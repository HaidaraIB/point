import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  getQicardPaymentStatus,
  getQicardSettingsStatus,
  isQicardPublicKeyPem,
  isValidQicardBaseUrl,
  normalizeQicardBaseUrl,
  QICARD_LIVE_DEFAULT_HOST,
  qicardApiBaseUrl,
  resolveQicardCredentials,
} from "./qicard.ts";

const str = (v: string) => ({ stringValue: v });

function liveFields(liveApiBase?: string): Record<string, unknown> {
  return {
    qicardEnvironment: str("live"),
    qicardLiveUsername: str("live-user"),
    qicardLivePassword: str("live-pass"),
    qicardLiveTerminalId: str("111111"),
    ...(liveApiBase === undefined
      ? {}
      : { qicardLiveApiBase: str(liveApiBase) }),
    // Sandbox creds present too: live must never fall back to them.
    qicardTestUsername: str("paymentgatewaytest"),
    qicardTestPassword: str("sandbox-pass"),
    qicardTestTerminalId: str("237984"),
  };
}

Deno.test("normalizeQicardBaseUrl strips trailing slash and /api/v1", () => {
  const cases: [string, string][] = [
    ["https://3ds-api.qi.iq/api/v1", "https://3ds-api.qi.iq"],
    ["https://3ds-api.qi.iq/api/v1/", "https://3ds-api.qi.iq"],
    ["  https://3ds-api.qi.iq/api/v1  ", "https://3ds-api.qi.iq"],
    ["https://3ds-api.qi.iq", "https://3ds-api.qi.iq"],
    ["https://3ds-api.qi.iq/", "https://3ds-api.qi.iq"],
    ["", ""],
  ];
  for (const [input, expected] of cases) {
    assertEquals(normalizeQicardBaseUrl(input), expected, input);
  }
});

Deno.test("qicardApiBaseUrl never doubles /api/v1", () => {
  for (
    const apiBase of [
      "https://3ds-api.qi.iq/api/v1",
      "https://3ds-api.qi.iq/api/v1/",
      "https://3ds-api.qi.iq",
      "https://3ds-api.qi.iq/",
    ]
  ) {
    assertEquals(
      qicardApiBaseUrl({ apiBase }),
      "https://3ds-api.qi.iq/api/v1",
    );
  }
});

Deno.test("live default host is 3ds-api.qi.iq", () => {
  assertEquals(QICARD_LIVE_DEFAULT_HOST, "https://3ds-api.qi.iq");
  for (const base of [undefined, "", "   "]) {
    const creds = resolveQicardCredentials(liveFields(base));
    assertEquals(creds?.environment, "live");
    assertEquals(creds?.apiBase, "https://3ds-api.qi.iq");
  }
});

Deno.test("live uses the configured base URL", () => {
  const creds = resolveQicardCredentials(
    liveFields("https://custom-qi.example/api/v1/"),
  );
  assertEquals(creds?.apiBase, "https://custom-qi.example");
  assertEquals(creds?.username, "live-user");
});

Deno.test("incomplete live credentials do not fall back to sandbox", () => {
  const fields = liveFields();
  delete fields.qicardLivePassword;
  assertEquals(resolveQicardCredentials(fields), null);
});

Deno.test("isValidQicardBaseUrl accepts empty/https, rejects http", () => {
  assert(isValidQicardBaseUrl(""));
  assert(isValidQicardBaseUrl("https://3ds-api.qi.iq/api/v1"));
  assert(!isValidQicardBaseUrl("http://3ds-api.qi.iq"));
  assert(!isValidQicardBaseUrl("3ds-api.qi.iq"));
  assert(!isValidQicardBaseUrl("https://localhost"));
});

Deno.test("isQicardPublicKeyPem rejects private keys", () => {
  assert(isQicardPublicKeyPem("-----BEGIN PUBLIC KEY-----\nAA\n-----END PUBLIC KEY-----"));
  assert(!isQicardPublicKeyPem("-----BEGIN PRIVATE KEY-----\nAA\n-----END PRIVATE KEY-----"));
  assert(!isQicardPublicKeyPem("hello"));
});

type Call = { url: string; headers: Headers };

async function withStubbedFetch(
  osSettings: Record<string, unknown>,
  fn: (calls: Call[]) => Promise<void>,
) {
  const original = globalThis.fetch;
  const calls: Call[] = [];
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input instanceof Request ? input.url : input);
    if (url.includes("firestore.googleapis.com")) {
      return Promise.resolve(
        new Response(JSON.stringify({ fields: osSettings }), { status: 200 }),
      );
    }
    calls.push({ url, headers: new Headers(init?.headers) });
    return Promise.resolve(
      new Response(
        JSON.stringify({
          requestId: "r1",
          paymentId: "p1",
          status: "SUCCESS",
          amount: 1000,
          currency: "IQD",
        }),
        { status: 200 },
      ),
    );
  }) as typeof fetch;
  try {
    await fn(calls);
  } finally {
    globalThis.fetch = original;
  }
}

Deno.test("live status call hits the configured URL with live credentials", async () => {
  await withStubbedFetch(
    liveFields("https://3ds-api.qi.iq/api/v1"),
    async (calls) => {
      const payment = await getQicardPaymentStatus("tok", "proj", "p1");
      assertEquals(payment.status, "SUCCESS");
      assertEquals(calls.length, 1);
      assertEquals(
        calls[0].url,
        "https://3ds-api.qi.iq/api/v1/payment/p1/status",
      );
      assertEquals(calls[0].headers.get("X-Terminal-Id"), "111111");
      assertEquals(
        calls[0].headers.get("Authorization"),
        `Basic ${btoa("live-user:live-pass")}`,
      );
    },
  );
});

Deno.test("live status call with empty base URL uses the live default", async () => {
  await withStubbedFetch(liveFields(""), async (calls) => {
    await getQicardPaymentStatus("tok", "proj", "p1");
    assertEquals(
      calls[0].url,
      "https://3ds-api.qi.iq/api/v1/payment/p1/status",
    );
  });
});

Deno.test("credential check (configured / enable toggle) passes in live without a base URL", async () => {
  await withStubbedFetch(liveFields(), async (calls) => {
    const status = await getQicardSettingsStatus("tok", "proj");
    assertEquals(status.environment, "live");
    assert(status.configuredInFirestore);
    assertEquals(calls.length, 0);
  });
});
