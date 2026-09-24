import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  listAllowedFirebaseProjectIds,
  type ServiceAccountJson,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import {
  loadZaincashSettings,
  settleZaincashInvoice,
  verifyZaincashCallbackJwt,
} from "../_shared/zaincash.ts";

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

function parseTransactionId(payload: Record<string, unknown>): string {
  const data = (payload.data as Record<string, unknown> | undefined) ?? {};
  return String(
    data.transactionId ?? payload.transactionId ?? "",
  ).trim();
}

async function handleWebhookPost(req: Request): Promise<Response> {
  const resolved = await resolveProjectFromQuery(req);
  if (!resolved) {
    return new Response("Unknown project", { status: 400 });
  }

  const rawBody = await req.text();
  let payload: Record<string, unknown> = {};
  let jwtToken = "";

  if (rawBody.trim().startsWith("{")) {
    try {
      payload = JSON.parse(rawBody) as Record<string, unknown>;
      jwtToken = String(payload.token ?? "").trim();
    } catch {
      return new Response("Invalid JSON", { status: 400 });
    }
  } else {
    jwtToken = rawBody.trim();
  }

  const settings = await loadZaincashSettings(
    resolved.accessToken,
    resolved.projectId,
  );
  const verifyKey = settings?.apiKey?.trim() ||
    settings?.clientSecret?.trim() ||
    "";

  if (jwtToken && verifyKey) {
    try {
      const decoded = await verifyZaincashCallbackJwt(jwtToken, verifyKey);
      payload = decoded.payload;
      if (!decoded.verified) {
        console.warn("zaincash-webhook: JWT not verified");
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.warn("zaincash-webhook: token decode failed:", msg);
      return new Response("Invalid token", { status: 400 });
    }
  }

  const transactionId = parseTransactionId(payload);
  if (!transactionId) {
    return new Response("Missing transactionId", { status: 400 });
  }

  try {
    const result = await settleZaincashInvoice(
      resolved.accessToken,
      resolved.projectId,
      transactionId,
    );
    console.log("zaincash-webhook:", transactionId, result);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("zaincash-webhook settlement error:", msg);
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
