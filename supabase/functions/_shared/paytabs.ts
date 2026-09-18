/**
 * PayTabs API helpers, settings, and invoice settlement.
 */

import {
  createFirestoreDoc,
  firestoreBool,
  firestoreNumber,
  firestoreString,
  getFirestoreDoc,
  listFirestoreCollection,
  parseFirestoreFields,
  queryFirestoreCollection,
  setFirestoreDoc,
  toFirestoreBool,
  toFirestoreNumber,
  toFirestoreString,
  toFirestoreTimestamp,
} from "./firestore-rest.ts";

export const OS_SETTINGS_DOC = "os_settings/default";
export const PAYTABS_EVENTS_COLLECTION = "os_paytabs_events";
export const INVOICES_COLLECTION = "os_invoices";
export const BANK_ACCOUNTS_COLLECTION = "os_bank_accounts";
export const VOUCHERS_COLLECTION = "os_vouchers";

export type PaytabsRegion = "IRQ" | "ARE" | "SAU" | "EGY" | "JOR";

export type PaytabsSettings = {
  profileId: string;
  serverKey: string;
  clientKey: string;
  region: PaytabsRegion;
  currency: string;
  isEnabled: boolean;
  defaultBankAccountId: string;
};

export type PaytabsSettingsStatus = {
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

export function getReturnUrl(firebaseProjectId?: string): string {
  const ipnUrl = getIpnUrl(firebaseProjectId);
  const separator = ipnUrl.includes("?") ? "&" : "?";
  return `${ipnUrl}${separator}return=1`;
}

function parseRegion(value: string): PaytabsRegion {
  const v = value.trim().toUpperCase();
  if (v === "ARE" || v === "SAU" || v === "EGY" || v === "JOR" || v === "IRQ") {
    return v;
  }
  return "IRQ";
}

export async function loadPaytabsSettings(
  accessToken: string,
  projectId: string,
): Promise<PaytabsSettings | null> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return null;

  const profileId = firestoreString(fields, "paytabsProfileId");
  const serverKey = firestoreString(fields, "paytabsServerKey");
  const clientKey = firestoreString(fields, "paytabsClientKey");
  const region = parseRegion(firestoreString(fields, "paytabsRegion"));
  const currency = firestoreString(fields, "paytabsCurrency") || "IQD";
  const isEnabled = firestoreBool(fields, "paytabsEnabled");
  const defaultBankAccountId = firestoreString(fields, "paytabsDefaultBankAccountId");

  if (!profileId && !serverKey && !clientKey && !isEnabled) return null;

  return {
    profileId,
    serverKey,
    clientKey,
    region,
    currency,
    isEnabled,
    defaultBankAccountId,
  };
}

export async function getPaytabsSettingsStatus(
  accessToken: string,
  projectId: string,
): Promise<PaytabsSettingsStatus> {
  const settings = await loadPaytabsSettings(accessToken, projectId);
  if (!settings) {
    return {
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

  const hasServerKey = settings.serverKey.length > 0;
  const hasClientKey = settings.clientKey.length > 0;
  return {
    profileId: settings.profileId,
    region: settings.region,
    currency: settings.currency,
    isEnabled: settings.isEnabled,
    defaultBankAccountId: settings.defaultBankAccountId,
    hasServerKey,
    serverKeyPreview: hasServerKey ? maskSecret(settings.serverKey) : "",
    hasClientKey,
    clientKeyPreview: hasClientKey ? maskSecret(settings.clientKey) : "",
    configuredInFirestore: hasServerKey || hasClientKey || settings.isEnabled,
  };
}

export type SavePaytabsSettingsInput = {
  profileId?: string;
  serverKey?: string;
  clientKey?: string;
  region?: string;
  currency?: string;
  isEnabled?: boolean;
  defaultBankAccountId?: string;
};

export async function savePaytabsSettings(
  input: SavePaytabsSettingsInput,
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<PaytabsSettingsStatus> {
  const existing = await loadPaytabsSettings(accessToken, projectId);
  const profileId = (input.profileId ?? existing?.profileId ?? "").trim();
  const serverKey = input.serverKey !== undefined
    ? input.serverKey.trim()
    : (existing?.serverKey ?? "");
  const clientKey = input.clientKey !== undefined
    ? input.clientKey.trim()
    : (existing?.clientKey ?? "");
  const region = parseRegion(input.region ?? existing?.region ?? "IRQ");
  const currency = (input.currency ?? existing?.currency ?? "IQD").trim().toUpperCase();
  const isEnabled = input.isEnabled ?? existing?.isEnabled ?? false;
  const defaultBankAccountId = (
    input.defaultBankAccountId ?? existing?.defaultBankAccountId ?? ""
  ).trim();

  if (isEnabled) {
    if (!profileId) throw new Error("ERR_PAYTABS_PROFILE_REQUIRED");
    if (!serverKey) throw new Error("ERR_PAYTABS_SERVER_KEY_REQUIRED");
    if (!defaultBankAccountId) {
      throw new Error("ERR_PAYTABS_BANK_ACCOUNT_REQUIRED");
    }
  }

  const now = new Date().toISOString();
  const fields: Record<string, unknown> = {
    paytabsProfileId: toFirestoreString(profileId),
    paytabsRegion: toFirestoreString(region),
    paytabsCurrency: toFirestoreString(currency),
    paytabsEnabled: toFirestoreBool(isEnabled),
    paytabsDefaultBankAccountId: toFirestoreString(defaultBankAccountId),
    paytabsUpdatedAt: toFirestoreString(now),
    paytabsUpdatedBy: toFirestoreString(uid),
  };
  if (serverKey.length > 0) {
    fields.paytabsServerKey = toFirestoreString(serverKey);
  }
  if (clientKey.length > 0) {
    fields.paytabsClientKey = toFirestoreString(clientKey);
  }

  const mask = [
    "paytabsProfileId",
    "paytabsRegion",
    "paytabsCurrency",
    "paytabsEnabled",
    "paytabsDefaultBankAccountId",
    "paytabsUpdatedAt",
    "paytabsUpdatedBy",
  ];
  if (serverKey.length > 0) mask.push("paytabsServerKey");
  if (clientKey.length > 0) mask.push("paytabsClientKey");

  await setFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC, fields, mask);
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

function amountsMatch(expected: number, received: number): boolean {
  return Math.abs(expected - received) < 0.01;
}

function formatDate(d: Date): string {
  const y = d.getUTCFullYear().toString().padStart(4, "0");
  const m = (d.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = d.getUTCDate().toString().padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function nextVoucherDisplayNumber(
  existing: Array<{ fields: Record<string, unknown> }>,
): string {
  let maxN = 100;
  const re = /^V-(\d+)$/i;
  for (const doc of existing) {
    const raw = firestoreString(doc.fields, "displayNumber");
    const m = re.exec(raw);
    if (m) {
      const n = Number(m[1]);
      if (n > maxN) maxN = n;
    }
  }
  return `V-${maxN + 1}`;
}

function sanitizeEventId(tranRef: string): string {
  return tranRef.replace(/[^A-Za-z0-9_-]/g, "_");
}

export async function settlePaytabsInvoice(
  accessToken: string,
  projectId: string,
  notification: PaytabsNotification,
): Promise<"settled" | "ignored" | "duplicate"> {
  const eventId = sanitizeEventId(notification.tranRef);
  const claim = await createFirestoreDoc(
    accessToken,
    projectId,
    PAYTABS_EVENTS_COLLECTION,
    eventId,
    {
      tranRef: toFirestoreString(notification.tranRef),
      cartId: toFirestoreString(notification.cartId),
      responseStatus: toFirestoreString(notification.responseStatus),
      cartAmount: toFirestoreNumber(notification.cartAmount),
      processedAt: toFirestoreTimestamp(new Date()),
    },
  );
  if (claim === "exists") return "duplicate";

  if (notification.responseStatus !== "A") {
    return "ignored";
  }

  const settings = await loadPaytabsSettings(accessToken, projectId);
  if (!settings?.isEnabled || !settings.defaultBankAccountId) {
    throw new Error("PayTabs settings missing or disabled");
  }

  let invoiceDoc = await getFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${notification.cartId}`,
  );
  let invoiceId = notification.cartId;

  if (!invoiceDoc) {
    const byCart = await queryFirestoreCollection(
      accessToken,
      projectId,
      INVOICES_COLLECTION,
      "paytabsCartId",
      "EQUAL",
      notification.cartId,
      1,
    );
    if (byCart.length > 0) {
      invoiceId = byCart[0].id;
      invoiceDoc = byCart[0].fields;
    }
  }

  if (!invoiceDoc) {
    const byDisplay = await queryFirestoreCollection(
      accessToken,
      projectId,
      INVOICES_COLLECTION,
      "displayNumber",
      "EQUAL",
      notification.cartId,
      1,
    );
    if (byDisplay.length > 0) {
      invoiceId = byDisplay[0].id;
      invoiceDoc = byDisplay[0].fields;
    }
  }

  if (!invoiceDoc) {
    throw new Error(`Invoice not found for cart_id ${notification.cartId}`);
  }

  const status = firestoreString(invoiceDoc, "status");
  if (status === "PAID") return "duplicate";

  const total = firestoreNumber(invoiceDoc, "total");
  if (!amountsMatch(total, notification.cartAmount)) {
    throw new Error(
      `Amount mismatch for invoice ${invoiceId}: expected ${total}, got ${notification.cartAmount}`,
    );
  }

  const bankAccountId = settings.defaultBankAccountId;
  const bankFields = await getFirestoreDoc(
    accessToken,
    projectId,
    `${BANK_ACCOUNTS_COLLECTION}/${bankAccountId}`,
  );
  if (!bankFields) {
    throw new Error(`Bank account missing: ${bankAccountId}`);
  }

  const bankBalance = firestoreNumber(bankFields, "balance");
  const clientName = firestoreString(invoiceDoc, "clientName");
  const voucherDocs = await listFirestoreCollection(
    accessToken,
    projectId,
    VOUCHERS_COLLECTION,
    500,
  );
  const voucherId = crypto.randomUUID();
  const voucherDisplay = nextVoucherDisplayNumber(voucherDocs);
  const now = new Date();

  await setFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${invoiceId}`,
    {
      status: toFirestoreString("PAID"),
      bankAccountId: toFirestoreString(bankAccountId),
      paymentMethod: toFirestoreString("CARD"),
      paytabsTranRef: toFirestoreString(notification.tranRef),
    },
    ["status", "bankAccountId", "paymentMethod", "paytabsTranRef"],
  );

  await setFirestoreDoc(
    accessToken,
    projectId,
    `${BANK_ACCOUNTS_COLLECTION}/${bankAccountId}`,
    {
      balance: toFirestoreNumber(bankBalance + total),
    },
    ["balance"],
  );

  await createFirestoreDoc(
    accessToken,
    projectId,
    VOUCHERS_COLLECTION,
    voucherId,
    {
      id: toFirestoreString(voucherId),
      displayNumber: toFirestoreString(voucherDisplay),
      type: toFirestoreString("RECEIPT"),
      amount: toFirestoreNumber(total),
      date: toFirestoreString(formatDate(now)),
      payeeOrPayer: toFirestoreString(clientName),
      description: toFirestoreString(`تحصيل فاتورة — ${clientName}`),
      bankAccountId: toFirestoreString(bankAccountId),
      status: toFirestoreString("COMPLETED"),
      invoiceId: toFirestoreString(invoiceId),
      source: toFirestoreString("INVOICE"),
      createdAt: toFirestoreTimestamp(now),
    },
  );

  return "settled";
}

export type CreateSessionResult = {
  redirectUrl: string;
  tranRef: string;
  cartId: string;
};

export async function createPaytabsSession(
  accessToken: string,
  projectId: string,
  invoiceId: string,
): Promise<CreateSessionResult> {
  const settings = await loadPaytabsSettings(accessToken, projectId);
  if (!settings?.isEnabled) throw new Error("ERR_PAYTABS_DISABLED");
  if (!settings.profileId || !settings.serverKey) {
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
  const existingRedirect = firestoreString(invoiceFields, "paytabsRedirectUrl");
  const existingTranRef = firestoreString(invoiceFields, "paytabsTranRef");
  const existingCartId = firestoreString(invoiceFields, "paytabsCartId");
  const existingAmount = firestoreNumber(invoiceFields, "paytabsSessionAmount");

  if (
    existingRedirect &&
    existingTranRef &&
    existingCartId === invoiceId &&
    amountsMatch(existingAmount, total)
  ) {
    return {
      redirectUrl: existingRedirect,
      tranRef: existingTranRef,
      cartId: invoiceId,
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
    return: getReturnUrl(projectId),
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
      paytabsCartId: toFirestoreString(invoiceId),
      paytabsTranRef: toFirestoreString(tranRef),
      paytabsRedirectUrl: toFirestoreString(redirectUrl),
      paytabsSessionAmount: toFirestoreNumber(total),
    },
    [
      "paytabsCartId",
      "paytabsTranRef",
      "paytabsRedirectUrl",
      "paytabsSessionAmount",
    ],
  );

  return { redirectUrl, tranRef, cartId: invoiceId };
}

export function invoiceFieldsToPlain(
  fields: Record<string, unknown>,
): Record<string, unknown> {
  return parseFirestoreFields(fields);
}
