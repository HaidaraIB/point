import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  verifyFirebaseIdToken,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import { assertOsAdmin } from "../_shared/os-admin.ts";
import {
  getZaincashSettingsStatus,
  saveZaincashSettings,
} from "../_shared/zaincash.ts";

type ZaincashBody = {
  action?: string;
  environment?: string;
  clientId?: string;
  clientSecret?: string;
  apiKey?: string;
  serviceType?: string;
  liveApiBase?: string;
  language?: string;
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

    const body = await req.json().catch(() => ({})) as ZaincashBody;
    const action = (body.action ?? "").trim();

    if (action === "get-settings") {
      await assertOsAdmin(saAccessToken, caller.firebaseProjectId, caller.uid);
      const env = (body.environment ?? "").trim().toLowerCase();
      const status = await getZaincashSettingsStatus(
        saAccessToken,
        caller.firebaseProjectId,
        env === "live" || env === "test" ? env : undefined,
      );
      return json({ success: true, ...status });
    }

    if (action === "save-settings") {
      await assertOsAdmin(saAccessToken, caller.firebaseProjectId, caller.uid);
      try {
        const status = await saveZaincashSettings(
          {
            environment: body.environment,
            clientId: body.clientId,
            clientSecret: body.clientSecret,
            apiKey: body.apiKey,
            serviceType: body.serviceType,
            liveApiBase: body.liveApiBase,
            language: body.language,
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

    return json({ errorCode: "ERR_INVALID_ACTION" }, 400);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg === "Forbidden") {
      return json({ errorCode: "ERR_FORBIDDEN" }, 403);
    }
    console.error("zaincash error:", msg);
    return json({ errorCode: "ERR_INTERNAL", message: msg }, 500);
  }
});
