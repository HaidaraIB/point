import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  listAllowedFirebaseProjectIds,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import {
  loadWhatsappSettings,
  recordWhatsappCustomerInbound,
} from "../_shared/whatsapp.ts";

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function verifyToken(): string {
  return (Deno.env.get("WHATSAPP_WEBHOOK_VERIFY_TOKEN") ?? "").trim();
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);

  if (req.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token") ?? "";
    const challenge = url.searchParams.get("hub.challenge") ?? "";
    const expected = verifyToken();
    if (mode === "subscribe" && expected.length > 0 && token === expected) {
      return new Response(challenge, { status: 200 });
    }
    return new Response("Forbidden", { status: 403 });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const body = await req.json().catch(() => ({})) as {
      object?: string;
      entry?: Array<{
        changes?: Array<{
          value?: {
            metadata?: { phone_number_id?: string };
            messages?: Array<{ from?: string; timestamp?: string }>;
          };
        }>;
      }>;
    };

    if (body.object !== "whatsapp_business_account") {
      return json({ success: true });
    }

    const explicitProjectId =
      url.searchParams.get("firebaseProjectId")?.trim() ?? "";
    const allowed = listAllowedFirebaseProjectIds();
    const projectIds = explicitProjectId.length > 0
      ? (allowed.includes(explicitProjectId) ? [explicitProjectId] : [])
      : allowed;

    for (const change of body.entry ?? []) {
      for (const item of change.changes ?? []) {
        const value = item.value;
        if (!value?.messages?.length) continue;
        const phoneNumberId = (value.metadata?.phone_number_id ?? "").trim();
        for (const msg of value.messages) {
          const from = (msg.from ?? "").trim();
          if (!from) continue;
          const tsSec = Number(msg.timestamp ?? "0");
          const inboundAt = tsSec > 0
            ? new Date(tsSec * 1000)
            : new Date();

          for (const projectId of projectIds) {
            const sa = getServiceAccountForFirebaseProject(projectId);
            const accessToken = await getAccessToken(sa);
            const settings = await loadWhatsappSettings(accessToken, projectId);
            if (!settings?.isEnabled) continue;
            if (phoneNumberId &&
              settings.phoneNumberId &&
              settings.phoneNumberId !== phoneNumberId) {
              continue;
            }
            await recordWhatsappCustomerInbound(
              accessToken,
              projectId,
              from,
              inboundAt,
            );
          }
        }
      }
    }

    return json({ success: true });
  } catch (e) {
    console.error("os-whatsapp-webhook error:", e);
    return json({ success: false }, 500);
  }
});
