import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  listAllowedFirebaseProjectIds,
  type ServiceAccountJson,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import { settleAlqasehInvoice } from "../_shared/alqaseh.ts";

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

function parsePaymentId(payload: Record<string, unknown>, url: URL): string {
  const fromBody = String(
    payload.payment_id ?? payload.paymentId ?? "",
  ).trim();
  if (fromBody) return fromBody;
  return url.searchParams.get("payment_id")?.trim() ?? "";
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

  const url = new URL(req.url);
  const paymentId = parsePaymentId(payload, url);
  if (!paymentId) {
    return new Response("Missing payment_id", { status: 400 });
  }

  try {
    const result = await settleAlqasehInvoice(
      resolved.accessToken,
      resolved.projectId,
      paymentId,
    );
    console.log("alqaseh-webhook:", paymentId, result);
    return new Response("OK", { status: 200 });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("alqaseh-webhook settlement error:", msg);
    return new Response("Settlement failed", { status: 500 });
  }
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
