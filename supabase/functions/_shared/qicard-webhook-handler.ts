/**
 * QiCard webhook request handling, with I/O injected so it can be tested.
 *
 * The body is only a hint: `settle` re-reads the payment from QiCard's status
 * API with server-side credentials before anything is marked paid.
 */

import {
  buildQicardWebhookDataString,
  verifyQicardWebhookSignature,
} from "./qicard.ts";

export type QicardWebhookProject = {
  projectId: string;
  accessToken: string;
};

export type QicardWebhookDeps = {
  resolveProject: (req: Request) => Promise<QicardWebhookProject | null>;
  loadPublicKey: (accessToken: string, projectId: string) => Promise<string>;
  settle: (
    accessToken: string,
    projectId: string,
    paymentId: string,
  ) => Promise<string>;
};

function parsePaymentId(payload: Record<string, unknown>): string {
  return String(payload.paymentId ?? payload.payment_id ?? "").trim();
}

export async function handleQicardWebhookPost(
  req: Request,
  deps: QicardWebhookDeps,
): Promise<Response> {
  const resolved = await deps.resolveProject(req);
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

  const publicKey = (await deps.loadPublicKey(
    resolved.accessToken,
    resolved.projectId,
  )).trim();

  if (publicKey) {
    const signature = req.headers.get("X-Signature")?.trim() ?? "";
    if (!signature) {
      console.warn("qicard-webhook: missing signature", paymentId);
      return new Response("Missing signature", { status: 401 });
    }
    const valid = await verifyQicardWebhookSignature(
      buildQicardWebhookDataString(payload),
      signature,
      publicKey,
    );
    if (!valid) {
      console.warn("qicard-webhook: invalid signature", paymentId);
      return new Response("Invalid signature", { status: 401 });
    }
  }

  try {
    const result = await deps.settle(
      resolved.accessToken,
      resolved.projectId,
      paymentId,
    );
    console.log("qicard-webhook:", paymentId, result);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("qicard-webhook settlement error:", paymentId, msg);
  }

  return new Response("OK", { status: 200 });
}
