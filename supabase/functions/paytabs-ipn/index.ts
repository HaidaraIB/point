import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  listAllowedFirebaseProjectIds,
  type ServiceAccountJson,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import { buildPaytabsAppReturnRedirect } from "../_shared/card-return-url.ts";
import {
  loadPaytabsServerKeys,
  parsePaytabsNotification,
  settlePaytabsInvoice,
  verifyPaytabsSignature,
} from "../_shared/paytabs.ts";

type ResolvedIpnProject = {
  sa: ServiceAccountJson;
  projectId: string;
  accessToken: string;
};

async function resolveProjectForIpn(
  req: Request,
  rawBody: string,
  signature: string,
): Promise<ResolvedIpnProject | null> {
  const allowed = listAllowedFirebaseProjectIds();
  if (allowed.length === 0) {
    throw new Error("No Firebase service accounts configured");
  }

  const explicitId = new URL(req.url).searchParams.get("firebaseProjectId")?.trim() ?? "";
  const candidates = explicitId.length > 0
    ? (allowed.includes(explicitId) ? [explicitId] : [])
    : allowed;

  for (const projectId of candidates) {
    const sa = getServiceAccountForFirebaseProject(projectId);
    const accessToken = await getAccessToken(sa);
    const serverKeys = await loadPaytabsServerKeys(accessToken, projectId);
    for (const serverKey of serverKeys) {
      const valid = await verifyPaytabsSignature(
        rawBody,
        signature,
        serverKey,
      );
      if (valid) {
        return { sa, projectId, accessToken };
      }
    }
  }

  return null;
}

function readReturnFields(req: Request, url: URL): Record<string, string> {
  const fromQuery = (key: string, alt?: string): string =>
    url.searchParams.get(key)?.trim() ??
      (alt ? url.searchParams.get(alt)?.trim() : "") ??
      "";

  return {
    respStatus: fromQuery("respStatus", "resp_status"),
    respMessage: fromQuery("respMessage", "resp_message"),
    tranRef: fromQuery("tranRef", "tran_ref"),
    cartId: fromQuery("cartId", "cart_id"),
  };
}

async function handleReturn(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const appBase = url.searchParams.get("appBase") ?? "";
  const firebaseProjectId = url.searchParams.get("firebaseProjectId") ?? "";
  const payLinkToken = url.searchParams.get("t") ?? "";
  const fields = readReturnFields(req, url);

  if (req.method === "POST") {
    const form = await req.formData().catch(() => null);
    if (form) {
      const pick = (primary: string, alt: string) =>
        form.get(primary)?.toString().trim() ||
        form.get(alt)?.toString().trim() ||
        "";
      fields.respStatus = pick("respStatus", "resp_status") || fields.respStatus;
      fields.respMessage = pick("respMessage", "resp_message") || fields.respMessage;
      fields.tranRef = pick("tranRef", "tran_ref") || fields.tranRef;
      fields.cartId = pick("cartId", "cart_id") || fields.cartId;
    }
  }

  const location = buildPaytabsAppReturnRedirect(
    appBase,
    firebaseProjectId,
    fields,
    payLinkToken,
  );
  return new Response(null, {
    status: 302,
    headers: {
      Location: location,
      "Cache-Control": "no-store, max-age=0",
    },
  });
}

async function handleIpnPost(req: Request): Promise<Response> {
  const rawBody = await req.text();
  const signature = req.headers.get("Signature") ??
    req.headers.get("signature") ?? "";
  const resolved = await resolveProjectForIpn(req, rawBody, signature);
  if (!resolved) {
    console.error("paytabs-ipn: could not resolve project or invalid signature");
    return new Response("Invalid signature", { status: 401 });
  }

  const { projectId, accessToken } = resolved;

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody) as Record<string, unknown>;
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const notification = parsePaytabsNotification(payload);
  if (!notification) {
    return new Response("Invalid payload", { status: 400 });
  }

  try {
    const result = await settlePaytabsInvoice(accessToken, projectId, notification);
    console.log("paytabs-ipn:", notification.tranRef, result);
    return new Response("OK", { status: 200 });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("paytabs-ipn settlement error:", msg);
    return new Response("Settlement failed", { status: 500 });
  }
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const isReturn = url.searchParams.get("return") === "1";

  if (isReturn) {
    return await handleReturn(req);
  }

  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200 });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  return await handleIpnPost(req);
});
