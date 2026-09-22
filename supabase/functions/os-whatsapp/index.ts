import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  verifyFirebaseIdToken,
} from "../_shared/firebase-edge.ts";
import { getAccessToken } from "../_shared/firestore-rest.ts";
import { assertOsAdmin, assertOsAccess } from "../_shared/os-admin.ts";
import {
  getWhatsappSettingsStatus,
  getWhatsappSessionWindowStatus,
  listApprovedWhatsappTemplates,
  loadWhatsappSettings,
  loadWhatsappTemplateMap,
  normalizeWhatsappPhone,
  persistWhatsappConnectionMeta,
  saveWhatsappSettings,
  saveWhatsappTemplateMap,
  sendWhatsappTemplate,
  sendWhatsappSession,
  testWhatsappConnection,
  writeWhatsappLog,
} from "../_shared/whatsapp.ts";

type WhatsappBody = {
  action?: string;
  accessToken?: string;
  phoneNumberId?: string;
  businessAccountId?: string;
  isEnabled?: boolean;
  toPhone?: string;
  templateName?: string;
  languageCode?: string;
  bodyParameters?: unknown;
  headerParameters?: unknown;
  buttonParameters?: unknown;
  templateMap?: { templates?: unknown[] };
  referenceId?: string;
  recipientName?: string;
  category?: string;
  preview?: string;
  documentBase64?: string;
  documentFilename?: string;
  templateHasDocumentHeader?: boolean;
  text?: string;
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

function graphErrorCode(e: unknown): string {
  return graphErrorPayload(e).errorCode;
}

function graphErrorPayload(e: unknown): {
  errorCode: string;
  errorMessage?: string;
} {
  const msg = e instanceof Error ? e.message : String(e);
  if (msg.startsWith("ERR_WHATSAPP_GRAPH:")) {
    return {
      errorCode: "ERR_WHATSAPP_GRAPH",
      errorMessage: msg.slice("ERR_WHATSAPP_GRAPH:".length).trim(),
    };
  }
  if (msg.startsWith("ERR_")) {
    const code = msg.split(":")[0];
    const rest = msg.includes(":") ? msg.slice(msg.indexOf(":") + 1).trim() : "";
    return rest ? { errorCode: code, errorMessage: rest } : { errorCode: code };
  }
  return { errorCode: "ERR_INTERNAL", errorMessage: msg };
}

function newLogId(): string {
  return crypto.randomUUID();
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

    const body = await req.json().catch(() => ({})) as WhatsappBody;
    const action = (body.action ?? "").trim();

    if (action === "get-settings") {
      try {
        await assertOsAdmin(
          saAccessToken,
          caller.firebaseProjectId,
          caller.uid,
        );
      } catch {
        await assertOsAccess(
          saAccessToken,
          caller.firebaseProjectId,
          caller.uid,
          "messaging",
        );
      }
      const status = await getWhatsappSettingsStatus(
        saAccessToken,
        caller.firebaseProjectId,
      );
      return json({ success: true, ...status });
    }

    if (action === "save-settings") {
      await assertOsAdmin(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
      );
      try {
        const status = await saveWhatsappSettings(
          {
            accessToken: body.accessToken,
            phoneNumberId: body.phoneNumberId,
            businessAccountId: body.businessAccountId,
            isEnabled: body.isEnabled,
          },
          saAccessToken,
          caller.firebaseProjectId,
          caller.uid,
        );
        return json({ success: true, ...status });
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        if (msg.startsWith("ERR_WHATSAPP_")) {
          return json({ success: false, errorCode: msg }, 400);
        }
        throw e;
      }
    }

    if (action === "test-connection") {
      await assertOsAdmin(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
      );
      const settings = await loadWhatsappSettings(
        saAccessToken,
        caller.firebaseProjectId,
      );
      if (!settings?.accessToken || !settings.phoneNumberId) {
        return json(
          { success: false, errorCode: "ERR_WHATSAPP_NOT_CONFIGURED" },
          400,
        );
      }
      try {
        const meta = await testWhatsappConnection(settings);
        await persistWhatsappConnectionMeta(
          saAccessToken,
          caller.firebaseProjectId,
          caller.uid,
          meta,
        );
        return json({ success: true, ...meta });
      } catch (e) {
        const payload = graphErrorPayload(e);
        return json({ success: false, ...payload }, 400);
      }
    }

    if (action === "list-templates") {
      await assertOsAccess(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
        "messaging",
      );
      const settings = await loadWhatsappSettings(
        saAccessToken,
        caller.firebaseProjectId,
      );
      if (
        !settings?.accessToken ||
        !settings.businessAccountId ||
        !settings.isEnabled
      ) {
        return json(
          { success: false, errorCode: "ERR_WHATSAPP_NOT_CONFIGURED" },
          400,
        );
      }
      try {
        const templates = await listApprovedWhatsappTemplates(settings);
        const templateMap = await loadWhatsappTemplateMap(
          saAccessToken,
          caller.firebaseProjectId,
        );
        return json({ success: true, templates, templateMap });
      } catch (e) {
        return json({ success: false, ...graphErrorPayload(e) }, 400);
      }
    }

    if (action === "get-template-map") {
      await assertOsAccess(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
        "messaging",
      );
      const templateMap = await loadWhatsappTemplateMap(
        saAccessToken,
        caller.firebaseProjectId,
      );
      return json({ success: true, templateMap });
    }

    if (action === "save-template-map") {
      await assertOsAdmin(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
      );
      const raw = body.templateMap;
      const templates = raw && typeof raw === "object" && Array.isArray(
        (raw as { templates?: unknown[] }).templates,
      )
        ? (raw as { templates: unknown[] }).templates
        : [];
      const templateMap = await saveWhatsappTemplateMap(
        { templates: templates as Array<Record<string, unknown>> },
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
      );
      return json({ success: true, templateMap });
    }

    if (action === "check-session-window") {
      await assertOsAccess(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
        "messaging",
      );
      const toPhone = (body.toPhone ?? "").trim();
      if (!toPhone || !normalizeWhatsappPhone(toPhone)) {
        return json(
          { success: false, errorCode: "ERR_PHONE_INVALID" },
          400,
        );
      }
      const status = await getWhatsappSessionWindowStatus(
        saAccessToken,
        caller.firebaseProjectId,
        toPhone,
      );
      return json({ success: true, ...status });
    }

    if (action === "send-template") {
      await assertOsAccess(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
        "messaging",
      );
      const settings = await loadWhatsappSettings(
        saAccessToken,
        caller.firebaseProjectId,
      );
      if (
        !settings?.accessToken ||
        !settings.phoneNumberId ||
        !settings.isEnabled
      ) {
        return json(
          { success: false, errorCode: "ERR_WHATSAPP_NOT_CONFIGURED" },
          400,
        );
      }

      const toPhone = (body.toPhone ?? "").trim();
      const templateName = (body.templateName ?? "").trim();
      const languageCode = (body.languageCode ?? "ar").trim();
      if (!toPhone || !templateName) {
        return json(
          { success: false, errorCode: "ERR_WHATSAPP_INVALID_REQUEST" },
          400,
        );
      }
      if (!normalizeWhatsappPhone(toPhone)) {
        return json(
          { success: false, errorCode: "ERR_PHONE_INVALID" },
          400,
        );
      }

      const documentBase64 = (body.documentBase64 ?? "").trim();
      const documentFilename = (body.documentFilename ?? "").trim();
      const templateHasDocumentHeader = body.templateHasDocumentHeader === true;

      const result = await sendWhatsappTemplate(settings, {
        toPhone,
        templateName,
        languageCode,
        bodyParameters: body.bodyParameters,
        headerParameters: body.headerParameters,
        buttonParameters: body.buttonParameters,
        referenceId: body.referenceId,
        recipientName: body.recipientName,
        category: body.category,
        ...(documentBase64 ? { documentBase64 } : {}),
        ...(documentFilename ? { documentFilename } : {}),
        templateHasDocumentHeader,
      });

      const normalizedPhone = normalizeWhatsappPhone(toPhone) ?? toPhone;
      const logId = newLogId();
      const preview = (body.preview ?? templateName).trim().slice(0, 500);
      const attachmentFilename = documentBase64
        ? (documentFilename || "document.pdf")
        : "";
      await writeWhatsappLog(
        saAccessToken,
        caller.firebaseProjectId,
        logId,
        {
          type: (body.category ?? "CUSTOM").trim().toUpperCase() || "CUSTOM",
          recipientName: (body.recipientName ?? "").trim(),
          recipientPhone: normalizedPhone,
          templateName,
          languageCode,
          status: result.success ? "SENT" : "FAILED",
          preview,
          referenceId: body.referenceId,
          wamid: result.wamid,
          errorMessage: result.errorMessage,
          sentByUid: caller.uid,
          ...(attachmentFilename
            ? { attachmentFilename }
            : {}),
        },
      );

      if (!result.success) {
        return json({
          success: false,
          errorCode: "ERR_WHATSAPP_GRAPH",
          errorMessage: result.errorMessage,
          logId,
        }, 400);
      }

      return json({ success: true, wamid: result.wamid, logId });
    }

    if (action === "send-session") {
      await assertOsAccess(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
        "messaging",
      );
      const settings = await loadWhatsappSettings(
        saAccessToken,
        caller.firebaseProjectId,
      );
      if (
        !settings?.accessToken ||
        !settings.phoneNumberId ||
        !settings.isEnabled
      ) {
        return json(
          { success: false, errorCode: "ERR_WHATSAPP_NOT_CONFIGURED" },
          400,
        );
      }

      const toPhone = (body.toPhone ?? "").trim();
      if (!toPhone) {
        return json(
          { success: false, errorCode: "ERR_WHATSAPP_INVALID_REQUEST" },
          400,
        );
      }
      if (!normalizeWhatsappPhone(toPhone)) {
        return json(
          { success: false, errorCode: "ERR_PHONE_INVALID" },
          400,
        );
      }

      const text = (body.text ?? "").trim();
      const documentBase64 = (body.documentBase64 ?? "").trim();
      const documentFilename = (body.documentFilename ?? "").trim();

      const result = await sendWhatsappSession(settings, {
        toPhone,
        text,
        ...(documentBase64 ? { documentBase64 } : {}),
        ...(documentFilename ? { documentFilename } : {}),
      });

      const normalizedPhone = normalizeWhatsappPhone(toPhone) ?? toPhone;
      const logId = newLogId();
      const previewRaw = (body.preview ?? text).trim();
      const preview = previewRaw.slice(0, 500) ||
        (documentFilename ? documentFilename : "SESSION");
      const sessionAttachment = documentBase64
        ? (documentFilename || "document.pdf")
        : "";

      await writeWhatsappLog(
        saAccessToken,
        caller.firebaseProjectId,
        logId,
        {
          type: (body.category ?? "CUSTOM").trim().toUpperCase() || "CUSTOM",
          recipientName: (body.recipientName ?? "").trim(),
          recipientPhone: normalizedPhone,
          templateName: "SESSION",
          languageCode: "",
          status: result.success ? "SENT" : "FAILED",
          preview,
          referenceId: body.referenceId,
          wamid: result.wamid,
          errorMessage: result.errorMessage,
          sentByUid: caller.uid,
          ...(sessionAttachment
            ? { attachmentFilename: sessionAttachment }
            : {}),
        },
      );

      if (!result.success) {
        const code = result.errorMessage === "ERR_WHATSAPP_SESSION_CLOSED"
          ? "ERR_WHATSAPP_SESSION_CLOSED"
          : "ERR_WHATSAPP_GRAPH";
        return json({
          success: false,
          errorCode: code,
          errorMessage: result.errorMessage,
          logId,
        }, 400);
      }

      return json({ success: true, wamid: result.wamid, logId });
    }

    return json({ errorCode: "ERR_INVALID_ACTION" }, 400);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg === "Forbidden") {
      return json({ errorCode: "ERR_FORBIDDEN" }, 403);
    }
    console.error("os-whatsapp error:", msg);
    return json({ errorCode: "ERR_INTERNAL", message: msg }, 500);
  }
});
