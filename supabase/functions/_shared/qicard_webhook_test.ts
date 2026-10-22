import {
  assertEquals,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  buildQicardWebhookDataString,
  formatQicardWebhookAmount,
  mapQicardPaymentStatus,
} from "./qicard.ts";
import { handleQicardWebhookPost } from "./qicard-webhook-handler.ts";

const DOCS_EXAMPLE =
  "b91e8d70-1ab7-4275-85a2-61f7dbb31410|10000.000|IQD|2025-01-13T21:25:19|SUCCESS";

const docsPayload = {
  paymentId: "b91e8d70-1ab7-4275-85a2-61f7dbb31410",
  amount: 10000,
  currency: "IQD",
  creationDate: "2025-01-13T21:25:19",
  status: "SUCCESS",
};

Deno.test("formatQicardWebhookAmount appends .000", () => {
  assertEquals(formatQicardWebhookAmount(10000), "10000.000");
  assertEquals(formatQicardWebhookAmount(10000.0), "10000.000");
});

Deno.test("buildQicardWebhookDataString matches docs example", () => {
  assertEquals(buildQicardWebhookDataString(docsPayload), DOCS_EXAMPLE);
  // JSON `10000.0` parses to the same number.
  assertEquals(
    buildQicardWebhookDataString(
      JSON.parse(JSON.stringify(docsPayload).replace("10000", "10000.0")),
    ),
    DOCS_EXAMPLE,
  );
});

Deno.test("buildQicardWebhookDataString uses - for missing or falsy fields", () => {
  assertEquals(buildQicardWebhookDataString({}), "-|-|-|-|-");
  assertEquals(
    buildQicardWebhookDataString({ paymentId: "p1", amount: 0, status: "" }),
    "p1|-|-|-|-",
  );
});

Deno.test("mapQicardPaymentStatus", () => {
  assertEquals(mapQicardPaymentStatus("SUCCESS", false), "paid");
  assertEquals(mapQicardPaymentStatus("CREATED", false), "pending");
  assertEquals(mapQicardPaymentStatus("CREATED", true), "failed");
  assertEquals(mapQicardPaymentStatus("FAILED", false), "failed");
});

// --- webhook handler with a key pair generated in the test ---

function toB64(bytes: ArrayBuffer): string {
  let s = "";
  for (const b of new Uint8Array(bytes)) s += String.fromCharCode(b);
  return btoa(s);
}

async function generateKeyPair(): Promise<{ privateKey: CryptoKey; pem: string }> {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const spki = await crypto.subtle.exportKey("spki", pair.publicKey);
  const body = toB64(spki).match(/.{1,64}/g)!.join("\n");
  return {
    privateKey: pair.privateKey,
    pem: `-----BEGIN PUBLIC KEY-----\n${body}\n-----END PUBLIC KEY-----\n`,
  };
}

async function sign(privateKey: CryptoKey, data: string): Promise<string> {
  return toB64(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      privateKey,
      new TextEncoder().encode(data),
    ),
  );
}

function webhookRequest(body: unknown, signature?: string): Request {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (signature !== undefined) headers.set("X-Signature", signature);
  return new Request(
    "https://example.supabase.co/functions/v1/qicard-webhook?firebaseProjectId=proj",
    { method: "POST", headers, body: JSON.stringify(body) },
  );
}

/** `settle` stands in for the status-API re-check + settlement. */
function makeDeps(publicKey: string) {
  const settled: string[] = [];
  return {
    settled,
    deps: {
      resolveProject: () =>
        Promise.resolve({ projectId: "proj", accessToken: "tok" }),
      loadPublicKey: () => Promise.resolve(publicKey),
      settle: (_t: string, _p: string, paymentId: string) => {
        settled.push(paymentId);
        return Promise.resolve("settled");
      },
    },
  };
}

Deno.test("webhook with key: valid signature is processed", async () => {
  const { privateKey, pem } = await generateKeyPair();
  const signature = await sign(privateKey, DOCS_EXAMPLE);
  const { settled, deps } = makeDeps(pem);
  const res = await handleQicardWebhookPost(
    webhookRequest(docsPayload, signature),
    deps,
  );
  assertEquals(res.status, 200);
  assertEquals(settled, [docsPayload.paymentId]);
});

Deno.test("webhook with key: missing signature is 401 and not processed", async () => {
  const { pem } = await generateKeyPair();
  const { settled, deps } = makeDeps(pem);
  const res = await handleQicardWebhookPost(webhookRequest(docsPayload), deps);
  assertEquals(res.status, 401);
  assertEquals(settled, []);
});

Deno.test("webhook with key: garbage signature is 401 and not processed", async () => {
  const { pem } = await generateKeyPair();
  const { settled, deps } = makeDeps(pem);
  for (const bad of ["not-base64!!", btoa("garbage"), ""]) {
    const res = await handleQicardWebhookPost(
      webhookRequest(docsPayload, bad),
      deps,
    );
    assertEquals(res.status, 401, bad);
  }
  assertEquals(settled, []);
});

Deno.test("webhook with key: tampered body is 401 and not processed", async () => {
  const { privateKey, pem } = await generateKeyPair();
  const signature = await sign(privateKey, DOCS_EXAMPLE);
  const { settled, deps } = makeDeps(pem);
  const res = await handleQicardWebhookPost(
    webhookRequest({ ...docsPayload, amount: 1 }, signature),
    deps,
  );
  assertEquals(res.status, 401);
  assertEquals(settled, []);
});

Deno.test("webhook with key: signature from another key is 401", async () => {
  const signer = await generateKeyPair();
  const configured = await generateKeyPair();
  const signature = await sign(signer.privateKey, DOCS_EXAMPLE);
  const { settled, deps } = makeDeps(configured.pem);
  const res = await handleQicardWebhookPost(
    webhookRequest(docsPayload, signature),
    deps,
  );
  assertEquals(res.status, 401);
  assertEquals(settled, []);
});

Deno.test("webhook without key keeps current behavior (processed)", async () => {
  const { settled, deps } = makeDeps("");
  const res = await handleQicardWebhookPost(webhookRequest(docsPayload), deps);
  assertEquals(res.status, 200);
  assertEquals(settled, [docsPayload.paymentId]);
});
