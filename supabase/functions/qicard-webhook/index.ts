import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  listAllowedFirebaseProjectIds,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import {
  loadQicardWebhookPublicKey,
  settleQicardInvoice,
} from "../_shared/qicard.ts";
import {
  handleQicardWebhookPost,
  type QicardWebhookProject,
} from "../_shared/qicard-webhook-handler.ts";

async function resolveProjectFromQuery(
  req: Request,
): Promise<QicardWebhookProject | null> {
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
  return { projectId, accessToken };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200 });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  return await handleQicardWebhookPost(req, {
    resolveProject: resolveProjectFromQuery,
    loadPublicKey: loadQicardWebhookPublicKey,
    settle: settleQicardInvoice,
  });
});
