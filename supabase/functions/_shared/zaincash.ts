/**
 * ZainCash Payment Gateway API v2 helpers, settings, and invoice sessions.
 */

import {
  amountsMatch,
  claimCardPaymentEvent,
  INVOICES_COLLECTION,
  logCardPaymentEvent,
  sanitizeEventId,
  settleCardInvoice,
} from "./card-settlement.ts";
import {
  isZaincashEnabled,
  OS_SETTINGS_DOC,
  resolveSettlementBankAccountId,
} from "./card-settings.ts";
import {
  firestoreBool,
  firestoreNumber,
  firestoreString,
  getFirestoreDoc,
  setFirestoreDoc,
  toFirestoreNumber,
  toFirestoreString,
} from "./firestore-rest.ts";
import { buildZaincashRedirectUrls } from "./card-return-url.ts";
import { ensureInvoicePayLinkToken } from "./pay-link.ts";
import { maskSecret } from "./paytabs.ts";

export const ZAINCASH_EVENTS_COLLECTION = "os_zaincash_events";

export type ZaincashEnvironment = "test" | "live";

const UAT_API_BASE = "https://pg-api-uat.zaincash.iq";
const LIVE_API_BASE_DEFAULT = "https://pg-api.zaincash.iq";
const OAUTH_SCOPE = "payment:read payment:write";

export type ZaincashSettings = {
  environment: ZaincashEnvironment;
  clientId: string;
  clientSecret: string;
  apiKey: string;
  apiBase: string;
  serviceType: string;
  language: string;
  bankAccountId: string;
};

export type ZaincashSettingsStatus = {
  enabled: boolean;
  environment: ZaincashEnvironment;
  clientId: string;
  serviceType: string;
  liveApiBase: string;
  hasClientSecret: boolean;
  clientSecretPreview: string;
  hasApiKey: boolean;
  apiKeyPreview: string;
  configuredInFirestore: boolean;
};

type TokenCacheEntry = {
  token: string;
  expiresAt: number;
};

const tokenCache = new Map<string, TokenCacheEntry>();

function parseEnvironment(value: string): ZaincashEnvironment {
  return value.trim().toLowerCase() === "live" ? "live" : "test";
}

function cacheKey(projectId: string, environment: ZaincashEnvironment): string {
  return `${projectId}:${environment}`;
}

function loadCredentialsForEnvironment(
  fields: Record<string, unknown>,
  environment: ZaincashEnvironment,
): {
  clientId: string;
  clientSecret: string;
  apiKey: string;
  apiBase: string;
} {
  if (environment === "test") {
    return {
      clientId: firestoreString(fields, "zaincashTestClientId"),
      clientSecret: firestoreString(fields, "zaincashTestClientSecret"),
      apiKey: firestoreString(fields, "zaincashTestApiKey"),
      apiBase: UAT_API_BASE,
    };
  }
  const liveBase = firestoreString(fields, "zaincashLiveApiBase") ||
    LIVE_API_BASE_DEFAULT;
  return {
    clientId: firestoreString(fields, "zaincashLiveClientId"),
    clientSecret: firestoreString(fields, "zaincashLiveClientSecret"),
    apiKey: firestoreString(fields, "zaincashLiveApiKey"),
    apiBase: liveBase.replace(/\/+$/, "") || LIVE_API_BASE_DEFAULT,
  };
}

function resolveZaincashCredentials(
  fields: Record<string, unknown>,
): {
  environment: ZaincashEnvironment;
  clientId: string;
  clientSecret: string;
  apiKey: string;
  apiBase: string;
} | null {
  const preferred = parseEnvironment(
    firestoreString(fields, "zaincashEnvironment"),
  );
  const order: ZaincashEnvironment[] = preferred === "live"
    ? ["live", "test"]
    : ["test", "live"];

  for (const environment of order) {
    const creds = loadCredentialsForEnvironment(fields, environment);
    if (creds.clientId && creds.clientSecret) {
      const apiBase = environment === "live"
        ? (creds.apiBase || "").replace(/\/+$/, "")
        : UAT_API_BASE;
      if (environment === "live" && !apiBase) continue;
      return {
        environment,
        clientId: creds.clientId,
        clientSecret: creds.clientSecret,
        apiKey: creds.apiKey,
        apiBase: apiBase || UAT_API_BASE,
      };
    }
  }
  return null;
}

function zaincashApiBase(settings: ZaincashSettings): string {
  return settings.apiBase.replace(/\/+$/, "");
}

function normalizeIqdAmount(amount: number): number {
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error("ERR_INVOICE_INVALID_AMOUNT");
  }
  return Math.round(amount);
}

function formatIqdAmountString(amount: number): string {
  return String(normalizeIqdAmount(amount));
}

async function parseJsonResponse(res: Response): Promise<Record<string, unknown>> {
  const raw = await res.text();
  if (!raw.trim()) return {};
  try {
    return JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return { raw };
  }
}

export async function getZaincashAccessToken(
  settings: ZaincashSettings,
  projectId: string,
): Promise<string> {
  const key = cacheKey(projectId, settings.environment);
  const cached = tokenCache.get(key);
  const now = Date.now();
  if (cached && now < cached.expiresAt - 60_000) {
    return cached.token;
  }

  const base = zaincashApiBase(settings);
  const body = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: settings.clientId,
    client_secret: settings.clientSecret,
    scope: OAUTH_SCOPE,
  });

  const res = await fetch(`${base}/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  const data = await parseJsonResponse(res);
  const accessToken = String(data.access_token ?? "").trim();
  if (!res.ok || !accessToken) {
    console.error("ZainCash OAuth failed:", res.status, JSON.stringify(data));
    throw new Error("ERR_ZAINCASH_AUTH_FAILED");
  }

  const expiresIn = Number(data.expires_in ?? 3600);
  tokenCache.set(key, {
    token: accessToken,
    expiresAt: now + Math.max(60, expiresIn) * 1000,
  });
  return accessToken;
}

export type ZaincashTransactionDetails = {
  status: string;
  transactionId: string;
  orderId: string;
  amount: number;
  currency: string;
  redirectUrl?: string;
};

function parseTransactionDetails(
  json: Record<string, unknown>,
): ZaincashTransactionDetails {
  const details =
    (json.transactionDetails as Record<string, unknown> | undefined) ?? {};
  const amountMap =
    (details.amount as Record<string, unknown> | undefined) ?? {};
  const amountValue = Number(amountMap.value ?? 0);

  return {
    status: String(json.status ?? "").trim().toUpperCase(),
    transactionId: String(details.transactionId ?? "").trim(),
    orderId: String(details.orderId ?? "").trim(),
    amount: Number.isFinite(amountValue) ? amountValue : 0,
    currency: String(amountMap.currency ?? "IQD").trim().toUpperCase(),
    redirectUrl: String(json.redirectUrl ?? "").trim() || undefined,
  };
}

export async function loadZaincashSettings(
  accessToken: string,
  projectId: string,
): Promise<ZaincashSettings | null> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return null;
  const resolved = resolveZaincashCredentials(fields);
  if (!resolved) return null;

  const serviceType = firestoreString(fields, "zaincashServiceType") ||
    "Invoice";
  const bankAccountId = firestoreString(fields, "zaincashBankAccountId");
  const language = firestoreString(fields, "zaincashLanguage") || "ar";

  return {
    environment: resolved.environment,
    clientId: resolved.clientId,
    clientSecret: resolved.clientSecret,
    apiKey: resolved.apiKey,
    apiBase: resolved.apiBase,
    serviceType,
    language,
    bankAccountId,
  };
}

function emptyZaincashStatus(): ZaincashSettingsStatus {
  return {
    enabled: false,
    environment: "test",
    clientId: "",
    serviceType: "Invoice",
    liveApiBase: "",
    hasClientSecret: false,
    clientSecretPreview: "",
    hasApiKey: false,
    apiKeyPreview: "",
    configuredInFirestore: false,
  };
}

export async function getZaincashSettingsStatus(
  accessToken: string,
  projectId: string,
  environmentFilter?: string,
): Promise<ZaincashSettingsStatus> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return emptyZaincashStatus();

  const env = environmentFilter === "live" || environmentFilter === "test"
    ? parseEnvironment(environmentFilter)
    : parseEnvironment(firestoreString(fields, "zaincashEnvironment"));

  const creds = loadCredentialsForEnvironment(fields, env);
  const clientSecret = creds.clientSecret;
  const apiKey = creds.apiKey;

  return {
    enabled: firestoreBool(fields, "zaincashEnabled"),
    environment: env,
    clientId: creds.clientId,
    serviceType: firestoreString(fields, "zaincashServiceType") || "Invoice",
    liveApiBase: firestoreString(fields, "zaincashLiveApiBase"),
    hasClientSecret: clientSecret.length > 0,
    clientSecretPreview: maskSecret(clientSecret),
    hasApiKey: apiKey.length > 0,
    apiKeyPreview: maskSecret(apiKey),
    configuredInFirestore: Boolean(
      creds.clientId && creds.clientSecret &&
        (env !== "live" || firestoreString(fields, "zaincashLiveApiBase") ||
          LIVE_API_BASE_DEFAULT),
    ),
  };
}

export async function saveZaincashSettings(
  input: {
    environment?: string;
    clientId?: string;
    clientSecret?: string;
    apiKey?: string;
    serviceType?: string;
    liveApiBase?: string;
    language?: string;
  },
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<ZaincashSettingsStatus> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC) ??
    {};
  const environment = parseEnvironment(
    input.environment ?? firestoreString(fields, "zaincashEnvironment"),
  );

  const clientId = (input.clientId ??
    loadCredentialsForEnvironment(fields, environment).clientId).trim();
  const clientSecretInput = (input.clientSecret ?? "").trim();
  const existingSecret = loadCredentialsForEnvironment(
    fields,
    environment,
  ).clientSecret;
  const clientSecret = clientSecretInput || existingSecret;

  const apiKeyInput = (input.apiKey ?? "").trim();
  const existingApiKey = loadCredentialsForEnvironment(
    fields,
    environment,
  ).apiKey;
  const apiKey = apiKeyInput || existingApiKey;

  if (!clientId || !clientSecret) {
    throw new Error("ERR_ZAINCASH_NOT_CONFIGURED");
  }

  const serviceType = (input.serviceType ??
    firestoreString(fields, "zaincashServiceType") ??
    "Invoice").trim();
  const liveApiBase = (input.liveApiBase ??
    firestoreString(fields, "zaincashLiveApiBase")).trim().replace(/\/+$/, "");
  const language = (input.language ??
    firestoreString(fields, "zaincashLanguage") ??
    "ar").trim();

  const resolvedLiveBase = liveApiBase || LIVE_API_BASE_DEFAULT;

  const now = new Date().toISOString();
  const docFields: Record<string, unknown> = {
    zaincashServiceType: toFirestoreString(serviceType),
    zaincashLanguage: toFirestoreString(language),
    zaincashEnvironment: toFirestoreString(environment),
    zaincashUpdatedAt: toFirestoreString(now),
    zaincashUpdatedBy: toFirestoreString(uid),
  };
  const mask = [
    "zaincashServiceType",
    "zaincashLanguage",
    "zaincashEnvironment",
    "zaincashUpdatedAt",
    "zaincashUpdatedBy",
  ];

  if (environment === "test") {
    docFields.zaincashTestClientId = toFirestoreString(clientId);
    mask.push("zaincashTestClientId");
    if (clientSecretInput.length > 0) {
      docFields.zaincashTestClientSecret = toFirestoreString(clientSecretInput);
      mask.push("zaincashTestClientSecret");
    }
    if (apiKeyInput.length > 0) {
      docFields.zaincashTestApiKey = toFirestoreString(apiKeyInput);
      mask.push("zaincashTestApiKey");
    }
  } else {
    docFields.zaincashLiveClientId = toFirestoreString(clientId);
    docFields.zaincashLiveApiBase = toFirestoreString(resolvedLiveBase);
    mask.push("zaincashLiveClientId", "zaincashLiveApiBase");
    if (clientSecretInput.length > 0) {
      docFields.zaincashLiveClientSecret = toFirestoreString(clientSecretInput);
      mask.push("zaincashLiveClientSecret");
    }
    if (apiKeyInput.length > 0) {
      docFields.zaincashLiveApiKey = toFirestoreString(apiKeyInput);
      mask.push("zaincashLiveApiKey");
    }
  }

  await setFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC, docFields, mask);
  tokenCache.delete(cacheKey(projectId, environment));
  return await getZaincashSettingsStatus(accessToken, projectId, environment);
}

export async function getZaincashTransactionStatus(
  accessToken: string,
  projectId: string,
  transactionId: string,
): Promise<ZaincashTransactionDetails> {
  const settings = await loadZaincashSettings(accessToken, projectId);
  if (!settings) throw new Error("ERR_ZAINCASH_NOT_CONFIGURED");

  const token = await getZaincashAccessToken(settings, projectId);
  const base = zaincashApiBase(settings);
  const url =
    `${base}/api/v2/payment-gateway/transaction/inquiry/${encodeURIComponent(transactionId)}`;

  const res = await fetch(url, {
    method: "GET",
    headers: { Authorization: `Bearer ${token}` },
  });

  const data = await parseJsonResponse(res);
  if (!res.ok) {
    throw new Error(
      `ZainCash inquiry failed: ${res.status} ${JSON.stringify(data)}`,
    );
  }
  return parseTransactionDetails(data);
}

/** Only reuse hosted URL while checkout can still be completed (not after failure/expiry). */
const REUSABLE_STATUSES = new Set([
  "PENDING",
  "OTP_SENT",
  "CUSTOMER_AUTHENTICATION_REQUIRED",
]);

export type CreateZaincashSessionResult = {
  redirectUrl: string;
  providerRef: string;
};

export async function createZaincashSession(
  accessToken: string,
  projectId: string,
  invoiceId: string,
  returnBaseUrl?: string,
): Promise<CreateZaincashSessionResult> {
  const enabled = await isZaincashEnabled(accessToken, projectId);
  if (!enabled) throw new Error("ERR_CARD_PAYMENT_DISABLED");

  const settings = await loadZaincashSettings(accessToken, projectId);
  if (!settings) throw new Error("ERR_ZAINCASH_NOT_CONFIGURED");

  const invoiceFields = await getFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${invoiceId}`,
  );
  if (!invoiceFields) throw new Error("ERR_INVOICE_NOT_FOUND");

  const invoiceStatus = firestoreString(invoiceFields, "status");
  if (invoiceStatus === "PAID") throw new Error("ERR_INVOICE_ALREADY_PAID");

  const total = firestoreNumber(invoiceFields, "total");
  let payLinkToken = firestoreString(invoiceFields, "payLinkToken");
  if (payLinkToken.length < 16) {
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
  const existingTxnId = firestoreString(invoiceFields, "zaincashTransactionId");

  if (
    existingProvider === "zaincash" &&
    existingUrl &&
    existingRef &&
    amountsMatch(existingAmount, total)
  ) {
    try {
      const txn = await getZaincashTransactionStatus(
        accessToken,
        projectId,
        existingRef || existingTxnId,
      );
      if (REUSABLE_STATUSES.has(txn.status) && existingUrl) {
        return {
          redirectUrl: existingUrl,
          providerRef: existingRef || txn.transactionId,
        };
      }
    } catch {
      // Create a new payment.
    }
  }

  const { successUrl, failureUrl } = buildZaincashRedirectUrls(
    projectId,
    invoiceId,
    payLinkToken,
    returnBaseUrl,
  );

  const externalReferenceId = crypto.randomUUID();
  const checkoutAmount = normalizeIqdAmount(total);
  const oauthToken = await getZaincashAccessToken(settings, projectId);
  const base = zaincashApiBase(settings);

  const payload: Record<string, unknown> = {
    language: settings.language === "en" ? "en" : "ar",
    externalReferenceId,
    orderId: invoiceId,
    serviceType: settings.serviceType,
    amount: {
      value: formatIqdAmountString(checkoutAmount),
      currency: "IQD",
    },
    redirectUrls: {
      successUrl,
      failureUrl,
    },
  };

  const res = await fetch(
    `${base}/api/v2/payment-gateway/transaction/init`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${oauthToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    },
  );

  const data = await parseJsonResponse(res);
  if (!res.ok) {
    console.error("ZainCash init failed:", res.status, JSON.stringify(data));
    throw new Error("ERR_ZAINCASH_CREATE_FAILED");
  }

  const session = parseTransactionDetails(data);
  const redirectUrl = session.redirectUrl ||
    String(data.redirectUrl ?? "").trim();
  const transactionId = session.transactionId;

  if (!redirectUrl || !transactionId) {
    throw new Error("ERR_ZAINCASH_CREATE_FAILED");
  }

  await setFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${invoiceId}`,
    {
      cardProvider: toFirestoreString("zaincash"),
      cardPaymentUrl: toFirestoreString(redirectUrl),
      cardSessionAmount: toFirestoreNumber(checkoutAmount),
      cardProviderRef: toFirestoreString(transactionId),
      zaincashTransactionId: toFirestoreString(transactionId),
    },
    [
      "cardProvider",
      "cardPaymentUrl",
      "cardSessionAmount",
      "cardProviderRef",
      "zaincashTransactionId",
    ],
  );

  return { redirectUrl, providerRef: transactionId };
}

export function mapZaincashPaymentStatus(
  status: string,
): "paid" | "pending" | "failed" {
  const s = status.trim().toUpperCase();
  if (s === "SUCCESS") return "paid";
  if (
    s === "PENDING" ||
    s === "OTP_SENT" ||
    s === "CUSTOMER_AUTHENTICATION_REQUIRED"
  ) {
    return "pending";
  }
  return "failed";
}

export async function settleZaincashInvoice(
  accessToken: string,
  projectId: string,
  transactionId: string,
): Promise<"settled" | "ignored" | "duplicate"> {
  const txn = await getZaincashTransactionStatus(
    accessToken,
    projectId,
    transactionId,
  );
  const eventId = sanitizeEventId(transactionId);
  const eventPayload = {
    transactionId: toFirestoreString(transactionId),
    orderId: toFirestoreString(txn.orderId),
    status: toFirestoreString(txn.status),
    amount: toFirestoreNumber(txn.amount),
    processedAt: toFirestoreString(new Date().toISOString()),
  };

  const state = mapZaincashPaymentStatus(txn.status);
  if (state !== "paid") {
    const statusKey = txn.status || "unknown";
    await logCardPaymentEvent(
      accessToken,
      projectId,
      ZAINCASH_EVENTS_COLLECTION,
      `${eventId}_${statusKey}`,
      eventPayload,
    );
    return "ignored";
  }

  const claim = await claimCardPaymentEvent(
    accessToken,
    projectId,
    ZAINCASH_EVENTS_COLLECTION,
    eventId,
    eventPayload,
  );
  if (claim === "duplicate") return "duplicate";

  const bankAccountId = await resolveSettlementBankAccountId(
    accessToken,
    projectId,
    "zaincash",
  );
  if (!bankAccountId) {
    throw new Error("Card payment bank account missing");
  }

  const invoiceLookupId = txn.orderId.trim() || transactionId.trim();
  if (!invoiceLookupId) {
    throw new Error("ZainCash payment missing orderId");
  }

  return await settleCardInvoice({
    accessToken,
    projectId,
    eventsCollection: ZAINCASH_EVENTS_COLLECTION,
    eventId,
    eventPayload,
    provider: "zaincash",
    providerRef: transactionId,
    invoiceLookupId,
    amount: txn.amount,
    bankAccountId,
    extraInvoiceFields: {
      zaincashTransactionId: toFirestoreString(transactionId),
    },
    claimEvent: false,
  });
}

export async function resolveZaincashTransactionForInvoice(
  accessToken: string,
  projectId: string,
  invoiceLookupId: string,
): Promise<ZaincashTransactionDetails | null> {
  const trimmed = invoiceLookupId.trim();
  if (!trimmed) return null;

  const invoiceFields = await getFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${trimmed}`,
  );

  let transactionId = "";
  if (invoiceFields) {
    transactionId = firestoreString(invoiceFields, "zaincashTransactionId") ||
      firestoreString(invoiceFields, "cardProviderRef");
  }

  if (!transactionId) return null;
  return await getZaincashTransactionStatus(
    accessToken,
    projectId,
    transactionId,
  );
}

function base64UrlToBytes(segment: string): Uint8Array {
  const padded = segment.replace(/-/g, "+").replace(/_/g, "/") +
    "===".slice((segment.length + 3) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/** Verify HS256 JWT callback token (redirect/webhook). */
export async function verifyZaincashCallbackJwt(
  token: string,
  secret: string,
): Promise<{ verified: boolean; payload: Record<string, unknown> }> {
  const parts = token.trim().split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid JWT");
  }

  const [headerB64, payloadB64, signatureB64] = parts;
  const header = JSON.parse(new TextDecoder().decode(base64UrlToBytes(headerB64)));
  if (header.alg !== "HS256") {
    return {
      verified: false,
      payload: JSON.parse(new TextDecoder().decode(base64UrlToBytes(payloadB64))),
    };
  }

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signature = base64UrlToBytes(signatureB64);
  const verified = await crypto.subtle.verify(
    "HMAC",
    key,
    signature,
    signingInput,
  );

  const payload = JSON.parse(
    new TextDecoder().decode(base64UrlToBytes(payloadB64)),
  ) as Record<string, unknown>;

  return { verified, payload };
}
