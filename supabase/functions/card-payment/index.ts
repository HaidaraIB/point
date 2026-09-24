import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  verifyFirebaseIdToken,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import { assertOsAdmin, assertOsAccess } from "../_shared/os-admin.ts";
import { createAlqasehSession } from "../_shared/alqaseh.ts";
import { createPaytabsSession } from "../_shared/paytabs.ts";
import {
  getActiveCardProviderStatus,
  parseActiveCardProvider,
  setActiveCardProvider,
} from "../_shared/card-settings.ts";

type CardPaymentBody = {
  action?: string;
  provider?: string;
  defaultBankAccountId?: string;
  invoiceId?: string;
  firebaseProjectId?: string;
  returnBaseUrl?: string;
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
    const body = await req.json().catch(() => ({})) as CardPaymentBody;
    const action = (body.action ?? "").trim();

    const firebaseAuthz = req.headers.get("x-firebase-id-token") ?? "";
    const idToken = firebaseAuthz.toLowerCase().startsWith("bearer ")
      ? firebaseAuthz.slice(7).trim()
      : firebaseAuthz.trim();
    if (!idToken) return json({ errorCode: "ERR_MISSING_TOKEN" }, 401);

    const caller = await verifyFirebaseIdToken(idToken);
    const sa = getServiceAccountForFirebaseProject(caller.firebaseProjectId);
    const saAccessToken = await getAccessToken(sa);

    if (action === "get-active") {
      await assertOsAccess(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
        "invoices",
      );
      const status = await getActiveCardProviderStatus(
        saAccessToken,
        caller.firebaseProjectId,
      );
      return json({ success: true, ...status });
    }

    if (action === "set-active") {
      await assertOsAdmin(saAccessToken, caller.firebaseProjectId, caller.uid);
      try {
        const status = await setActiveCardProvider(
          {
            provider: parseActiveCardProvider(body.provider ?? "none"),
            defaultBankAccountId: body.defaultBankAccountId,
          },
          saAccessToken,
          caller.firebaseProjectId,
          caller.uid,
        );
        return json({ success: true, ...status });
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        if (msg.startsWith("ERR_")) {
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

      const returnBaseUrl = (body.returnBaseUrl ?? "").trim();

      const active = await getActiveCardProviderStatus(
        saAccessToken,
        caller.firebaseProjectId,
      );
      if (active.provider === "none") {
        return json({ success: false, errorCode: "ERR_CARD_PAYMENT_DISABLED" }, 400);
      }

      try {
        if (active.provider === "paytabs") {
          const session = await createPaytabsSession(
            saAccessToken,
            caller.firebaseProjectId,
            invoiceId,
            returnBaseUrl,
          );
          return json({
            success: true,
            provider: session.provider,
            redirectUrl: session.redirectUrl,
            providerRef: session.providerRef,
          });
        }

        const session = await createAlqasehSession(
          saAccessToken,
          caller.firebaseProjectId,
          invoiceId,
          returnBaseUrl,
        );
        return json({
          success: true,
          provider: "alqaseh",
          redirectUrl: session.redirectUrl,
          providerRef: session.providerRef,
        });
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
    console.error("card-payment error:", msg);
    return json({ errorCode: "ERR_INTERNAL", message: msg }, 500);
  }
});
