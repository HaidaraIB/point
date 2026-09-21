/**
 * Meta WhatsApp Cloud API helpers, settings, and dispatch logs.
 */

import {
  createFirestoreDoc,
  firestoreBool,
  firestoreString,
  getFirestoreDoc,
  parseFirestoreFields,
  setFirestoreDoc,
  toFirestoreBool,
  toFirestoreString,
  toFirestoreTimestamp,
} from "./firestore-rest.ts";
import { OS_SETTINGS_DOC, maskSecret } from "./paytabs.ts";

export { OS_SETTINGS_DOC };

export const WHATSAPP_LOGS_COLLECTION = "os_whatsapp_logs";
export const WHATSAPP_SESSION_WINDOWS_COLLECTION = "os_whatsapp_session_windows";

const SESSION_WINDOW_MS = 24 * 60 * 60 * 1000;

const GRAPH_VERSION = "v25.0";
const GRAPH_BASE = `https://graph.facebook.com/${GRAPH_VERSION}`;

export type WhatsappSettings = {
  accessToken: string;
  phoneNumberId: string;
  businessAccountId: string;
  isEnabled: boolean;
  displayPhoneNumber: string;
  verifiedName: string;
};

export type WhatsappSettingsStatus = {
  phoneNumberId: string;
  businessAccountId: string;
  isEnabled: boolean;
  hasAccessToken: boolean;
  accessTokenPreview: string;
  displayPhoneNumber: string;
  verifiedName: string;
  configuredInFirestore: boolean;
};

export type WhatsappTemplateSummary = {
  name: string;
  status: string;
  category: string;
  language: string;
  components: unknown[];
};

export async function loadWhatsappSettings(
  accessToken: string,
  projectId: string,
): Promise<WhatsappSettings | null> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return null;

  const token = firestoreString(fields, "whatsappAccessToken");
  const phoneNumberId = firestoreString(fields, "whatsappPhoneNumberId");
  const businessAccountId = firestoreString(fields, "whatsappBusinessAccountId");
  const isEnabled = firestoreBool(fields, "whatsappEnabled");
  const displayPhoneNumber = firestoreString(fields, "whatsappDisplayPhoneNumber");
  const verifiedName = firestoreString(fields, "whatsappVerifiedName");

  if (!token && !phoneNumberId && !businessAccountId && !isEnabled) {
    return null;
  }

  return {
    accessToken: token,
    phoneNumberId,
    businessAccountId,
    isEnabled,
    displayPhoneNumber,
    verifiedName,
  };
}

export async function getWhatsappSettingsStatus(
  accessToken: string,
  projectId: string,
): Promise<WhatsappSettingsStatus> {
  const settings = await loadWhatsappSettings(accessToken, projectId);
  if (!settings) {
    return {
      phoneNumberId: "",
      businessAccountId: "",
      isEnabled: false,
      hasAccessToken: false,
      accessTokenPreview: "",
      displayPhoneNumber: "",
      verifiedName: "",
      configuredInFirestore: false,
    };
  }

  const hasAccessToken = settings.accessToken.length > 0;
  return {
    phoneNumberId: settings.phoneNumberId,
    businessAccountId: settings.businessAccountId,
    isEnabled: settings.isEnabled,
    hasAccessToken,
    accessTokenPreview: hasAccessToken
      ? maskSecret(settings.accessToken)
      : "",
    displayPhoneNumber: settings.displayPhoneNumber,
    verifiedName: settings.verifiedName,
    configuredInFirestore:
      hasAccessToken ||
      settings.phoneNumberId.length > 0 ||
      settings.isEnabled,
  };
}

export type SaveWhatsappSettingsInput = {
  accessToken?: string;
  phoneNumberId?: string;
  businessAccountId?: string;
  isEnabled?: boolean;
};

export async function saveWhatsappSettings(
  input: SaveWhatsappSettingsInput,
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<WhatsappSettingsStatus> {
  const existing = await loadWhatsappSettings(accessToken, projectId);
  const token = input.accessToken !== undefined
    ? input.accessToken.trim()
    : (existing?.accessToken ?? "");
  const phoneNumberId = (input.phoneNumberId ?? existing?.phoneNumberId ?? "")
    .trim();
  const businessAccountId = (
    input.businessAccountId ?? existing?.businessAccountId ?? ""
  ).trim();
  const isEnabled = input.isEnabled ?? existing?.isEnabled ?? false;

  if (isEnabled) {
    if (!token) throw new Error("ERR_WHATSAPP_TOKEN_REQUIRED");
    if (!phoneNumberId) throw new Error("ERR_WHATSAPP_PHONE_ID_REQUIRED");
    if (!businessAccountId) {
      throw new Error("ERR_WHATSAPP_WABA_ID_REQUIRED");
    }
  }

  const now = new Date().toISOString();
  const fields: Record<string, unknown> = {
    whatsappPhoneNumberId: toFirestoreString(phoneNumberId),
    whatsappBusinessAccountId: toFirestoreString(businessAccountId),
    whatsappEnabled: toFirestoreBool(isEnabled),
    whatsappUpdatedAt: toFirestoreString(now),
    whatsappUpdatedBy: toFirestoreString(uid),
  };
  if (token.length > 0) {
    fields.whatsappAccessToken = toFirestoreString(token);
  }

  const mask = [
    "whatsappPhoneNumberId",
    "whatsappBusinessAccountId",
    "whatsappEnabled",
    "whatsappUpdatedAt",
    "whatsappUpdatedBy",
  ];
  if (token.length > 0) mask.push("whatsappAccessToken");

  await setFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC, fields, mask);
  return await getWhatsappSettingsStatus(accessToken, projectId);
}

/** Normalize client phone to WhatsApp `to` (digits only, international). */
export function normalizeWhatsappPhone(raw: string): string | null {
  let digits = raw.replace(/\D/g, "");
  if (digits.length < 8) return null;
  if (digits.startsWith("00")) digits = digits.slice(2);
  if (digits.startsWith("0")) digits = `964${digits.slice(1)}`;
  if (digits.startsWith("7") && digits.length === 10) {
    digits = `964${digits}`;
  }
  if (digits.length < 10) return null;
  return digits;
}

export type WhatsappSessionWindowStatus = {
  open: boolean;
  expiresAt?: string;
  lastInboundAt?: string;
  tracked: boolean;
};

export async function recordWhatsappCustomerInbound(
  saAccessToken: string,
  projectId: string,
  customerPhone: string,
  inboundAt: Date = new Date(),
): Promise<void> {
  const phone = normalizeWhatsappPhone(customerPhone);
  if (!phone) return;
  const expiresAt = new Date(inboundAt.getTime() + SESSION_WINDOW_MS);
  const fields: Record<string, unknown> = {
    phone: toFirestoreString(phone),
    lastInboundAt: toFirestoreTimestamp(inboundAt),
    sessionExpiresAt: toFirestoreTimestamp(expiresAt),
  };
  const docPath = `${WHATSAPP_SESSION_WINDOWS_COLLECTION}/${phone}`;
  const existing = await getFirestoreDoc(saAccessToken, projectId, docPath);
  if (existing) {
    await setFirestoreDoc(
      saAccessToken,
      projectId,
      docPath,
      fields,
      ["phone", "lastInboundAt", "sessionExpiresAt"],
    );
  } else {
    await createFirestoreDoc(
      saAccessToken,
      projectId,
      WHATSAPP_SESSION_WINDOWS_COLLECTION,
      phone,
      fields,
    );
  }
}

export async function getWhatsappSessionWindowStatus(
  saAccessToken: string,
  projectId: string,
  customerPhone: string,
): Promise<WhatsappSessionWindowStatus> {
  const phone = normalizeWhatsappPhone(customerPhone);
  if (!phone) {
    return { open: false, tracked: false };
  }
  const docPath = `${WHATSAPP_SESSION_WINDOWS_COLLECTION}/${phone}`;
  const fields = await getFirestoreDoc(saAccessToken, projectId, docPath);
  if (!fields) {
    return { open: false, tracked: false };
  }
  const parsed = parseFirestoreFields(fields);
  const expiresRaw = parsed.sessionExpiresAt;
  const lastRaw = parsed.lastInboundAt;
  const expiresAt = typeof expiresRaw === "string"
    ? new Date(expiresRaw)
    : null;
  if (!expiresAt || Number.isNaN(expiresAt.getTime())) {
    return { open: false, tracked: false };
  }
  const lastInboundAt = typeof lastRaw === "string" ? lastRaw : undefined;
  return {
    open: expiresAt.getTime() > Date.now(),
    expiresAt: expiresAt.toISOString(),
    lastInboundAt,
    tracked: true,
  };
}

async function graphGet(
  path: string,
  token: string,
  searchParams?: Record<string, string>,
): Promise<unknown> {
  const params = new URLSearchParams(searchParams ?? {});
  params.set("access_token", token);
  const url = `${GRAPH_BASE}${path}?${params.toString()}`;
  const res = await fetch(url);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = data as { error?: { message?: string; code?: number } };
    const msg = err.error?.message ?? JSON.stringify(data);
    throw new Error(`ERR_WHATSAPP_GRAPH:${msg}`);
  }
  return data;
}

async function graphPost(
  path: string,
  token: string,
  body: Record<string, unknown>,
): Promise<unknown> {
  const url = `${GRAPH_BASE}${path}?access_token=${encodeURIComponent(token)}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = data as { error?: { message?: string } };
    const msg = err.error?.message ?? JSON.stringify(data);
    throw new Error(`ERR_WHATSAPP_GRAPH:${msg}`);
  }
  return data;
}

export async function testWhatsappConnection(
  settings: WhatsappSettings,
): Promise<{ displayPhoneNumber: string; verifiedName: string }> {
  if (!settings.accessToken || !settings.phoneNumberId) {
    throw new Error("ERR_WHATSAPP_NOT_CONFIGURED");
  }
  const data = await graphGet(
    `/${settings.phoneNumberId}`,
    settings.accessToken,
    {
      fields: "display_phone_number,verified_name,quality_rating",
    },
  ) as {
    display_phone_number?: string;
    verified_name?: string;
  };
  return {
    displayPhoneNumber: (data.display_phone_number ?? "").trim(),
    verifiedName: (data.verified_name ?? "").trim(),
  };
}

export async function persistWhatsappConnectionMeta(
  saAccessToken: string,
  projectId: string,
  uid: string,
  meta: { displayPhoneNumber: string; verifiedName: string },
): Promise<void> {
  const now = new Date().toISOString();
  await setFirestoreDoc(
    saAccessToken,
    projectId,
    OS_SETTINGS_DOC,
    {
      whatsappDisplayPhoneNumber: toFirestoreString(meta.displayPhoneNumber),
      whatsappVerifiedName: toFirestoreString(meta.verifiedName),
      whatsappTestedAt: toFirestoreString(now),
      whatsappTestedBy: toFirestoreString(uid),
    },
    [
      "whatsappDisplayPhoneNumber",
      "whatsappVerifiedName",
      "whatsappTestedAt",
      "whatsappTestedBy",
    ],
  );
}

export async function listApprovedWhatsappTemplates(
  settings: WhatsappSettings,
): Promise<WhatsappTemplateSummary[]> {
  if (!settings.accessToken || !settings.businessAccountId) {
    throw new Error("ERR_WHATSAPP_NOT_CONFIGURED");
  }
  const all: WhatsappTemplateSummary[] = [];
  let after: string | undefined;
  for (let page = 0; page < 10; page++) {
    const params: Record<string, string> = {
      fields: "name,status,category,language,components",
      limit: "100",
    };
    if (after) params.after = after;
    const data = await graphGet(
      `/${settings.businessAccountId}/message_templates`,
      settings.accessToken,
      params,
    ) as {
      data?: Array<{
        name?: string;
        status?: string;
        category?: string;
        language?: string;
        components?: unknown[];
      }>;
      paging?: { cursors?: { after?: string } };
    };
    for (const row of data.data ?? []) {
      const status = (row.status ?? "").toUpperCase();
      if (status !== "APPROVED") continue;
      all.push({
        name: row.name ?? "",
        status,
        category: row.category ?? "",
        language: row.language ?? "",
        components: row.components ?? [],
      });
    }
    after = data.paging?.cursors?.after;
    if (!after) break;
  }
  return all.filter((t) => t.name.length > 0);
}

export type SendTemplateInput = {
  toPhone: string;
  templateName: string;
  languageCode: string;
  bodyParameters?: string[];
  headerParameters?: string[];
  referenceId?: string;
  recipientName?: string;
  category?: string;
  documentBase64?: string;
  documentFilename?: string;
  templateHasDocumentHeader?: boolean;
};

export type SendTemplateResult = {
  success: boolean;
  wamid?: string;
  errorMessage?: string;
};

function graphErrorUserMessage(raw: string): string {
  let msg = raw.trim();
  while (msg.startsWith("ERR_WHATSAPP_GRAPH:")) {
    msg = msg.slice("ERR_WHATSAPP_GRAPH:".length).trim();
  }
  return msg;
}

function decodeBase64Pdf(b64: string): Uint8Array {
  const trimmed = b64.trim();
  if (!trimmed) throw new Error("ERR_WHATSAPP_DOCUMENT_EMPTY");
  const binary = atob(trimmed);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export async function uploadWhatsappMedia(
  settings: WhatsappSettings,
  pdfBytes: Uint8Array,
  filename: string,
): Promise<string> {
  if (!settings.accessToken || !settings.phoneNumberId) {
    throw new Error("ERR_WHATSAPP_NOT_CONFIGURED");
  }
  const safeName = filename.trim() || "document.pdf";
  const blob = new Blob([pdfBytes], { type: "application/pdf" });
  const form = new FormData();
  form.append("messaging_product", "whatsapp");
  form.append("type", "application/pdf");
  form.append("file", blob, safeName);

  const url =
    `${GRAPH_BASE}/${settings.phoneNumberId}/media?access_token=${
      encodeURIComponent(settings.accessToken)
    }`;
  const res = await fetch(url, { method: "POST", body: form });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = data as { error?: { message?: string } };
    const msg = err.error?.message ?? JSON.stringify(data);
    throw new Error(`ERR_WHATSAPP_GRAPH:${msg}`);
  }
  const id = (data as { id?: string }).id?.trim() ?? "";
  if (!id) throw new Error("ERR_WHATSAPP_MEDIA_UPLOAD_FAILED");
  return id;
}

export function isWhatsappSessionWindowError(raw: string): boolean {
  const msg = raw.toLowerCase();
  return msg.includes("131047") ||
    msg.includes("131026") ||
    (msg.includes("470") && msg.includes("24")) ||
    msg.includes("re-engagement") ||
    msg.includes("reengagement") ||
    msg.includes("customer service window") ||
    msg.includes("24 hour") ||
    msg.includes("24-hour") ||
    msg.includes("more than 24 hours");
}

export async function sendWhatsappTextMessage(
  settings: WhatsappSettings,
  toPhone: string,
  text: string,
): Promise<SendTemplateResult> {
  if (!settings.accessToken || !settings.phoneNumberId) {
    throw new Error("ERR_WHATSAPP_NOT_CONFIGURED");
  }
  const to = normalizeWhatsappPhone(toPhone);
  if (!to) throw new Error("ERR_PHONE_INVALID");
  const body = text.trim();
  if (!body) throw new Error("ERR_WHATSAPP_TEXT_REQUIRED");

  const payload: Record<string, unknown> = {
    messaging_product: "whatsapp",
    to,
    type: "text",
    text: { body, preview_url: false },
  };
  try {
    const data = await graphPost(
      `/${settings.phoneNumberId}/messages`,
      settings.accessToken,
      payload,
    ) as { messages?: Array<{ id?: string }> };
    const wamid = data.messages?.[0]?.id?.trim() ?? "";
    return { success: true, wamid };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const userMsg = graphErrorUserMessage(msg);
    if (isWhatsappSessionWindowError(userMsg)) {
      return { success: false, errorMessage: "ERR_WHATSAPP_SESSION_CLOSED" };
    }
    return { success: false, errorMessage: userMsg };
  }
}

export async function sendWhatsappDocumentMessage(
  settings: WhatsappSettings,
  toPhone: string,
  mediaId: string,
  filename: string,
): Promise<SendTemplateResult> {
  const to = normalizeWhatsappPhone(toPhone);
  if (!to) throw new Error("ERR_PHONE_INVALID");
  const payload: Record<string, unknown> = {
    messaging_product: "whatsapp",
    to,
    type: "document",
    document: {
      id: mediaId,
      filename: filename.trim() || "document.pdf",
    },
  };
  try {
    const data = await graphPost(
      `/${settings.phoneNumberId}/messages`,
      settings.accessToken,
      payload,
    ) as { messages?: Array<{ id?: string }> };
    const wamid = data.messages?.[0]?.id?.trim() ?? "";
    return { success: true, wamid };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const userMsg = graphErrorUserMessage(msg);
    if (isWhatsappSessionWindowError(userMsg)) {
      return { success: false, errorMessage: "ERR_WHATSAPP_SESSION_CLOSED" };
    }
    return { success: false, errorMessage: userMsg };
  }
}

export type SendSessionInput = {
  toPhone: string;
  text?: string;
  documentBase64?: string;
  documentFilename?: string;
};

/** Free-form messages (text and/or document) within the 24-hour customer window. */
export async function sendWhatsappSession(
  settings: WhatsappSettings,
  input: SendSessionInput,
): Promise<SendTemplateResult> {
  const text = (input.text ?? "").trim();
  const documentB64 = (input.documentBase64 ?? "").trim();
  const documentFilename = (input.documentFilename ?? "document.pdf").trim() ||
    "document.pdf";

  if (!text && !documentB64) {
    return { success: false, errorMessage: "ERR_WHATSAPP_SESSION_EMPTY" };
  }

  let wamid = "";
  if (text) {
    const textResult = await sendWhatsappTextMessage(
      settings,
      input.toPhone,
      text,
    );
    if (!textResult.success) return textResult;
    if (textResult.wamid) wamid = textResult.wamid;
  }

  if (documentB64) {
    try {
      const pdfBytes = decodeBase64Pdf(documentB64);
      const mediaId = await uploadWhatsappMedia(
        settings,
        pdfBytes,
        documentFilename,
      );
      const docResult = await sendWhatsappDocumentMessage(
        settings,
        input.toPhone,
        mediaId,
        documentFilename,
      );
      if (!docResult.success) return docResult;
      if (!wamid && docResult.wamid) wamid = docResult.wamid;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { success: false, errorMessage: graphErrorUserMessage(msg) };
    }
  }

  return { success: true, wamid };
}

function buildTemplateComponents(
  bodyParameters: string[],
  headerTextParameters: string[],
  documentHeader?: { mediaId: string; filename: string },
): Array<Record<string, unknown>> {
  const components: Array<Record<string, unknown>> = [];
  if (documentHeader) {
    components.push({
      type: "header",
      parameters: [{
        type: "document",
        document: {
          id: documentHeader.mediaId,
          filename: documentHeader.filename,
        },
      }],
    });
  } else if (headerTextParameters.length > 0) {
    components.push({
      type: "header",
      parameters: headerTextParameters.map((text) => ({
        type: "text",
        text,
      })),
    });
  }
  if (bodyParameters.length > 0) {
    components.push({
      type: "body",
      parameters: bodyParameters.map((text) => ({
        type: "text",
        text,
      })),
    });
  }
  return components;
}

export async function sendWhatsappTemplate(
  settings: WhatsappSettings,
  input: SendTemplateInput,
): Promise<SendTemplateResult> {
  if (!settings.accessToken || !settings.phoneNumberId) {
    throw new Error("ERR_WHATSAPP_NOT_CONFIGURED");
  }
  const to = normalizeWhatsappPhone(input.toPhone);
  if (!to) throw new Error("ERR_PHONE_INVALID");

  const lang = (input.languageCode ?? "ar").trim() || "ar";
  const category = (input.category ?? "").trim().toUpperCase();
  const attachInvoicePdf = category === "INVOICE";
  const documentB64 = (input.documentBase64 ?? "").trim();
  const documentFilename = (input.documentFilename ?? "invoice.pdf").trim() ||
    "invoice.pdf";

  let mediaId: string | undefined;
  try {
    if (documentB64) {
      const pdfBytes = decodeBase64Pdf(documentB64);
      mediaId = await uploadWhatsappMedia(settings, pdfBytes, documentFilename);
    } else if (attachInvoicePdf) {
      throw new Error("ERR_WHATSAPP_DOCUMENT_REQUIRED");
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { success: false, errorMessage: graphErrorUserMessage(msg) };
  }

  const useDocumentHeader = Boolean(
    input.templateHasDocumentHeader && mediaId,
  );

  const components = buildTemplateComponents(
    input.bodyParameters ?? [],
    useDocumentHeader ? [] : (input.headerParameters ?? []),
    useDocumentHeader && mediaId
      ? { mediaId, filename: documentFilename }
      : undefined,
  );

  const payload: Record<string, unknown> = {
    messaging_product: "whatsapp",
    to,
    type: "template",
    template: {
      name: input.templateName.trim(),
      language: { code: lang },
      ...(components.length > 0 ? { components } : {}),
    },
  };

  try {
    const data = await graphPost(
      `/${settings.phoneNumberId}/messages`,
      settings.accessToken,
      payload,
    ) as { messages?: Array<{ id?: string }> };
    let wamid = data.messages?.[0]?.id?.trim() ?? "";

    if (mediaId && !useDocumentHeader) {
      const docResult = await sendWhatsappDocumentMessage(
        settings,
        input.toPhone,
        mediaId,
        documentFilename,
      );
      if (!docResult.success) {
        return docResult;
      }
      if (!wamid && docResult.wamid) wamid = docResult.wamid;
    }

    return { success: true, wamid };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const userMsg = graphErrorUserMessage(msg);
    if (isWhatsappSessionWindowError(userMsg)) {
      return { success: false, errorMessage: "ERR_WHATSAPP_SESSION_CLOSED" };
    }
    return { success: false, errorMessage: userMsg };
  }
}

export async function writeWhatsappLog(
  saAccessToken: string,
  projectId: string,
  logId: string,
  entry: {
    type: string;
    recipientName: string;
    recipientPhone: string;
    templateName: string;
    languageCode: string;
    status: string;
    preview: string;
    referenceId?: string;
    wamid?: string;
    errorMessage?: string;
    sentByUid: string;
    attachmentFilename?: string;
  },
): Promise<void> {
  const now = new Date();
  await createFirestoreDoc(
    saAccessToken,
    projectId,
    WHATSAPP_LOGS_COLLECTION,
    logId,
    {
      type: toFirestoreString(entry.type),
      recipientName: toFirestoreString(entry.recipientName),
      recipientPhone: toFirestoreString(entry.recipientPhone),
      templateName: toFirestoreString(entry.templateName),
      languageCode: toFirestoreString(entry.languageCode),
      status: toFirestoreString(entry.status),
      preview: toFirestoreString(entry.preview),
      referenceId: toFirestoreString(entry.referenceId ?? ""),
      wamid: toFirestoreString(entry.wamid ?? ""),
      errorMessage: toFirestoreString(
        graphErrorUserMessage(entry.errorMessage ?? ""),
      ),
      attachmentFilename: toFirestoreString(entry.attachmentFilename ?? ""),
      sentByUid: toFirestoreString(entry.sentByUid),
      sentAt: toFirestoreTimestamp(now),
    },
  );
}
