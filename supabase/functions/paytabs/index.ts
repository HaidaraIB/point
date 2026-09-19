import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  verifyFirebaseIdToken,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import { assertOsAdmin, assertOsAccess } from "../_shared/os-admin.ts";
import {
  createPaytabsSession,
  getPaytabsSettingsStatus,
  savePaytabsSettings,
} from "../_shared/paytabs.ts";

type PaytabsBody = {
  action?: string;
  profileId?: string;
  serverKey?: string;
  clientKey?: string;
  region?: string;
  currency?: string;
  isEnabled?: boolean;
  defaultBankAccountId?: string;
  invoiceId?: string;
};

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-firebase-id-token, x-supabase-client-platform, x-supabase-client-platform-version, x-region",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return json({ errorCode: "ERR_METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    const firebaseAuthz = req.headers.get("x-firebase-id-token") ?? "";
    const idToken = firebaseAuthz.toLowerCase().startsWith("bearer ")
      ? firebaseAuthz.slice(7).trim()
      : firebaseAuthz.trim();
    if (!idToken) return json({ errorCode: "ERR_MISSING_TOKEN" }, 401);

    const caller = await verifyFirebaseIdToken(idToken);
    const sa = getServiceAccountForFirebaseProject(caller.firebaseProjectId);
    const saAccessToken = await getAccessToken(sa);

    const body = await req.json().catch(() => ({})) as PaytabsBody;
    const action = (body.action ?? "").trim();

    if (action === "get-settings") {
      await assertOsAdmin(saAccessToken, caller.firebaseProjectId, caller.uid);
      const status = await getPaytabsSettingsStatus(
        saAccessToken,
        caller.firebaseProjectId,
      );
      return json({ success: true, ...status });
    }

    if (action === "save-settings") {
      await assertOsAdmin(saAccessToken, caller.firebaseProjectId, caller.uid);
      try {
        const status = await savePaytabsSettings(
          {
            profileId: body.profileId,
            serverKey: body.serverKey,
            clientKey: body.clientKey,
            region: body.region,
            currency: body.currency,
            isEnabled: body.isEnabled,
            defaultBankAccountId: body.defaultBankAccountId,
          },
          saAccessToken,
          caller.firebaseProjectId,
          caller.uid,
        );
        return json({ success: true, ...status });
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        if (msg.startsWith("ERR_PAYTABS_")) {
          return json({ success: false, errorCode: msg }, 400);
        }
        throw e;
      }
    }

    if (action === "create-session") {
      await assertOsAccess(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
        "invoices",
      );
      const invoiceId = (body.invoiceId ?? "").trim();
      if (!invoiceId) {
        return json({ success: false, errorCode: "ERR_INVOICE_ID_REQUIRED" }, 400);
      }
      try {
        const session = await createPaytabsSession(
          saAccessToken,
          caller.firebaseProjectId,
          invoiceId,
        );
        return json({ success: true, ...session });
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        if (msg.startsWith("ERR_")) {
          return json({ success: false, errorCode: msg }, 400);
        }
        throw e;
      }
    }

    return json({ errorCode: "ERR_INVALID_ACTION" }, 400);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg === "Forbidden") {
      return json({ errorCode: "ERR_FORBIDDEN" }, 403);
    }
    console.error("paytabs error:", msg);
    return json({ errorCode: "ERR_INTERNAL", message: msg }, 500);
  }
});
