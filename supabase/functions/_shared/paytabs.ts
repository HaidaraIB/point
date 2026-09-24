/**
 * PayTabs API helpers, settings, and invoice settlement.
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
  loadActiveCardProvider,
  loadCardDefaultBankAccountId,
  OS_SETTINGS_DOC,
  resolveSettlementBankAccountId,
} from "./card-settings.ts";
import {
  firestoreBool,
  firestoreNumber,
  firestoreString,
  getFirestoreDoc,
  parseFirestoreFields,
  queryFirestoreCollection,
  setFirestoreDoc,
  toFirestoreNumber,
  toFirestoreString,
} from "./firestore-rest.ts";

export { OS_SETTINGS_DOC };
export const PAYTABS_EVENTS_COLLECTION = "os_paytabs_events";

export type PaytabsRegion = "IRQ" | "ARE" | "SAU" | "EGY" | "JOR";
export type PaytabsEnvironment = "test" | "live";

export type PaytabsSettings = {
  environment: PaytabsEnvironment;
  profileId: string;
  serverKey: string;
  clientKey: string;
  region: PaytabsRegion;
  currency: string;
  isEnabled: boolean;
  defaultBankAccountId: string;
};

export type PaytabsSettingsStatus = {
  environment: PaytabsEnvironment;
  profileId: string;
  region: PaytabsRegion;
  currency: string;
  isEnabled: boolean;
  defaultBankAccountId: string;
  hasServerKey: boolean;
  serverKeyPreview: string;
  hasClientKey: boolean;
  clientKeyPreview: string;
  configuredInFirestore: boolean;
};

const REGION_BASE_URL: Record<PaytabsRegion, string> = {
  IRQ: "https://secure-iraq.paytabs.com",
  ARE: "https://secure.paytabs.com",
  SAU: "https://secure.paytabs.sa",
  EGY: "https://secure-egypt.paytabs.com",
  JOR: "https://secure-jordan.paytabs.com",
};

export function paytabsBaseUrl(region: string): string {
  const key = (region.trim().toUpperCase() || "IRQ") as PaytabsRegion;
  return REGION_BASE_URL[key] ?? REGION_BASE_URL.IRQ;
}

export function maskSecret(value: string): string {
  const v = value.trim();
  if (v.length <= 8) return "••••••••";
  return `${v.slice(0, 4)}••••${v.slice(-4)}`;
}

export function getIpnUrl(firebaseProjectId?: string): string {
  const base = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
  if (!base) throw new Error("SUPABASE_URL not set");
  const url = `${base}/functions/v1/paytabs-ipn`;
  const projectId = (firebaseProjectId ?? "").trim();
  if (!projectId) return url;
  return `${url}?firebaseProjectId=${encodeURIComponent(projectId)}`;
}

import {
  buildPaytabsAppReturnRedirect,
  normalizeReturnBaseUrl,
} from "./card-return-url.ts";

export function getReturnUrl(
  firebaseProjectId?: string,
  returnBaseUrl?: string,
): string {
  const ipnUrl = getIpnUrl(firebaseProjectId);
  const separator = ipnUrl.includes("?") ? "&" : "?";
  let url = `${ipnUrl}${separator}return=1`;
  const appBase = normalizeReturnBaseUrl(returnBaseUrl);
  if (appBase) {
    url += `&appBase=${encodeURIComponent(appBase)}`;
  }
  return url;
}

function parseRegion(value: string): PaytabsRegion {
  const v = value.trim().toUpperCase();
  if (v === "ARE" || v === "SAU" || v === "EGY" || v === "JOR" || v === "IRQ") {
    return v;
  }
  return "IRQ";
}

function parseEnvironment(value: string): PaytabsEnvironment {
  return value.trim().toLowerCase() === "live" ? "live" : "test";
}

function loadCredentialsForEnvironment(
  fields: Record<string, unknown>,
  environment: PaytabsEnvironment,
): {
  profileId: string;
  serverKey: string;
  clientKey: string;
  region: PaytabsRegion;
  currency: string;
} {
  if (environment === "test") {
    return {
      profileId: firestoreString(fields, "paytabsTestProfileId"),
      serverKey: firestoreString(fields, "paytabsTestServerKey"),
      clientKey: firestoreString(fields, "paytabsTestClientKey"),
      region: parseRegion(firestoreString(fields, "paytabsTestRegion")),
      currency: firestoreString(fields, "paytabsTestCurrency") || "IQD",
    };
  }
  return {
    profileId: firestoreString(fields, "paytabsProfileId"),
    serverKey: firestoreString(fields, "paytabsServerKey"),
    clientKey: firestoreString(fields, "paytabsClientKey"),
    region: parseRegion(firestoreString(fields, "paytabsRegion")),
    currency: firestoreString(fields, "paytabsCurrency") || "IQD",
  };
}

export async function loadPaytabsSettings(
  accessToken: string,
  projectId: string,
): Promise<PaytabsSettings | null> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return null;

  const environment = parseEnvironment(
    firestoreString(fields, "paytabsEnvironment"),
  );
  const creds = loadCredentialsForEnvironment(fields, environment);
  const active = await loadActiveCardProvider(accessToken, projectId);
  const isEnabled = active === "paytabs" ||
    (!firestoreString(fields, "activeCardProvider") &&
      firestoreBool(fields, "paytabsEnabled"));
  const defaultBankAccountId = await loadCardDefaultBankAccountId(
    accessToken,
    projectId,
  );

  if (
    !creds.profileId && !creds.serverKey && !creds.clientKey && !isEnabled
  ) {
    return null;
  }

  return {
    environment,
    ...creds,
    isEnabled,
    defaultBankAccountId,
  };
}

/** Returns server keys for both environments (for IPN signature verification). */
export async function loadPaytabsServerKeys(
  accessToken: string,
  projectId: string,
): Promise<string[]> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return [];
  const keys: string[] = [];
  const live = firestoreString(fields, "paytabsServerKey");
  const test = firestoreString(fields, "paytabsTestServerKey");
  if (live) keys.push(live);
  if (test && test !== live) keys.push(test);
  return keys;
}

export async function getPaytabsSettingsStatus(
  accessToken: string,
  projectId: string,
  environmentOverride?: PaytabsEnvironment,
): Promise<PaytabsSettingsStatus> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) {
    return {
      environment: environmentOverride ?? "test",
      profileId: "",
      region: "IRQ",
      currency: "IQD",
      isEnabled: false,
      defaultBankAccountId: "",
      hasServerKey: false,
      serverKeyPreview: "",
      hasClientKey: false,
      clientKeyPreview: "",
      configuredInFirestore: false,
    };
  }

  const storedEnv = parseEnvironment(firestoreString(fields, "paytabsEnvironment"));
  const environment = environmentOverride ?? storedEnv;
  const creds = loadCredentialsForEnvironment(fields, environment);
  const active = await loadActiveCardProvider(accessToken, projectId);
  const isEnabled = active === "paytabs" ||
    (!firestoreString(fields, "activeCardProvider") &&
      firestoreBool(fields, "paytabsEnabled"));
  const defaultBankAccountId = await loadCardDefaultBankAccountId(
    accessToken,
    projectId,
  );
  const hasServerKey = creds.serverKey.length > 0;
  const hasClientKey = creds.clientKey.length > 0;

  return {
    environment,
    profileId: creds.profileId,
    region: creds.region,
    currency: creds.currency,
    isEnabled,
    defaultBankAccountId,
    hasServerKey,
    serverKeyPreview: hasServerKey ? maskSecret(creds.serverKey) : "",
    hasClientKey,
    clientKeyPreview: hasClientKey ? maskSecret(creds.clientKey) : "",
    configuredInFirestore: hasServerKey || hasClientKey || isEnabled,
  };
}

export type SavePaytabsSettingsInput = {
  environment?: string;
  profileId?: string;
  serverKey?: string;
  clientKey?: string;
  region?: string;
  currency?: string;
};

export async function savePaytabsSettings(
  input: SavePaytabsSettingsInput,
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<PaytabsSettingsStatus> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  const existingEnv = fields
    ? parseEnvironment(firestoreString(fields, "paytabsEnvironment"))
    : "test";
  const environment = parseEnvironment(input.environment ?? existingEnv);
  const existingCreds = fields
    ? loadCredentialsForEnvironment(fields, environment)
    : {
      profileId: "",
      serverKey: "",
      clientKey: "",
      region: "IRQ" as PaytabsRegion,
      currency: "IQD",
    };

  const profileId = (input.profileId ?? existingCreds.profileId).trim();
  const serverKey = input.serverKey !== undefined
    ? input.serverKey.trim()
    : existingCreds.serverKey;
  const clientKey = input.clientKey !== undefined
    ? input.clientKey.trim()
    : existingCreds.clientKey;
  const region = parseRegion(input.region ?? existingCreds.region);
  const currency = (input.currency ?? existingCreds.currency).trim().toUpperCase();

  const now = new Date().toISOString();
  const docFields: Record<string, unknown> = {
    paytabsEnvironment: toFirestoreString(environment),
    paytabsUpdatedAt: toFirestoreString(now),
    paytabsUpdatedBy: toFirestoreString(uid),
  };
  const mask = ["paytabsEnvironment", "paytabsUpdatedAt", "paytabsUpdatedBy"];

  if (environment === "test") {
    docFields.paytabsTestProfileId = toFirestoreString(profileId);
    docFields.paytabsTestRegion = toFirestoreString(region);
    docFields.paytabsTestCurrency = toFirestoreString(currency);
    mask.push("paytabsTestProfileId", "paytabsTestRegion", "paytabsTestCurrency");
    if (serverKey.length > 0) {
      docFields.paytabsTestServerKey = toFirestoreString(serverKey);
      mask.push("paytabsTestServerKey");
    }
    if (clientKey.length > 0) {
      docFields.paytabsTestClientKey = toFirestoreString(clientKey);
      mask.push("paytabsTestClientKey");
    }
  } else {
    docFields.paytabsProfileId = toFirestoreString(profileId);
    docFields.paytabsRegion = toFirestoreString(region);
    docFields.paytabsCurrency = toFirestoreString(currency);
    mask.push("paytabsProfileId", "paytabsRegion", "paytabsCurrency");
    if (serverKey.length > 0) {
      docFields.paytabsServerKey = toFirestoreString(serverKey);
      mask.push("paytabsServerKey");
    }
    if (clientKey.length > 0) {
      docFields.paytabsClientKey = toFirestoreString(clientKey);
      mask.push("paytabsClientKey");
    }
  }

  await setFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC, docFields, mask);
  return await getPaytabsSettingsStatus(accessToken, projectId);
}

export async function verifyPaytabsSignature(
  rawBody: string,
  signatureHeader: string,
  serverKey: string,
): Promise<boolean> {
  const provided = signatureHeader.trim();
  if (!provided || !serverKey) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(serverKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(rawBody),
  );
  const expected = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return timingSafeEqual(expected.toLowerCase(), provided.toLowerCase());
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

export type PaytabsNotification = {
  tranRef: string;
  cartId: string;
  cartAmount: number;
  responseStatus: string;
  responseMessage: string;
};

export function parsePaytabsNotification(
  payload: Record<string, unknown>,
): PaytabsNotification | null {
  const paymentResult = payload.payment_result as Record<string, unknown> | undefined;
  const tranRef = String(payload.tran_ref ?? "").trim();
  const cartId = String(payload.cart_id ?? "").trim();
  const amountRaw = payload.cart_amount ?? payload.cart_total ?? 0;
  const cartAmount = Number(amountRaw);
  const responseStatus = String(
    paymentResult?.response_status ?? payload.response_status ?? "",
  ).trim();
  const responseMessage = String(
    paymentResult?.response_message ?? payload.response_message ?? "",
  ).trim();

  if (!tranRef || !cartId) return null;
  return {
    tranRef,
    cartId,
    cartAmount,
    responseStatus,
    responseMessage,
  };
}

/** Used by the app return page when PayTabs omits status but IPN already paid. */
export async function isPaytabsInvoicePaid(
  accessToken: string,
  projectId: string,
  cartId?: string,
  tranRef?: string,
): Promise<boolean> {
  const cart = (cartId ?? "").trim();
  const tran = (tranRef ?? "").trim();

  if (cart) {
    const direct = await getFirestoreDoc(
      accessToken,
      projectId,
      `${INVOICES_COLLECTION}/${cart}`,
    );
    if (direct && firestoreString(direct, "status") === "PAID") return true;

    const byCart = await queryFirestoreCollection(
      accessToken,
      projectId,
      INVOICES_COLLECTION,
      "paytabsCartId",
      "EQUAL",
      cart,
      1,
    );
    if (byCart.length > 0 &&
      firestoreString(byCart[0].fields, "status") === "PAID") {
      return true;
    }
  }

  if (tran) {
    const byTran = await queryFirestoreCollection(
      accessToken,
      projectId,
      INVOICES_COLLECTION,
      "paytabsTranRef",
      "EQUAL",
      tran,
      1,
    );
    if (byTran.length > 0 &&
      firestoreString(byTran[0].fields, "status") === "PAID") {
      return true;
    }
  }

  return false;
}

export type PaytabsQueryResult = {
  tranRef: string;
  cartId: string;
  cartAmount: number;
  cartCurrency: string;
  responseStatus: string;
};

/** Query PayTabs for authoritative transaction status (used by return page status endpoint). */
export async function queryPaytabsTransaction(
  accessToken: string,
  projectId: string,
  tranRef: string,
): Promise<PaytabsQueryResult | null> {
  const ref = tranRef.trim();
  if (!ref) return null;

  const settings = await loadPaytabsSettings(accessToken, projectId);
  if (!settings?.profileId || !settings.serverKey) return null;

  const body = {
    profile_id: Number(settings.profileId),
    tran_ref: ref,
  };

  const baseUrl = paytabsBaseUrl(settings.region);
  const res = await fetch(`${baseUrl}/payment/query`, {
    method: "POST",
    headers: {
      Authorization: settings.serverKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const data = await res.json().catch(() => ({})) as Record<string, unknown>;
  if (!res.ok) {
    console.error("PayTabs query failed:", res.status, JSON.stringify(data));
    return null;
  }

  const paymentResult = data.payment_result as Record<string, unknown> | undefined;
  const responseStatus = String(
    paymentResult?.response_status ?? data.response_status ?? "",
  ).trim().toUpperCase();
  const cartId = String(data.cart_id ?? "").trim();
  const cartAmount = Number(data.cart_amount ?? 0);
  const cartCurrency = String(data.cart_currency ?? settings.currency).trim();

  return {
    tranRef: String(data.tran_ref ?? ref).trim(),
    cartId,
    cartAmount,
    cartCurrency,
    responseStatus,
  };
}

export function mapPaytabsResponseStatus(
  responseStatus: string,
): "paid" | "pending" | "failed" {
  const status = responseStatus.trim().toUpperCase();
  if (status === "A") return "paid";
  if (status === "H" || status === "P") return "pending";
  return "failed";
}

export async function settlePaytabsInvoice(
  accessToken: string,
  projectId: string,
  notification: PaytabsNotification,
): Promise<"settled" | "ignored" | "duplicate"> {
  const eventId = sanitizeEventId(notification.tranRef);
  const eventPayload = {
    tranRef: toFirestoreString(notification.tranRef),
    cartId: toFirestoreString(notification.cartId),
    responseStatus: toFirestoreString(notification.responseStatus),
    cartAmount: toFirestoreNumber(notification.cartAmount),
    processedAt: toFirestoreString(new Date().toISOString()),
  };

  if (notification.responseStatus !== "A") {
    const statusKey = notification.responseStatus || "unknown";
    await logCardPaymentEvent(
      accessToken,
      projectId,
      PAYTABS_EVENTS_COLLECTION,
      `${eventId}_${statusKey}`,
      eventPayload,
    );
    return "ignored";
  }

  const claim = await claimCardPaymentEvent(
    accessToken,
    projectId,
    PAYTABS_EVENTS_COLLECTION,
    eventId,
    eventPayload,
  );
  if (claim === "duplicate") return "duplicate";

  const bankAccountId = await resolveSettlementBankAccountId(
    accessToken,
    projectId,
    "paytabs",
  );
  if (!bankAccountId) {
    throw new Error("PayTabs settings missing or disabled");
  }

  return await settleCardInvoice({
    accessToken,
    projectId,
    eventsCollection: PAYTABS_EVENTS_COLLECTION,
    eventId,
    eventPayload,
    provider: "paytabs",
    providerRef: notification.tranRef,
    invoiceLookupId: notification.cartId,
    amount: notification.cartAmount,
    bankAccountId,
    extraInvoiceFields: {
      paytabsTranRef: toFirestoreString(notification.tranRef),
    },
    claimEvent: false,
  });
}

export type CreateSessionResult = {
  redirectUrl: string;
  providerRef: string;
  cartId: string;
  provider: "paytabs";
};

export async function createPaytabsSession(
  accessToken: string,
  projectId: string,
  invoiceId: string,
  returnBaseUrl?: string,
): Promise<CreateSessionResult> {
  const active = await loadActiveCardProvider(accessToken, projectId);
  if (active !== "paytabs") throw new Error("ERR_CARD_PAYMENT_DISABLED");

  const settings = await loadPaytabsSettings(accessToken, projectId);
  if (!settings?.profileId || !settings.serverKey) {
    throw new Error("ERR_PAYTABS_NOT_CONFIGURED");
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
  const clientName = firestoreString(invoiceFields, "clientName");
  const clientEmail = firestoreString(invoiceFields, "clientEmail");
  const clientPhone = firestoreString(invoiceFields, "clientPhone");
  const existingProvider = firestoreString(invoiceFields, "cardProvider");
  const existingRedirect = firestoreString(invoiceFields, "cardPaymentUrl") ||
    firestoreString(invoiceFields, "paytabsRedirectUrl");
  const existingTranRef = firestoreString(invoiceFields, "cardProviderRef") ||
    firestoreString(invoiceFields, "paytabsTranRef");
  const existingCartId = firestoreString(invoiceFields, "paytabsCartId");
  const existingAmount = firestoreNumber(invoiceFields, "cardSessionAmount") ||
    firestoreNumber(invoiceFields, "paytabsSessionAmount");

  if (
    existingProvider === "paytabs" &&
    existingRedirect &&
    existingTranRef &&
    (existingCartId === invoiceId || existingCartId === "") &&
    amountsMatch(existingAmount, total)
  ) {
    return {
      redirectUrl: existingRedirect,
      providerRef: existingTranRef,
      cartId: invoiceId,
      provider: "paytabs",
    };
  }

  const cartDescription = displayNumber
    ? `Invoice ${displayNumber}`
    : `Invoice ${invoiceId}`;

  const customerDetails: Record<string, unknown> = {
    name: clientName || "Customer",
  };
  if (clientEmail) customerDetails.email = clientEmail;
  if (clientPhone) customerDetails.phone = clientPhone;
  customerDetails.country = "IQ";
  customerDetails.ip = "127.0.0.1";

  const body = {
    profile_id: Number(settings.profileId),
    tran_type: "sale",
    tran_class: "ecom",
    cart_id: invoiceId,
    cart_description: cartDescription,
    cart_currency: settings.currency,
    cart_amount: total,
    hide_shipping: true,
    callback: getIpnUrl(projectId),
    return: getReturnUrl(projectId, returnBaseUrl),
    customer_details: customerDetails,
  };

  const baseUrl = paytabsBaseUrl(settings.region);
  const res = await fetch(`${baseUrl}/payment/request`, {
    method: "POST",
    headers: {
      Authorization: settings.serverKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const data = await res.json().catch(() => ({})) as Record<string, unknown>;
  if (!res.ok) {
    throw new Error(
      `PayTabs request failed: ${res.status} ${JSON.stringify(data)}`,
    );
  }

  const redirectUrl = String(data.redirect_url ?? "").trim();
  const tranRef = String(data.tran_ref ?? "").trim();
  if (!redirectUrl) {
    throw new Error(`PayTabs response missing redirect_url: ${JSON.stringify(data)}`);
  }

  await setFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${invoiceId}`,
    {
      cardProvider: toFirestoreString("paytabs"),
      cardPaymentUrl: toFirestoreString(redirectUrl),
      cardSessionAmount: toFirestoreNumber(total),
      cardProviderRef: toFirestoreString(tranRef),
      paytabsCartId: toFirestoreString(invoiceId),
      paytabsTranRef: toFirestoreString(tranRef),
      paytabsRedirectUrl: toFirestoreString(redirectUrl),
      paytabsSessionAmount: toFirestoreNumber(total),
    },
    [
      "cardProvider",
      "cardPaymentUrl",
      "cardSessionAmount",
      "cardProviderRef",
      "paytabsCartId",
      "paytabsTranRef",
      "paytabsRedirectUrl",
      "paytabsSessionAmount",
    ],
  );

  return { redirectUrl, providerRef: tranRef, cartId: invoiceId, provider: "paytabs" };
}

export function invoiceFieldsToPlain(
  fields: Record<string, unknown>,
): Record<string, unknown> {
  return parseFirestoreFields(fields);
}
