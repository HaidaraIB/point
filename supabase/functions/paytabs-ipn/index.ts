import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  listAllowedFirebaseProjectIds,
  type ServiceAccountJson,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import {
  loadPaytabsSettings,
  parsePaytabsNotification,
  settlePaytabsInvoice,
  verifyPaytabsSignature,
} from "../_shared/paytabs.ts";

function htmlResponse(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

function returnPage(success: boolean, message: string): Response {
  const color = success ? "#059669" : "#e11d48";
  const title = success ? "Payment received" : "Payment not completed";
  return htmlResponse(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title}</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #f8fafc; margin: 0; padding: 32px; }
    .card { max-width: 480px; margin: 48px auto; background: #fff; border-radius: 16px; padding: 28px; border: 1px solid #e2e8f0; }
    h1 { margin: 0 0 12px; font-size: 22px; color: ${color}; }
    p { margin: 0; color: #475569; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="card">
    <h1>${title}</h1>
    <p>${message}</p>
  </div>
</body>
</html>`);
}

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
    const settings = await loadPaytabsSettings(accessToken, projectId);
    if (!settings?.serverKey) continue;
    const valid = await verifyPaytabsSignature(
      rawBody,
      signature,
      settings.serverKey,
    );
    if (valid) {
      return { sa, projectId, accessToken };
    }
  }

  return null;
}

async function handleReturn(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const respStatus = url.searchParams.get("respStatus") ??
    url.searchParams.get("resp_status") ?? "";
  const respMessage = url.searchParams.get("respMessage") ??
    url.searchParams.get("resp_message") ?? "";

  if (req.method === "POST") {
    const form = await req.formData().catch(() => null);
    const status = form?.get("respStatus")?.toString() ??
      form?.get("resp_status")?.toString() ?? respStatus;
    const message = form?.get("respMessage")?.toString() ??
      form?.get("resp_message")?.toString() ?? respMessage;
    const ok = status === "A";
    return returnPage(
      ok,
      ok
        ? "Thank you. Your payment was submitted successfully. The invoice will be updated shortly."
        : (message || "Your payment could not be completed. Please contact the agency."),
    );
  }

  const ok = respStatus === "A";
  return returnPage(
    ok,
    ok
      ? "Thank you. Your payment was submitted successfully. The invoice will be updated shortly."
      : (respMessage || "Your payment could not be completed. Please contact the agency."),
  );
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
