/**
 * Qi Card Payment Gateway helpers, settings, and invoice sessions.
 */

import {
  firestoreBool,
  firestoreNumber,
  firestoreString,
  getFirestoreDoc,
  setFirestoreDoc,
  toFirestoreNumber,
  toFirestoreString,
} from "./firestore-rest.ts";
import {
  amountsMatch,
  claimCardPaymentEvent,
  INVOICES_COLLECTION,
  logCardPaymentEvent,
  sanitizeEventId,
  settleCardInvoice,
} from "./card-settlement.ts";
import {
  isQicardEnabled,
  OS_SETTINGS_DOC,
  resolveSettlementBankAccountId,
} from "./card-settings.ts";
import { maskSecret } from "./paytabs.ts";
import { buildQicardFinishPaymentUrl } from "./card-return-url.ts";
import { ensureInvoicePayLinkToken } from "./pay-link.ts";

export const QICARD_EVENTS_COLLECTION = "os_qicard_events";

export type QicardEnvironment = "test" | "live";

/** Hosts only; request paths are `{host}/api/v1/...`. */
export const QICARD_SANDBOX_HOST = "https://uat-sandbox-3ds-api.qi.iq";
export const QICARD_LIVE_DEFAULT_HOST = "https://3ds-api.qi.iq";
const QICARD_API_PATH = "/api/v1";

/**
 * Normalizes a configured QiCard base URL to a bare host: trims, strips a
 * trailing `/`, then a trailing `/api/v1` (Qi hands out the URL with it).
 */
export function normalizeQicardBaseUrl(raw: string): string {
  return raw.trim().replace(/\/+$/, "").replace(/\/api\/v1$/i, "")
    .replace(/\/+$/, "");
}

/** Live host: configured value (normalized) or the production default. */
export function resolveQicardLiveHost(configured: string): string {
  return normalizeQicardBaseUrl(configured) || QICARD_LIVE_DEFAULT_HOST;
}

export type QicardSettings = {
  environment: QicardEnvironment;
  username: string;
  password: string;
  terminalId: string;
  apiBase: string;
  currency: string;
  bankAccountId: string;
  webhookPublicKey: string;
};

export type QicardSettingsStatus = {
  enabled: boolean;
  environment: QicardEnvironment;
  username: string;
  terminalId: string;
  currency: string;
  bankAccountId: string;
  liveApiBase: string;
  hasPassword: boolean;
  passwordPreview: string;
  hasWebhookPublicKey: boolean;
  webhookPublicKeyPreview: string;
  /** Full PEM; a public key is not secret, the admin UI shows it as-is. */
  webhookPublicKey: string;
  configuredInFirestore: boolean;
};

export type QicardPaymentObject = {
  requestId: string;
  paymentId: string;
  status: string;
  canceled: boolean;
  amount: number;
  currency: string;
  creationDate: string;
  formUrl?: string;
};

function parseEnvironment(value: string): QicardEnvironment {
  return value.trim().toLowerCase() === "live" ? "live" : "test";
}

function loadCredentialsForEnvironment(
  fields: Record<string, unknown>,
  environment: QicardEnvironment,
): { username: string; password: string; terminalId: string; apiBase: string } {
  if (environment === "test") {
    return {
      username: firestoreString(fields, "qicardTestUsername"),
      password: firestoreString(fields, "qicardTestPassword"),
      terminalId: firestoreString(fields, "qicardTestTerminalId"),
      apiBase: QICARD_SANDBOX_HOST,
    };
  }
  return {
    username: firestoreString(fields, "qicardLiveUsername"),
    password: firestoreString(fields, "qicardLivePassword"),
    terminalId: firestoreString(fields, "qicardLiveTerminalId"),
    apiBase: resolveQicardLiveHost(firestoreString(fields, "qicardLiveApiBase")),
  };
}

/**
 * Credentials for the selected environment only. Never falls back to the
 * other environment: a live invoice must not be settled against sandbox.
 */
export function resolveQicardCredentials(
  fields: Record<string, unknown>,
): {
  environment: QicardEnvironment;
  username: string;
  password: string;
  terminalId: string;
  apiBase: string;
} | null {
  const environment = parseEnvironment(
    firestoreString(fields, "qicardEnvironment"),
  );
  const creds = loadCredentialsForEnvironment(fields, environment);
  if (!creds.username || !creds.password || !creds.terminalId) return null;
  return { environment, ...creds };
}

/** `{host}/api/v1` for the resolved settings; callers append `/payment...`. */
export function qicardApiBaseUrl(settings: Pick<QicardSettings, "apiBase">): string {
  return `${normalizeQicardBaseUrl(settings.apiBase)}${QICARD_API_PATH}`;
}

function basicAuthHeader(username: string, password: string): string {
  return `Basic ${btoa(`${username}:${password}`)}`;
}

export function getQicardWebhookUrl(firebaseProjectId?: string): string {
  const base = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
  if (!base) throw new Error("SUPABASE_URL not set");
  const url = `${base}/functions/v1/qicard-webhook`;
  const projectId = (firebaseProjectId ?? "").trim();
  if (!projectId) return url;
  return `${url}?firebaseProjectId=${encodeURIComponent(projectId)}`;
}

function normalizeCheckoutAmount(amount: number, currency: string): number {
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error("ERR_INVOICE_INVALID_AMOUNT");
  }
  const cur = currency.trim().toUpperCase();
  if (cur === "IQD") return Math.round(amount * 1000) / 1000;
  return Math.round(amount * 100) / 100;
}

/** Qi's Node sample: `amount.toString() + '.000'`. Whole floats print as ints. */
export function formatQicardWebhookAmount(amount: number | string): string {
  const n = typeof amount === "number" && Number.isInteger(amount)
    ? Math.trunc(amount)
    : amount;
  return `${String(n)}.000`;
}

/**
 * Signed string per Qi "Webhook Verification":
 * `paymentId|amount|currency|creationDate|status`, `-` for any falsy value.
 * Uses the raw body values (no trimming) so it matches what Qi signed.
 */
export function buildQicardWebhookDataString(
  payload: Record<string, unknown>,
): string {
  const part = (v: unknown) => (v ? String(v) : "-");
  const amount = payload.amount;
  return [
    part(payload.paymentId),
    amount && (typeof amount === "number" || typeof amount === "string")
      ? formatQicardWebhookAmount(amount)
      : "-",
    part(payload.currency),
    part(payload.creationDate),
    part(payload.status),
  ].join("|");
}

function pemToSpkiDer(pem: string): Uint8Array<ArrayBuffer> {
  const b64 = pem
    .replace(/-----BEGIN PUBLIC KEY-----/g, "")
    .replace(/-----END PUBLIC KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

export async function verifyQicardWebhookSignature(
  dataString: string,
  signatureB64: string,
  publicKeyPem: string,
): Promise<boolean> {
  const pem = publicKeyPem.trim();
  if (!pem || !signatureB64.trim()) return false;
  try {
    const key = await crypto.subtle.importKey(
      "spki",
      pemToSpkiDer(pem),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
    const signature: Uint8Array<ArrayBuffer> = Uint8Array.from(
      atob(signatureB64.trim()),
      (c) => c.charCodeAt(0),
    );
    const data = new TextEncoder().encode(dataString);
    return await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      key,
      signature,
      data,
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn("verifyQicardWebhookSignature failed:", msg);
    return false;
  }
}

/** Webhook RSA public key (PEM), readable even when credentials are incomplete. */
export async function loadQicardWebhookPublicKey(
  accessToken: string,
  projectId: string,
): Promise<string> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return "";
  return firestoreString(fields, "qicardWebhookPublicKey").trim();
}

export async function loadQicardSettings(
  accessToken: string,
  projectId: string,
): Promise<QicardSettings | null> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return null;
  const resolved = resolveQicardCredentials(fields);
  if (!resolved) return null;

  const currency = firestoreString(fields, "qicardCurrency") || "IQD";
  const bankAccountId = firestoreString(fields, "qicardBankAccountId");
  const webhookPublicKey = firestoreString(fields, "qicardWebhookPublicKey");

  return {
    environment: resolved.environment,
    username: resolved.username,
    password: resolved.password,
    terminalId: resolved.terminalId,
    apiBase: resolved.apiBase,
    currency,
    bankAccountId,
    webhookPublicKey,
  };
}

export async function getQicardSettingsStatus(
  accessToken: string,
  projectId: string,
  environmentFilter?: string,
): Promise<QicardSettingsStatus> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return emptyQicardStatus();

  const env = environmentFilter === "live" || environmentFilter === "test"
    ? parseEnvironment(environmentFilter)
    : parseEnvironment(firestoreString(fields, "qicardEnvironment"));

  const creds = loadCredentialsForEnvironment(fields, env);
  const password = creds.password;
  const webhookKey = firestoreString(fields, "qicardWebhookPublicKey");

  return {
    enabled: firestoreBool(fields, "qicardEnabled"),
    environment: env,
    username: creds.username,
    terminalId: creds.terminalId,
    currency: firestoreString(fields, "qicardCurrency") || "IQD",
    bankAccountId: firestoreString(fields, "qicardBankAccountId"),
    liveApiBase: firestoreString(fields, "qicardLiveApiBase"),
    hasPassword: password.length > 0,
    passwordPreview: maskSecret(password),
    hasWebhookPublicKey: webhookKey.length > 0,
    webhookPublicKeyPreview: webhookKey
      ? `${webhookKey.slice(0, 24)}…`
      : "",
    webhookPublicKey: webhookKey,
    configuredInFirestore: Boolean(
      creds.username && creds.password && creds.terminalId,
    ),
  };
}

function emptyQicardStatus(): QicardSettingsStatus {
  return {
    enabled: false,
    environment: "test",
    username: "",
    terminalId: "",
    currency: "IQD",
    bankAccountId: "",
    liveApiBase: "",
    hasPassword: false,
    passwordPreview: "",
    hasWebhookPublicKey: false,
    webhookPublicKeyPreview: "",
    webhookPublicKey: "",
    configuredInFirestore: false,
  };
}

/** Public key PEM only; a private key must never be stored. */
export function isQicardPublicKeyPem(value: string): boolean {
  return value.includes("BEGIN PUBLIC KEY") && !value.includes("PRIVATE KEY");
}

/** Empty (= default host) or an https URL; Basic auth must not go over http. */
export function isValidQicardBaseUrl(raw: string): boolean {
  const normalized = normalizeQicardBaseUrl(raw);
  if (!normalized) return true;
  try {
    const url = new URL(normalized);
    return url.protocol === "https:" && url.hostname.includes(".") &&
      !url.search && !url.hash;
  } catch {
    return false;
  }
}

export async function saveQicardSettings(
  input: {
    environment?: string;
    username?: string;
    password?: string;
    terminalId?: string;
    currency?: string;
    liveApiBase?: string;
    webhookPublicKey?: string;
  },
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<QicardSettingsStatus> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC) ??
    {};
  const environment = parseEnvironment(
    input.environment ?? firestoreString(fields, "qicardEnvironment"),
  );

  const username = (input.username ??
    loadCredentialsForEnvironment(fields, environment).username).trim();
  const terminalId = (input.terminalId ??
    loadCredentialsForEnvironment(fields, environment).terminalId).trim();
  const passwordInput = (input.password ?? "").trim();
  const existingPassword = loadCredentialsForEnvironment(
    fields,
    environment,
  ).password;
  const password = passwordInput || existingPassword;

  const hasUsableCredentials = Boolean(username && password && terminalId);
  if (!hasUsableCredentials) {
    throw new Error("ERR_QICARD_NOT_CONFIGURED");
  }

  const currency = (input.currency ??
    firestoreString(fields, "qicardCurrency") ??
    "IQD").trim().toUpperCase();
  // Empty = use QICARD_LIVE_DEFAULT_HOST.
  const liveApiBase = normalizeQicardBaseUrl(
    input.liveApiBase ?? firestoreString(fields, "qicardLiveApiBase"),
  );
  if (!isValidQicardBaseUrl(liveApiBase)) {
    throw new Error("ERR_QICARD_LIVE_API_BASE_INVALID");
  }
  if (input.webhookPublicKey && !isQicardPublicKeyPem(input.webhookPublicKey)) {
    throw new Error("ERR_QICARD_WEBHOOK_KEY_INVALID");
  }

  const now = new Date().toISOString();
  const docFields: Record<string, unknown> = {
    qicardCurrency: toFirestoreString(currency),
    qicardUpdatedAt: toFirestoreString(now),
    qicardUpdatedBy: toFirestoreString(uid),
  };
  const mask = ["qicardCurrency", "qicardUpdatedAt", "qicardUpdatedBy"];

  if (hasUsableCredentials) {
    docFields.qicardEnvironment = toFirestoreString(environment);
    mask.push("qicardEnvironment");
  }

  if (input.webhookPublicKey !== undefined) {
    docFields.qicardWebhookPublicKey = toFirestoreString(
      input.webhookPublicKey.trim(),
    );
    mask.push("qicardWebhookPublicKey");
  }

  if (environment === "test") {
    docFields.qicardTestUsername = toFirestoreString(username);
    docFields.qicardTestTerminalId = toFirestoreString(terminalId);
    mask.push("qicardTestUsername", "qicardTestTerminalId");
    if (passwordInput.length > 0) {
      docFields.qicardTestPassword = toFirestoreString(passwordInput);
      mask.push("qicardTestPassword");
    }
  } else {
    docFields.qicardLiveUsername = toFirestoreString(username);
    docFields.qicardLiveTerminalId = toFirestoreString(terminalId);
    docFields.qicardLiveApiBase = toFirestoreString(liveApiBase);
    mask.push("qicardLiveUsername", "qicardLiveTerminalId", "qicardLiveApiBase");
    if (passwordInput.length > 0) {
      docFields.qicardLivePassword = toFirestoreString(passwordInput);
      mask.push("qicardLivePassword");
    }
  }

  await setFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC, docFields, mask);
  return await getQicardSettingsStatus(accessToken, projectId, environment);
}

/**
 * A Qi failure with a stable `ERR_QICARD_*` code as `message` (so existing
 * `startsWith("ERR_")` handlers keep working) plus Qi's own reason in `detail`.
 */
export class QicardError extends Error {
  constructor(code: string, readonly detail: string = "") {
    super(code);
    this.name = "QicardError";
  }
}

/** `detail` of a QicardError, or "" for any other error. */
export function qicardErrorDetail(e: unknown): string {
  return e instanceof QicardError ? e.detail : "";
}

/** Best-effort human reason from a Qi error body, capped for display. */
export function extractQicardErrorMessage(data: Record<string, unknown>): string {
  const pick = (v: unknown): string => {
    if (typeof v === "string") return v.trim();
    if (Array.isArray(v)) return v.map(pick).filter(Boolean).join("; ");
    if (v && typeof v === "object") {
      const o = v as Record<string, unknown>;
      return pick(o.message ?? o.description ?? o.detail ?? o.error ?? "");
    }
    return "";
  };
  const msg = pick(data.message) || pick(data.error) || pick(data.errors) ||
    pick(data.details) || pick(data.description) || pick(data.raw);
  return msg.length > 300 ? `${msg.slice(0, 300)}…` : msg;
}

/** Qi's numeric `error.code`, or null when absent. */
export function qicardProviderErrorCode(
  data: Record<string, unknown>,
): number | null {
  const err = data.error;
  if (!err || typeof err !== "object") return null;
  const code = Number((err as Record<string, unknown>).code);
  return Number.isFinite(code) ? code : null;
}

/** Qi error 21: a callback URL's domain is not whitelisted for the terminal. */
const QICARD_ERROR_DOMAIN_PROHIBITED = 21;

/** Maps a failed Qi response to a stable error code. */
export function qicardCreateErrorCode(
  status: number,
  data: Record<string, unknown> = {},
): string {
  if (qicardProviderErrorCode(data) === QICARD_ERROR_DOMAIN_PROHIBITED) {
    return "ERR_QICARD_DOMAIN_PROHIBITED";
  }
  if (status === 401 || status === 403) return "ERR_QICARD_AUTH_FAILED";
  if (status === 404 || status === 405) return "ERR_QICARD_ENDPOINT_NOT_FOUND";
  if (status >= 500) return "ERR_QICARD_PROVIDER_ERROR";
  return "ERR_QICARD_REQUEST_REJECTED";
}

async function parseQicardResponse(res: Response): Promise<Record<string, unknown>> {
  const raw = await res.text();
  if (!raw.trim()) return {};
  try {
    return JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return { raw };
  }
}

function parsePaymentObject(data: Record<string, unknown>): QicardPaymentObject {
  return {
    requestId: String(data.requestId ?? "").trim(),
    paymentId: String(data.paymentId ?? "").trim(),
    status: String(data.status ?? "").trim().toUpperCase(),
    canceled: data.canceled === true,
    amount: Number(data.amount ?? 0),
    currency: String(data.currency ?? "").trim(),
    creationDate: String(data.creationDate ?? "").trim(),
    formUrl: String(data.formUrl ?? "").trim() || undefined,
  };
}

export async function getQicardPaymentStatus(
  accessToken: string,
  projectId: string,
  paymentId: string,
): Promise<QicardPaymentObject> {
  const settings = await loadQicardSettings(accessToken, projectId);
  if (!settings) throw new Error("ERR_QICARD_NOT_CONFIGURED");

  const apiBase = qicardApiBaseUrl(settings);
  const res = await fetch(
    `${apiBase}/payment/${encodeURIComponent(paymentId)}/status`,
    {
      method: "GET",
      headers: {
        Authorization: basicAuthHeader(settings.username, settings.password),
        "X-Terminal-Id": settings.terminalId,
      },
    },
  );

  const data = await parseQicardResponse(res);
  if (!res.ok) {
    throw new Error(
      `QiCard status failed: ${res.status} ${JSON.stringify(data)}`,
    );
  }
  return parsePaymentObject(data);
}

export async function refundQicardPayment(
  accessToken: string,
  projectId: string,
  paymentId: string,
  amount: number,
  message?: string,
): Promise<Record<string, unknown>> {
  const settings = await loadQicardSettings(accessToken, projectId);
  if (!settings) throw new Error("ERR_QICARD_NOT_CONFIGURED");

  const pid = paymentId.trim();
  if (!pid) throw new Error("ERR_QICARD_PAYMENT_ID_REQUIRED");

  const checkoutAmount = normalizeCheckoutAmount(amount, settings.currency);
  const body: Record<string, unknown> = {
    requestId: crypto.randomUUID(),
    amount: checkoutAmount,
  };
  const note = (message ?? "").trim();
  if (note) body.message = note;

  const apiBase = qicardApiBaseUrl(settings);
  const res = await fetch(
    `${apiBase}/payment/${encodeURIComponent(pid)}/refund`,
    {
      method: "POST",
      headers: {
        Authorization: basicAuthHeader(settings.username, settings.password),
        "X-Terminal-Id": settings.terminalId,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );

  const data = await parseQicardResponse(res);
  if (!res.ok) {
    console.error("QiCard refund failed:", res.status, JSON.stringify(data));
    throw new Error("ERR_QICARD_REFUND_FAILED");
  }
  return data;
}

export async function cancelQicardPayment(
  accessToken: string,
  projectId: string,
  paymentId: string,
): Promise<QicardPaymentObject> {
  const settings = await loadQicardSettings(accessToken, projectId);
  if (!settings) throw new Error("ERR_QICARD_NOT_CONFIGURED");

  const pid = paymentId.trim();
  if (!pid) throw new Error("ERR_QICARD_PAYMENT_ID_REQUIRED");

  const apiBase = qicardApiBaseUrl(settings);
  const res = await fetch(
    `${apiBase}/payment/${encodeURIComponent(pid)}/cancel`,
    {
      method: "POST",
      headers: {
        Authorization: basicAuthHeader(settings.username, settings.password),
        "X-Terminal-Id": settings.terminalId,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ requestId: crypto.randomUUID() }),
    },
  );

  const data = await parseQicardResponse(res);
  if (!res.ok) {
    console.error("QiCard cancel failed:", res.status, JSON.stringify(data));
    throw new Error("ERR_QICARD_CANCEL_FAILED");
  }
  return parsePaymentObject(data);
}

const REUSABLE_STATUSES = new Set(["CREATED"]);

export type CreateQicardSessionResult = {
  redirectUrl: string;
  providerRef: string;
  requestId: string;
};

export async function createQicardSession(
  accessToken: string,
  projectId: string,
  invoiceId: string,
  returnBaseUrl?: string,
): Promise<CreateQicardSessionResult> {
  const enabled = await isQicardEnabled(accessToken, projectId);
  if (!enabled) throw new Error("ERR_CARD_PAYMENT_DISABLED");

  const settings = await loadQicardSettings(accessToken, projectId);
  if (!settings) throw new Error("ERR_QICARD_NOT_CONFIGURED");

  const invoiceFields = await getFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${invoiceId}`,
  );
  if (!invoiceFields) throw new Error("ERR_INVOICE_NOT_FOUND");

  const status = firestoreString(invoiceFields, "status");
  if (status === "PAID") throw new Error("ERR_INVOICE_ALREADY_PAID");

  const total = firestoreNumber(invoiceFields, "total");
  const displayNumber = firestoreString(invoiceFields, "displayNumber");
  const clientName = firestoreString(invoiceFields, "clientName");
  const clientEmail = firestoreString(invoiceFields, "clientEmail");
  const clientPhone = firestoreString(invoiceFields, "clientPhone");
  let payLinkToken = firestoreString(invoiceFields, "payLinkToken");
  if (payLinkToken.length < 8) {
    payLinkToken = await ensureInvoicePayLinkToken(
      accessToken,
      projectId,
      invoiceId,
    );
  }

  const existingProvider = firestoreString(invoiceFields, "cardProvider");
  const existingUrl = firestoreString(invoiceFields, "cardPaymentUrl");
  const existingRef = firestoreString(invoiceFields, "cardProviderRef");
  const existingAmount = firestoreNumber(invoiceFields, "cardSessionAmount");
  const existingRequestId = firestoreString(invoiceFields, "qicardRequestId");

  if (
    existingProvider === "qicard" &&
    existingUrl &&
    existingRef &&
    existingRequestId &&
    amountsMatch(existingAmount, total)
  ) {
    try {
      const payment = await getQicardPaymentStatus(
        accessToken,
        projectId,
        existingRef,
      );
      if (
        REUSABLE_STATUSES.has(payment.status) &&
        !payment.canceled &&
        payment.formUrl
      ) {
        return {
          redirectUrl: payment.formUrl || existingUrl,
          providerRef: existingRef,
          requestId: existingRequestId,
        };
      }
    } catch {
      // Create a new payment.
    }
  }

  const requestId = crypto.randomUUID();
  const checkoutAmount = normalizeCheckoutAmount(total, settings.currency);
  const finishPaymentUrl = buildQicardFinishPaymentUrl(
    projectId,
    requestId,
    payLinkToken,
    returnBaseUrl,
  );

  const body: Record<string, unknown> = {
    requestId,
    amount: checkoutAmount,
    currency: settings.currency.trim().toUpperCase(),
    locale: "ar_IQ",
    finishPaymentUrl,
    notificationUrl: getQicardWebhookUrl(projectId),
    appChannel: false,
    additionalInfo: {
      invoiceId,
      firebaseProjectId: projectId,
    },
    customerInfo: {
      firstName: clientName.split(/\s+/)[0] || clientName || "Customer",
      lastName: clientName.split(/\s+/).slice(1).join(" ") || "-",
      email: clientEmail || undefined,
      phone: clientPhone || undefined,
    },
  };

  const apiBase = qicardApiBaseUrl(settings);
  let res: Response;
  try {
    res = await fetch(`${apiBase}/payment`, {
      method: "POST",
      headers: {
        Authorization: basicAuthHeader(settings.username, settings.password),
        "X-Terminal-Id": settings.terminalId,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("QiCard create unreachable:", settings.environment, apiBase, msg);
    throw new QicardError(
      "ERR_QICARD_UNREACHABLE",
      `${settings.environment} ${apiBase}: ${msg}`,
    );
  }

  const data = await parseQicardResponse(res);
  if (!res.ok) {
    console.error(
      "QiCard create failed:",
      settings.environment,
      apiBase,
      res.status,
      JSON.stringify(data),
    );
    const code = qicardCreateErrorCode(res.status, data);
    const reason = extractQicardErrorMessage(data);
    // Name both callback URLs' hosts so the one to whitelist is obvious.
    const urls = code === "ERR_QICARD_DOMAIN_PROHIBITED"
      ? ` (finish: ${new URL(finishPaymentUrl).host}, notify: ${
        new URL(body.notificationUrl as string).host
      })`
      : "";
    throw new QicardError(
      code,
      `${settings.environment} HTTP ${res.status}${
        reason ? `: ${reason}` : ""
      }${urls}`,
    );
  }

  const payment = parsePaymentObject(data);
  if (!payment.paymentId || !payment.formUrl) {
    console.error(
      "QiCard create returned no paymentId/formUrl:",
      settings.environment,
      JSON.stringify(data),
    );
    const reason = extractQicardErrorMessage(data);
    throw new QicardError(
      "ERR_QICARD_INVALID_RESPONSE",
      `${settings.environment} HTTP ${res.status}: ${
        reason || "missing paymentId/formUrl"
      }`,
    );
  }

  await setFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${invoiceId}`,
    {
      cardProvider: toFirestoreString("qicard"),
      cardPaymentUrl: toFirestoreString(payment.formUrl),
      cardSessionAmount: toFirestoreNumber(checkoutAmount),
      cardProviderRef: toFirestoreString(payment.paymentId),
      qicardRequestId: toFirestoreString(requestId),
      qicardPaymentId: toFirestoreString(payment.paymentId),
    },
    [
      "cardProvider",
      "cardPaymentUrl",
      "cardSessionAmount",
      "cardProviderRef",
      "qicardRequestId",
      "qicardPaymentId",
    ],
  );

  return {
    redirectUrl: payment.formUrl,
    providerRef: payment.paymentId,
    requestId,
  };
}

export function mapQicardPaymentStatus(
  status: string,
  canceled: boolean,
): "paid" | "pending" | "failed" {
  if (canceled) return "failed";
  const s = status.trim().toUpperCase();
  if (s === "SUCCESS") return "paid";
  if (s === "CREATED") return "pending";
  return "failed";
}

export async function settleQicardInvoice(
  accessToken: string,
  projectId: string,
  paymentId: string,
): Promise<"settled" | "ignored" | "duplicate"> {
  const payment = await getQicardPaymentStatus(accessToken, projectId, paymentId);
  const eventId = sanitizeEventId(paymentId);
  const eventPayload = {
    paymentId: toFirestoreString(paymentId),
    requestId: toFirestoreString(payment.requestId),
    status: toFirestoreString(payment.status),
    amount: toFirestoreNumber(payment.amount),
    processedAt: toFirestoreString(new Date().toISOString()),
  };

  const state = mapQicardPaymentStatus(payment.status, payment.canceled);
  if (state !== "paid") {
    const statusKey = payment.status || "unknown";
    await logCardPaymentEvent(
      accessToken,
      projectId,
      QICARD_EVENTS_COLLECTION,
      `${eventId}_${statusKey}`,
      eventPayload,
    );
    return "ignored";
  }

  const claim = await claimCardPaymentEvent(
    accessToken,
    projectId,
    QICARD_EVENTS_COLLECTION,
    eventId,
    eventPayload,
  );
  if (claim === "duplicate") return "duplicate";

  const bankAccountId = await resolveSettlementBankAccountId(
    accessToken,
    projectId,
    "qicard",
  );
  if (!bankAccountId) {
    throw new Error("Card payment bank account missing");
  }

  const invoiceLookupId = payment.requestId.trim();
  if (!invoiceLookupId) {
    throw new Error("QiCard payment missing requestId");
  }

  return await settleCardInvoice({
    accessToken,
    projectId,
    eventsCollection: QICARD_EVENTS_COLLECTION,
    eventId,
    eventPayload,
    provider: "qicard",
    providerRef: paymentId,
    invoiceLookupId,
    amount: payment.amount,
    bankAccountId,
    extraInvoiceFields: {
      qicardPaymentId: toFirestoreString(paymentId),
    },
    claimEvent: false,
  });
}

export async function resolveQicardPaymentByRequestId(
  accessToken: string,
  projectId: string,
  requestId: string,
): Promise<QicardPaymentObject | null> {
  const trimmed = requestId.trim();
  if (!trimmed) return null;

  const invoiceFields = await getFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${trimmed}`,
  );
  let paymentId = "";

  if (!invoiceFields) {
    const { queryFirestoreCollection } = await import("./firestore-rest.ts");
    const matches = await queryFirestoreCollection(
      accessToken,
      projectId,
      INVOICES_COLLECTION,
      "qicardRequestId",
      "EQUAL",
      trimmed,
      1,
    );
    if (matches.length === 0) return null;
    paymentId = firestoreString(matches[0].fields, "qicardPaymentId") ||
      firestoreString(matches[0].fields, "cardProviderRef");
  } else {
    paymentId = firestoreString(invoiceFields, "qicardPaymentId") ||
      firestoreString(invoiceFields, "cardProviderRef");
  }

  if (!paymentId) return null;
  return await getQicardPaymentStatus(accessToken, projectId, paymentId);
}
