import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  listAllowedFirebaseProjectIds,
  type ServiceAccountJson,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import {
  buildQicardWebhookDataString,
  loadQicardSettings,
  settleQicardInvoice,
  verifyQicardWebhookSignature,
} from "../_shared/qicard.ts";

type ResolvedWebhookProject = {
  sa: ServiceAccountJson;
  projectId: string;
  accessToken: string;
};

async function resolveProjectFromQuery(
  req: Request,
): Promise<ResolvedWebhookProject | null> {
  const allowed = listAllowedFirebaseProjectIds();
  if (allowed.length === 0) {
    throw new Error("No Firebase service accounts configured");
  }

  const explicitId = new URL(req.url).searchParams.get("firebaseProjectId")
    ?.trim() ?? "";
  const projectId = explicitId.length > 0
    ? (allowed.includes(explicitId) ? explicitId : "")
    : allowed[0];
  if (!projectId) return null;

  const sa = getServiceAccountForFirebaseProject(projectId);
  const accessToken = await getAccessToken(sa);
  return { sa, projectId, accessToken };
}

function parsePaymentId(payload: Record<string, unknown>): string {
  return String(payload.paymentId ?? payload.payment_id ?? "").trim();
}

async function handleWebhookPost(req: Request): Promise<Response> {
  const resolved = await resolveProjectFromQuery(req);
  if (!resolved) {
    return new Response("Unknown project", { status: 400 });
  }

  const rawBody = await req.text();
  let payload: Record<string, unknown> = {};
  try {
    payload = rawBody ? JSON.parse(rawBody) as Record<string, unknown> : {};
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const paymentId = parsePaymentId(payload);
  if (!paymentId) {
    return new Response("Missing paymentId", { status: 400 });
  }

  const settings = await loadQicardSettings(
    resolved.accessToken,
    resolved.projectId,
  );
  const publicKey = settings?.webhookPublicKey?.trim() ?? "";
  const signature = req.headers.get("X-Signature")?.trim() ?? "";

  if (publicKey) {
    if (!signature) {
      console.warn("qicard-webhook: missing X-Signature");
      return new Response("Missing signature", { status: 401 });
    }
    const dataString = buildQicardWebhookDataString({
      paymentId: String(payload.paymentId ?? ""),
      amount: Number(payload.amount ?? 0),
      currency: String(payload.currency ?? ""),
      creationDate: String(payload.creationDate ?? ""),
      status: String(payload.status ?? ""),
    });
    const valid = await verifyQicardWebhookSignature(
      dataString,
      signature,
      publicKey,
    );
    if (!valid) {
      console.warn("qicard-webhook: invalid signature", paymentId);
      return new Response("Invalid signature", { status: 401 });
    }
  }

  try {
    const result = await settleQicardInvoice(
      resolved.accessToken,
      resolved.projectId,
      paymentId,
    );
    console.log("qicard-webhook:", paymentId, result);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("qicard-webhook settlement error:", msg);
  }

  return new Response("OK", { status: 200 });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200 });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  return await handleWebhookPost(req);
});
