import "https://deno.land/std@0.177.0/http/server.ts";
import {
  getServiceAccountForFirebaseProject,
  listAllowedFirebaseProjectIds,
} from "../_shared/firebase-edge.ts";
import {
  firestoreNumber,
  firestoreString,
  getAccessToken,
  getFirestoreDoc,
  queryFirestoreCollection,
} from "../_shared/firestore-rest.ts";
import {
  mapAlqasehPaymentStatus,
  settleAlqasehInvoice,
  verifyAlqasehPayment,
} from "../_shared/alqaseh.ts";
import {
  mapQicardPaymentStatus,
  resolveQicardPaymentByRequestId,
  settleQicardInvoice,
} from "../_shared/qicard.ts";
import {
  decodeZaincashCallbackJwtPayload,
  extractZaincashTokenFromSearch,
  loadZaincashSettings,
  mapZaincashPaymentStatus,
  normalizeZaincashRef,
  parseZaincashCallbackPayload,
  resolveZaincashTransactionForInvoice,
  settleZaincashInvoice,
  verifyZaincashCallbackJwt,
} from "../_shared/zaincash.ts";
import {
  mapPaytabsResponseStatus,
  parsePaytabsNotification,
  queryPaytabsTransaction,
  settlePaytabsInvoice,
} from "../_shared/paytabs.ts";
import { INVOICES_COLLECTION } from "../_shared/card-settlement.ts";

type PaymentState = "paid" | "pending" | "failed";

type StatusResponse = {
  state: PaymentState;
  invoiceNumber?: string;
  amount?: number;
  currency?: string;
};

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
  };
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

async function lookupInvoiceFields(
  accessToken: string,
  projectId: string,
  lookupId: string,
): Promise<Record<string, unknown> | null> {
  const id = lookupId.trim();
  if (!id) return null;

  let invoiceDoc = await getFirestoreDoc(
    accessToken,
    projectId,
    `${INVOICES_COLLECTION}/${id}`,
  );
  if (invoiceDoc) return invoiceDoc;

  const byCart = await queryFirestoreCollection(
    accessToken,
    projectId,
    INVOICES_COLLECTION,
    "paytabsCartId",
    "EQUAL",
    id,
    1,
  );
  if (byCart.length > 0) return byCart[0].fields;

  const byAlqasehOrder = await queryFirestoreCollection(
    accessToken,
    projectId,
    INVOICES_COLLECTION,
    "alqasehOrderId",
    "EQUAL",
    id,
    1,
  );
  if (byAlqasehOrder.length > 0) return byAlqasehOrder[0].fields;

  const byQicardRequest = await queryFirestoreCollection(
    accessToken,
    projectId,
    INVOICES_COLLECTION,
    "qicardRequestId",
    "EQUAL",
    id,
    1,
  );
  if (byQicardRequest.length > 0) return byQicardRequest[0].fields;

  const byDisplay = await queryFirestoreCollection(
    accessToken,
    projectId,
    INVOICES_COLLECTION,
    "displayNumber",
    "EQUAL",
    id,
    1,
  );
  if (byDisplay.length > 0) return byDisplay[0].fields;

  return null;
}

function invoiceSummary(
  fields: Record<string, unknown> | null,
  fallbackAmount?: number,
  fallbackCurrency?: string,
): Pick<StatusResponse, "invoiceNumber" | "amount" | "currency"> {
  if (!fields) {
    return {
      amount: fallbackAmount,
      currency: fallbackCurrency,
    };
  }
  const displayNumber = firestoreString(fields, "displayNumber");
  const total = firestoreNumber(fields, "total");
  return {
    invoiceNumber: displayNumber || undefined,
    amount: total > 0 ? total : fallbackAmount,
    currency: fallbackCurrency,
  };
}

async function resolveAlqasehStatus(
  accessToken: string,
  projectId: string,
  paymentId: string,
): Promise<StatusResponse> {
  let ctx;
  try {
    ctx = await verifyAlqasehPayment(accessToken, projectId, paymentId);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn("Alqaseh verify failed:", paymentId, msg);
    return { state: "failed" };
  }

  let state = mapAlqasehPaymentStatus(ctx.paymentStatus);

  if (state === "paid") {
    const result = await settleAlqasehInvoice(accessToken, projectId, paymentId);
    if (result === "ignored") {
      state = "failed";
    }
  }

  const lookupId = String(ctx.customData.invoiceId ?? ctx.orderId).trim();
  const invoiceFields = lookupId
    ? await lookupInvoiceFields(accessToken, projectId, lookupId)
    : null;

  if (invoiceFields && firestoreString(invoiceFields, "status") === "PAID") {
    state = "paid";
  }

  return {
    state,
    ...invoiceSummary(invoiceFields, ctx.amount, ctx.currency),
  };
}

type ZaincashCallbackSettleResult = {
  invoiceId: string;
  settleResult?: "settled" | "ignored" | "duplicate";
  callbackStatus: string;
};

async function trySettleFromZaincashCallbackToken(
  accessToken: string,
  projectId: string,
  callbackToken: string,
): Promise<ZaincashCallbackSettleResult | null> {
  const token = callbackToken.trim();
  if (!token) return null;

  const settings = await loadZaincashSettings(accessToken, projectId);
  const verifyKey = settings?.apiKey?.trim() ||
    settings?.clientSecret?.trim() ||
    "";

  let payload: Record<string, unknown> | null = null;
  if (verifyKey) {
    try {
      const decoded = await verifyZaincashCallbackJwt(token, verifyKey);
      payload = decoded.payload;
    } catch {
      payload = decodeZaincashCallbackJwtPayload(token);
    }
  } else {
    payload = decodeZaincashCallbackJwtPayload(token);
  }

  if (!payload) return null;
  const info = parseZaincashCallbackPayload(payload);
  if (!info) return null;

  let settleResult: "settled" | "ignored" | "duplicate" | undefined;
  if (
    mapZaincashPaymentStatus(info.currentStatus) === "paid" &&
    info.transactionId
  ) {
    try {
      settleResult = await settleZaincashInvoice(
        accessToken,
        projectId,
        info.transactionId,
      );
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.warn("ZainCash token settle failed:", info.transactionId, msg);
    }
  }

  return {
    invoiceId: info.orderId || normalizeZaincashRef(info.transactionId),
    settleResult,
    callbackStatus: info.currentStatus,
  };
}

async function resolveZaincashStatus(
  accessToken: string,
  projectId: string,
  invoiceId: string,
  callbackToken?: string,
): Promise<StatusResponse> {
  let normalizedInvoiceId = normalizeZaincashRef(invoiceId);

  if (callbackToken?.trim()) {
    const fromToken = await trySettleFromZaincashCallbackToken(
      accessToken,
      projectId,
      callbackToken,
    );
    if (fromToken?.invoiceId) {
      normalizedInvoiceId = fromToken.invoiceId;
    }
    if (fromToken?.settleResult === "ignored") {
      const invoiceFields = normalizedInvoiceId
        ? await lookupInvoiceFields(
          accessToken,
          projectId,
          normalizedInvoiceId,
        )
        : null;
      if (
        !invoiceFields ||
        firestoreString(invoiceFields, "status") !== "PAID"
      ) {
        return {
          state: "failed",
          ...invoiceSummary(invoiceFields),
        };
      }
    }
  }

  let txn;
  try {
    txn = await resolveZaincashTransactionForInvoice(
      accessToken,
      projectId,
      normalizedInvoiceId,
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn("ZainCash resolve failed:", normalizedInvoiceId, msg);
    return { state: "failed" };
  }

  if (!txn) {
    const invoiceFields = normalizedInvoiceId
      ? await lookupInvoiceFields(
        accessToken,
        projectId,
        normalizedInvoiceId,
      )
      : null;
    if (invoiceFields && firestoreString(invoiceFields, "status") === "PAID") {
      return {
        state: "paid",
        ...invoiceSummary(invoiceFields),
      };
    }
    return { state: "pending" };
  }

  let state = mapZaincashPaymentStatus(txn.status);

  if (state === "paid" && txn.transactionId) {
    const result = await settleZaincashInvoice(
      accessToken,
      projectId,
      txn.transactionId,
    );
    if (result === "ignored") {
      state = "failed";
    }
  }

  const invoiceFields = await lookupInvoiceFields(
    accessToken,
    projectId,
    normalizedInvoiceId,
  );

  if (invoiceFields && firestoreString(invoiceFields, "status") === "PAID") {
    state = "paid";
  }

  return {
    state,
    ...invoiceSummary(invoiceFields, txn.amount, txn.currency),
  };
}

async function resolveQicardStatus(
  accessToken: string,
  projectId: string,
  requestId: string,
): Promise<StatusResponse> {
  let payment;
  try {
    payment = await resolveQicardPaymentByRequestId(
      accessToken,
      projectId,
      requestId,
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn("QiCard resolve failed:", requestId, msg);
    return { state: "failed" };
  }

  if (!payment) {
    return { state: "pending" };
  }

  let state = mapQicardPaymentStatus(payment.status, payment.canceled);

  if (state === "paid" && payment.paymentId) {
    const result = await settleQicardInvoice(
      accessToken,
      projectId,
      payment.paymentId,
    );
    if (result === "ignored") {
      state = "failed";
    }
  }

  const invoiceFields = await lookupInvoiceFields(
    accessToken,
    projectId,
    requestId,
  );

  if (invoiceFields && firestoreString(invoiceFields, "status") === "PAID") {
    state = "paid";
  }

  return {
    state,
    ...invoiceSummary(invoiceFields, payment.amount, payment.currency),
  };
}

async function resolvePaytabsStatus(
  accessToken: string,
  projectId: string,
  tranRef: string,
): Promise<StatusResponse> {
  const query = await queryPaytabsTransaction(accessToken, projectId, tranRef);
  if (!query) {
    return { state: "pending" };
  }

  let state = mapPaytabsResponseStatus(query.responseStatus);

  if (state === "paid") {
    const notification = parsePaytabsNotification({
      tran_ref: query.tranRef,
      cart_id: query.cartId,
      cart_amount: query.cartAmount,
      payment_result: { response_status: query.responseStatus },
    });
    if (notification) {
      const result = await settlePaytabsInvoice(
        accessToken,
        projectId,
        notification,
      );
      if (result === "ignored") {
        state = "failed";
      }
    }
  }

  const lookupId = query.cartId.trim();
  const invoiceFields = lookupId
    ? await lookupInvoiceFields(accessToken, projectId, lookupId)
    : null;

  if (invoiceFields && firestoreString(invoiceFields, "status") === "PAID") {
    state = "paid";
  }

  return {
    state,
    ...invoiceSummary(invoiceFields, query.cartAmount, query.cartCurrency),
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders() });
  }

  if (req.method !== "GET") {
    return json({ errorCode: "ERR_METHOD_NOT_ALLOWED" }, 405);
  }

  const url = new URL(req.url);
  const provider = (url.searchParams.get("provider") ?? "").trim().toLowerCase();
  const projectId = (url.searchParams.get("firebaseProjectId") ?? "").trim();
  const rawRef = (url.searchParams.get("ref") ??
    url.searchParams.get("payment_id") ??
    url.searchParams.get("paymentId") ??
    url.searchParams.get("tranRef") ??
    url.searchParams.get("tran_ref") ??
    "").trim();
  const ref = provider === "zaincash"
    ? normalizeZaincashRef(rawRef)
    : rawRef;
  let zaincashToken = (url.searchParams.get("token") ?? "").trim();
  if (provider === "zaincash" && !zaincashToken) {
    zaincashToken = extractZaincashTokenFromSearch(url.search);
  }

  if (!provider || !projectId || !ref) {
    return json({ errorCode: "ERR_INVALID_REQUEST" }, 400);
  }

  const allowed = listAllowedFirebaseProjectIds();
  if (!allowed.includes(projectId)) {
    return json({ errorCode: "ERR_FORBIDDEN" }, 403);
  }

  try {
    getServiceAccountForFirebaseProject(projectId);
    const accessToken = await getAccessToken(
      getServiceAccountForFirebaseProject(projectId),
    );

    if (provider === "alqaseh") {
      const status = await resolveAlqasehStatus(accessToken, projectId, ref);
      return json(status);
    }

    if (provider === "paytabs") {
      const status = await resolvePaytabsStatus(accessToken, projectId, ref);
      return json(status);
    }

    if (provider === "qicard") {
      const status = await resolveQicardStatus(accessToken, projectId, ref);
      return json(status);
    }

    if (provider === "zaincash") {
      const status = await resolveZaincashStatus(
        accessToken,
        projectId,
        ref,
        zaincashToken,
      );
      return json(status);
    }

    return json({ errorCode: "ERR_INVALID_REQUEST" }, 400);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("card-payment-status error:", msg);
    return json({ errorCode: "ERR_INTERNAL" }, 500);
  }
});
