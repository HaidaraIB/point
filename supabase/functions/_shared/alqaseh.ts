/**
 * Alqaseh Payment Gateway helpers, settings, and invoice sessions.
 */

import {
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
  loadActiveCardProvider,
  loadCardDefaultBankAccountId,
  OS_SETTINGS_DOC,
  resolveSettlementBankAccountId,
} from "./card-settings.ts";
import { ensureInvoicePayLinkToken } from "./pay-link.ts";
import { maskSecret } from "./paytabs.ts";

export const ALQASEH_EVENTS_COLLECTION = "os_alqaseh_events";

export type AlqasehEnvironment = "test" | "live";

export type AlqasehSettings = {
  environment: AlqasehEnvironment;
  clientId: string;
  clientSecret: string;
  currency: string;
  tokenExpiryHours: number;
  defaultBankAccountId: string;
};

export type AlqasehSettingsStatus = {
  environment: AlqasehEnvironment;
  clientId: string;
  currency: string;
  tokenExpiryHours: number;
  defaultBankAccountId: string;
  hasClientSecret: boolean;
  clientSecretPreview: string;
  configuredInFirestore: boolean;
};

const API_BASE: Record<AlqasehEnvironment, string> = {
  test: "https://api-test.alqaseh.com/v1",
  live: "https://api.alqaseh.com/v1",
};

const PAY_PAGE_BASE: Record<AlqasehEnvironment, string> = {
  test: "https://pay-test.alqaseh.com/pay",
  live: "https://pay.alqaseh.com/pay",
};

export const ALQASEH_SANDBOX_CLIENT_ID = "public_test";
export const ALQASEH_SANDBOX_CLIENT_SECRET = "Lr10yWWmm1dXLoI7VgXCrQVnlq13c1G0";

function parseEnvironment(value: string): AlqasehEnvironment {
  return value.trim().toLowerCase() === "live" ? "live" : "test";
}

export function alqasehApiBaseUrl(environment: AlqasehEnvironment): string {
  return API_BASE[environment];
}

export function alqasehPayPageUrl(
  environment: AlqasehEnvironment,
  token: string,
): string {
  const base = PAY_PAGE_BASE[environment].replace(/\/+$/, "");
  const t = token.trim();
  return `${base}/${encodeURIComponent(t)}`;
}

export function getAlqasehWebhookUrl(firebaseProjectId?: string): string {
  const base = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
  if (!base) throw new Error("SUPABASE_URL not set");
  const url = `${base}/functions/v1/alqaseh-webhook`;
  const projectId = (firebaseProjectId ?? "").trim();
  if (!projectId) return url;
  return `${url}?firebaseProjectId=${encodeURIComponent(projectId)}`;
}

import { getAppCardPaymentReturnUrl } from "./card-return-url.ts";

export function getAlqasehReturnUrl(
  firebaseProjectId?: string,
  returnBaseUrl?: string,
  payLinkToken?: string,
): string {
  return getAppCardPaymentReturnUrl(
    firebaseProjectId,
    returnBaseUrl,
    payLinkToken,
  );
}

function basicAuthHeader(clientId: string, clientSecret: string): string {
  const encoded = btoa(`${clientId}:${clientSecret}`);
  return `Basic ${encoded}`;
}

function resolveAlqasehCredentials(
  fields: Record<string, unknown>,
): {
  environment: AlqasehEnvironment;
  clientId: string;
  clientSecret: string;
} | null {
  const preferred = parseEnvironment(
    firestoreString(fields, "alqasehEnvironment"),
  );
  const order: AlqasehEnvironment[] = preferred === "live"
    ? ["live", "test"]
    : ["test", "live"];

  for (const environment of order) {
    const { clientId, clientSecret } = loadCredentialsForEnvironment(
      fields,
      environment,
    );
    if (clientId && clientSecret) {
      return { environment, clientId, clientSecret };
    }
  }
  return null;
}

function normalizeCheckoutAmount(amount: number, currency: string): number {
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error("ERR_INVOICE_INVALID_AMOUNT");
  }
  const cur = currency.trim().toUpperCase();
  if (cur === "IQD") return Math.round(amount);
  return Math.round(amount * 100) / 100;
}

function normalizeTokenExpiryHours(value: number): number {
  const hours = Math.round(Number.isFinite(value) ? value : 72);
  return Math.max(1, Math.min(hours, 720));
}

function sanitizeAlqasehEmail(email: string): string | undefined {
  const trimmed = email.trim();
  if (!trimmed || trimmed.length > 80) return undefined;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) return undefined;
  return trimmed;
}

function buildPaymentDescription(
  displayNumber: string,
  invoiceId: string,
): string {
  const fromDisplay = displayNumber.trim();
  if (fromDisplay.length > 0) {
    return `Invoice ${fromDisplay}`.slice(0, 250);
  }
  const fromId = invoiceId.trim();
  if (fromId.length > 0) return `Invoice ${fromId}`.slice(0, 250);
  return "Invoice payment";
}

/** Alqaseh stores order_id as varchar(32) despite a higher OpenAPI maxLength. */
const ALQASEH_ORDER_ID_MAX = 32;

function buildAlqasehOrderId(invoiceId: string, displayNumber = ""): string {
  const ts = Date.now().toString(36);
  const fromDisplay = displayNumber.replace(/[^A-Za-z0-9]/g, "").slice(0, 12);
  if (fromDisplay.length >= 4) {
    const candidate = `${fromDisplay}${ts}`.slice(0, ALQASEH_ORDER_ID_MAX);
    if (candidate.length >= 4) return candidate;
  }
  const compactId = invoiceId.replace(/[^A-Za-z0-9]/g, "").slice(0, 12);
  const orderId = `${compactId}${ts}`.slice(0, ALQASEH_ORDER_ID_MAX);
  return orderId.length >= 4 ? orderId : ts.slice(0, ALQASEH_ORDER_ID_MAX);
}

async function parseAlqasehErrorResponse(
  res: Response,
): Promise<Record<string, unknown>> {
  const raw = await res.text();
  if (!raw.trim()) return {};
  try {
    return JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return { raw };
  }
}

function alqasehApiErrorCode(
  status: number,
  data: Record<string, unknown>,
): string {
  const err = String(data.err ?? data.error ?? data.message ?? "").trim();
  const errorCode = String(data.error_code ?? data.errorCode ?? "").trim();
  if (status === 401) return "ERR_ALQASEH_UNAUTHORIZED";
  if (errorCode) return `ERR_ALQASEH_${errorCode.toUpperCase()}`;
  if (err) return "ERR_ALQASEH_CREATE_FAILED";
  if (status === 400) return "ERR_ALQASEH_INVALID_REQUEST";
  return "ERR_ALQASEH_CREATE_FAILED";
}

function loadCredentialsForEnvironment(
  fields: Record<string, unknown>,
  environment: AlqasehEnvironment,
): { clientId: string; clientSecret: string } {
  if (environment === "test") {
    return {
      clientId: firestoreString(fields, "alqasehTestClientId"),
      clientSecret: firestoreString(fields, "alqasehTestClientSecret"),
    };
  }
  return {
    clientId: firestoreString(fields, "alqasehLiveClientId"),
    clientSecret: firestoreString(fields, "alqasehLiveClientSecret"),
  };
}

export async function loadAlqasehSettings(
  accessToken: string,
  projectId: string,
): Promise<AlqasehSettings | null> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return null;

  const resolved = resolveAlqasehCredentials(fields);
  if (!resolved) return null;

  const currency = firestoreString(fields, "alqasehCurrency") || "IQD";
  const tokenExpiryRaw = firestoreNumber(fields, "alqasehTokenExpiryHours");
  const tokenExpiryHours = normalizeTokenExpiryHours(
    tokenExpiryRaw > 0 ? tokenExpiryRaw : 72,
  );
  const defaultBankAccountId = await loadCardDefaultBankAccountId(
    accessToken,
    projectId,
  );

  return {
    environment: resolved.environment,
    clientId: resolved.clientId,
    clientSecret: resolved.clientSecret,
    currency,
    tokenExpiryHours,
    defaultBankAccountId,
  };
}

export async function getAlqasehSettingsStatus(
  accessToken: string,
  projectId: string,
  environmentOverride?: AlqasehEnvironment,
): Promise<AlqasehSettingsStatus> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) {
    return {
      environment: environmentOverride ?? "test",
      clientId: "",
      currency: "IQD",
      tokenExpiryHours: 72,
      defaultBankAccountId: "",
      hasClientSecret: false,
      clientSecretPreview: "",
      configuredInFirestore: false,
    };
  }

  const storedEnv = parseEnvironment(firestoreString(fields, "alqasehEnvironment"));
  const environment = environmentOverride ?? storedEnv;
  const { clientId, clientSecret } = loadCredentialsForEnvironment(
    fields,
    environment,
  );
  const currency = firestoreString(fields, "alqasehCurrency") || "IQD";
  const tokenExpiryRaw = firestoreNumber(fields, "alqasehTokenExpiryHours");
  const tokenExpiryHours = normalizeTokenExpiryHours(
    tokenExpiryRaw > 0 ? tokenExpiryRaw : 72,
  );
  const defaultBankAccountId = await loadCardDefaultBankAccountId(
    accessToken,
    projectId,
  );
  const hasClientSecret = clientSecret.length > 0;

  return {
    environment,
    clientId,
    currency,
    tokenExpiryHours,
    defaultBankAccountId,
    hasClientSecret,
    clientSecretPreview: hasClientSecret ? maskSecret(clientSecret) : "",
    configuredInFirestore: hasClientSecret || clientId.length > 0,
  };
}

export type SaveAlqasehSettingsInput = {
  environment?: string;
  clientId?: string;
  clientSecret?: string;
  currency?: string;
  tokenExpiryHours?: number;
};

export async function saveAlqasehSettings(
  input: SaveAlqasehSettingsInput,
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<AlqasehSettingsStatus> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  const existingEnv = fields
    ? parseEnvironment(firestoreString(fields, "alqasehEnvironment"))
    : "test";
  const environment = parseEnvironment(input.environment ?? existingEnv);

  const existingCreds = fields
    ? loadCredentialsForEnvironment(fields, environment)
    : { clientId: "", clientSecret: "" };

  const clientId = (input.clientId ?? existingCreds.clientId).trim();
  const clientSecret = input.clientSecret !== undefined
    ? input.clientSecret.trim()
    : existingCreds.clientSecret;
  const currency = (input.currency ??
    (fields ? firestoreString(fields, "alqasehCurrency") : "") ??
    "IQD").trim().toUpperCase();
  const tokenExpiryHours = normalizeTokenExpiryHours(
    input.tokenExpiryHours ??
      (fields ? firestoreNumber(fields, "alqasehTokenExpiryHours") : 0) ??
      72,
  );

  const hasUsableCredentials = clientId.length > 0 &&
    (clientSecret.length > 0 || existingCreds.clientSecret.length > 0);

  const now = new Date().toISOString();
  const docFields: Record<string, unknown> = {
    alqasehCurrency: toFirestoreString(currency),
    alqasehTokenExpiryHours: toFirestoreNumber(tokenExpiryHours),
    alqasehUpdatedAt: toFirestoreString(now),
    alqasehUpdatedBy: toFirestoreString(uid),
  };
  const mask = [
    "alqasehCurrency",
    "alqasehTokenExpiryHours",
    "alqasehUpdatedAt",
    "alqasehUpdatedBy",
  ];
  if (hasUsableCredentials) {
    docFields.alqasehEnvironment = toFirestoreString(environment);
    mask.push("alqasehEnvironment");
  }

  if (environment === "test") {
    docFields.alqasehTestClientId = toFirestoreString(clientId);
    mask.push("alqasehTestClientId");
    if (clientSecret.length > 0) {
      docFields.alqasehTestClientSecret = toFirestoreString(clientSecret);
      mask.push("alqasehTestClientSecret");
    }
  } else {
    docFields.alqasehLiveClientId = toFirestoreString(clientId);
    mask.push("alqasehLiveClientId");
    if (clientSecret.length > 0) {
      docFields.alqasehLiveClientSecret = toFirestoreString(clientSecret);
      mask.push("alqasehLiveClientSecret");
    }
  }

  await setFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC, docFields, mask);
  return await getAlqasehSettingsStatus(accessToken, projectId);
}

export type AlqasehPaymentContext = {
  paymentId: string;
  paymentStatus: string;
  amount: number;
  orderId: string;
  currency: string;
  customData: Record<string, unknown>;
};

export async function verifyAlqasehPayment(
  accessToken: string,
  projectId: string,
  paymentId: string,
): Promise<AlqasehPaymentContext> {
  const settings = await loadAlqasehSettings(accessToken, projectId);
  if (!settings?.clientId || !settings.clientSecret) {
    throw new Error("ERR_ALQASEH_NOT_CONFIGURED");
  }

  const apiBase = alqasehApiBaseUrl(settings.environment);
  const res = await fetch(
    `${apiBase}/egw/payments/${encodeURIComponent(paymentId)}`,
    {
      method: "GET",
      headers: {
        Authorization: basicAuthHeader(
          settings.clientId,
          settings.clientSecret,
        ),
      },
    },
  );

  const data = await parseAlqasehErrorResponse(res);
  if (!res.ok) {
    throw new Error(
      `Alqaseh verify failed: ${res.status} ${JSON.stringify(data)}`,
    );
  }

  return {
    paymentId: String(data.payment_id ?? paymentId).trim(),
    paymentStatus: String(data.payment_status ?? "").trim().toLowerCase(),
    amount: Number(data.amount ?? 0),
    orderId: String(data.order_id ?? "").trim(),
    currency: String(data.currency ?? "").trim(),
    customData: (data.custom_data as Record<string, unknown>) ?? {},
  };
}

const REUSABLE_STATUSES = new Set(["prepared", "retried"]);

export type CreateAlqasehSessionResult = {
  redirectUrl: string;
  providerRef: string;
  orderId: string;
};

export async function createAlqasehSession(
  accessToken: string,
  projectId: string,
  invoiceId: string,
  returnBaseUrl?: string,
): Promise<CreateAlqasehSessionResult> {
  const active = await loadActiveCardProvider(accessToken, projectId);
  if (active !== "alqaseh") throw new Error("ERR_CARD_PAYMENT_DISABLED");

  const settings = await loadAlqasehSettings(accessToken, projectId);
  if (!settings?.clientId || !settings.clientSecret) {
    throw new Error("ERR_ALQASEH_NOT_CONFIGURED");
  }

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
  const clientEmail = firestoreString(invoiceFields, "clientEmail");
  const existingProvider = firestoreString(invoiceFields, "cardProvider");
  const existingUrl = firestoreString(invoiceFields, "cardPaymentUrl");
  const existingRef = firestoreString(invoiceFields, "cardProviderRef");
  const existingAmount = firestoreNumber(invoiceFields, "cardSessionAmount");
  const existingOrderId = firestoreString(invoiceFields, "alqasehOrderId");

  if (
    existingProvider === "alqaseh" &&
    existingUrl &&
    existingRef &&
    amountsMatch(existingAmount, total)
  ) {
    try {
      const ctx = await verifyAlqasehPayment(
        accessToken,
        projectId,
        existingRef,
      );
      if (REUSABLE_STATUSES.has(ctx.paymentStatus)) {
        return {
          redirectUrl: existingUrl,
          providerRef: existingRef,
          orderId: existingOrderId || ctx.orderId,
        };
      }
    } catch {
      // Fall through to create a new context.
    }
  }

  let payLinkToken = firestoreString(invoiceFields, "payLinkToken");
  if (payLinkToken.length < 8) {
    payLinkToken = await ensureInvoicePayLinkToken(
      accessToken,
      projectId,
      invoiceId,
    );
  }

  const orderId = buildAlqasehOrderId(invoiceId, displayNumber);
  const checkoutAmount = normalizeCheckoutAmount(total, settings.currency);
  const description = buildPaymentDescription(displayNumber, invoiceId);
  const tokenExpiryHours = normalizeTokenExpiryHours(settings.tokenExpiryHours);
  const sanitizedEmail = sanitizeAlqasehEmail(clientEmail);

  const body: Record<string, unknown> = {
    amount: checkoutAmount,
    currency: settings.currency.trim().toUpperCase(),
    description,
    order_id: orderId,
    transaction_type: "Retail",
    redirect_url: getAlqasehReturnUrl(projectId, returnBaseUrl, payLinkToken),
    webhook_url: getAlqasehWebhookUrl(projectId),
    token_expiry_in_hour: tokenExpiryHours,
    country: "IQ",
    custom_data: {
      invoiceId,
      firebaseProjectId: projectId,
    },
  };
  if (sanitizedEmail) body.email = sanitizedEmail;

  const apiBase = alqasehApiBaseUrl(settings.environment);
  const res = await fetch(`${apiBase}/egw/payments/create`, {
    method: "POST",
    headers: {
      Authorization: basicAuthHeader(
        settings.clientId,
        settings.clientSecret,
      ),
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const data = await parseAlqasehErrorResponse(res);
  if (!res.ok) {
    const code = alqasehApiErrorCode(res.status, data);
    console.error(
      "Alqaseh create failed:",
      res.status,
      JSON.stringify(data),
      "payload:",
      JSON.stringify({
        amount: checkoutAmount,
        currency: body.currency,
        environment: settings.environment,
        orderId,
        hasEmail: Boolean(sanitizedEmail),
        tokenExpiryHours,
      }),
    );
    throw new Error(code);
  }

  const paymentId = String(data.payment_id ?? "").trim();
  const token = String(data.token ?? "").trim();
  if (!paymentId || !token) {
    throw new Error(
      `Alqaseh response missing payment_id/token: ${JSON.stringify(data)}`,
    );
  }

  const redirectUrl = alqasehPayPageUrl(settings.environment, token);

  await setFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${invoiceId}`,
    {
      cardProvider: toFirestoreString("alqaseh"),
      cardPaymentUrl: toFirestoreString(redirectUrl),
      cardSessionAmount: toFirestoreNumber(checkoutAmount),
      cardProviderRef: toFirestoreString(paymentId),
      alqasehOrderId: toFirestoreString(orderId),
    },
    [
      "cardProvider",
      "cardPaymentUrl",
      "cardSessionAmount",
      "cardProviderRef",
      "alqasehOrderId",
    ],
  );

  return { redirectUrl, providerRef: paymentId, orderId };
}

export async function settleAlqasehInvoice(
  accessToken: string,
  projectId: string,
  paymentId: string,
): Promise<"settled" | "ignored" | "duplicate"> {
  const ctx = await verifyAlqasehPayment(accessToken, projectId, paymentId);
  const eventId = sanitizeEventId(paymentId);
  const eventPayload = {
    paymentId: toFirestoreString(paymentId),
    orderId: toFirestoreString(ctx.orderId),
    paymentStatus: toFirestoreString(ctx.paymentStatus),
    amount: toFirestoreNumber(ctx.amount),
    processedAt: toFirestoreString(new Date().toISOString()),
  };

  if (ctx.paymentStatus !== "succeeded") {
    const statusKey = ctx.paymentStatus || "unknown";
    await logCardPaymentEvent(
      accessToken,
      projectId,
      ALQASEH_EVENTS_COLLECTION,
      `${eventId}_${statusKey}`,
      eventPayload,
    );
    return "ignored";
  }

  const claim = await claimCardPaymentEvent(
    accessToken,
    projectId,
    ALQASEH_EVENTS_COLLECTION,
    eventId,
    eventPayload,
  );
  if (claim === "duplicate") return "duplicate";

  const bankAccountId = await resolveSettlementBankAccountId(
    accessToken,
    projectId,
    "alqaseh",
  );
  if (!bankAccountId) {
    throw new Error("Card payment bank account missing");
  }

  const invoiceLookupId = String(ctx.customData.invoiceId ?? ctx.orderId).trim();
  if (!invoiceLookupId) {
    throw new Error("Alqaseh payment missing invoice reference");
  }

  return await settleCardInvoice({
    accessToken,
    projectId,
    eventsCollection: ALQASEH_EVENTS_COLLECTION,
    eventId,
    eventPayload,
    provider: "alqaseh",
    providerRef: paymentId,
    invoiceLookupId,
    amount: ctx.amount,
    bankAccountId,
    claimEvent: false,
  });
}

export function mapAlqasehPaymentStatus(
  paymentStatus: string,
): "paid" | "pending" | "failed" {
  const status = paymentStatus.trim().toLowerCase();
  if (status === "succeeded") return "paid";
  if (
    status === "prepared" ||
    status === "pending" ||
    status === "unknown" ||
    status === "retried"
  ) {
    return "pending";
  }
  return "failed";
}
