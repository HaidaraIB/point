/**
 * Shared invoice settlement for card payment providers (PayTabs, Alqaseh).
 */

import {
  createFirestoreDoc,
  firestoreNumber,
  firestoreString,
  getFirestoreDoc,
  listFirestoreCollection,
  queryFirestoreCollection,
  setFirestoreDoc,
  toFirestoreNumber,
  toFirestoreString,
  toFirestoreTimestamp,
} from "./firestore-rest.ts";

export const INVOICES_COLLECTION = "os_invoices";
export const BANK_ACCOUNTS_COLLECTION = "os_bank_accounts";
export const VOUCHERS_COLLECTION = "os_vouchers";

export type CardProvider = "paytabs" | "alqaseh";

export function amountsMatch(expected: number, received: number): boolean {
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

export function sanitizeEventId(value: string): string {
  return value.replace(/[^A-Za-z0-9_-]/g, "_");
}

export async function claimCardPaymentEvent(
  accessToken: string,
  projectId: string,
  eventsCollection: string,
  eventId: string,
  eventPayload: Record<string, unknown>,
): Promise<"claimed" | "duplicate"> {
  const claim = await createFirestoreDoc(
    accessToken,
    projectId,
    eventsCollection,
    eventId,
    eventPayload,
  );
  return claim === "exists" ? "duplicate" : "claimed";
}

/** Audit log for non-successful payment events (does not block future success claims). */
export async function logCardPaymentEvent(
  accessToken: string,
  projectId: string,
  eventsCollection: string,
  eventId: string,
  eventPayload: Record<string, unknown>,
): Promise<void> {
  try {
    await createFirestoreDoc(
      accessToken,
      projectId,
      eventsCollection,
      eventId,
      eventPayload,
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn("logCardPaymentEvent failed:", eventId, msg);
  }
}

export type SettleCardInvoiceInput = {
  accessToken: string;
  projectId: string;
  eventsCollection: string;
  eventId: string;
  eventPayload: Record<string, unknown>;
  provider: CardProvider;
  providerRef: string;
  invoiceLookupId: string;
  amount: number;
  bankAccountId: string;
  /** Extra invoice fields to write (e.g. paytabsTranRef). */
  extraInvoiceFields?: Record<string, unknown>;
  /** If false, skip idempotency claim (already claimed). */
  claimEvent?: boolean;
};

export async function settleCardInvoice(
  input: SettleCardInvoiceInput,
): Promise<"settled" | "duplicate"> {
  if (input.claimEvent !== false) {
    const claim = await createFirestoreDoc(
      input.accessToken,
      input.projectId,
      input.eventsCollection,
      input.eventId,
      input.eventPayload,
    );
    if (claim === "exists") return "duplicate";
  }

  let invoiceDoc = await getFirestoreDoc(
    input.accessToken,
    input.projectId,
    `${INVOICES_COLLECTION}/${input.invoiceLookupId}`,
  );
  let invoiceId = input.invoiceLookupId;

  if (!invoiceDoc) {
    const byCart = await queryFirestoreCollection(
      input.accessToken,
      input.projectId,
      INVOICES_COLLECTION,
      "paytabsCartId",
      "EQUAL",
      input.invoiceLookupId,
      1,
    );
    if (byCart.length > 0) {
      invoiceId = byCart[0].id;
      invoiceDoc = byCart[0].fields;
    }
  }

  if (!invoiceDoc) {
    const byAlqasehOrder = await queryFirestoreCollection(
      input.accessToken,
      input.projectId,
      INVOICES_COLLECTION,
      "alqasehOrderId",
      "EQUAL",
      input.invoiceLookupId,
      1,
    );
    if (byAlqasehOrder.length > 0) {
      invoiceId = byAlqasehOrder[0].id;
      invoiceDoc = byAlqasehOrder[0].fields;
    }
  }

  if (!invoiceDoc) {
    const byDisplay = await queryFirestoreCollection(
      input.accessToken,
      input.projectId,
      INVOICES_COLLECTION,
      "displayNumber",
      "EQUAL",
      input.invoiceLookupId,
      1,
    );
    if (byDisplay.length > 0) {
      invoiceId = byDisplay[0].id;
      invoiceDoc = byDisplay[0].fields;
    }
  }

  if (!invoiceDoc) {
    throw new Error(`Invoice not found for lookup ${input.invoiceLookupId}`);
  }

  const status = firestoreString(invoiceDoc, "status");
  if (status === "PAID") return "duplicate";

  const total = firestoreNumber(invoiceDoc, "total");
  if (!amountsMatch(total, input.amount)) {
    throw new Error(
      `Amount mismatch for invoice ${invoiceId}: expected ${total}, got ${input.amount}`,
    );
  }

  const bankFields = await getFirestoreDoc(
    input.accessToken,
    input.projectId,
    `${BANK_ACCOUNTS_COLLECTION}/${input.bankAccountId}`,
  );
  if (!bankFields) {
    throw new Error(`Bank account missing: ${input.bankAccountId}`);
  }

  const bankBalance = firestoreNumber(bankFields, "balance");
  const clientName = firestoreString(invoiceDoc, "clientName");
  const voucherDocs = await listFirestoreCollection(
    input.accessToken,
    input.projectId,
    VOUCHERS_COLLECTION,
    500,
  );
  const voucherId = crypto.randomUUID();
  const voucherDisplay = nextVoucherDisplayNumber(voucherDocs);
  const now = new Date();

  const invoiceFields: Record<string, unknown> = {
    status: toFirestoreString("PAID"),
    bankAccountId: toFirestoreString(input.bankAccountId),
    paymentMethod: toFirestoreString("CARD"),
    cardProvider: toFirestoreString(input.provider),
    cardProviderRef: toFirestoreString(input.providerRef),
    ...(input.extraInvoiceFields ?? {}),
  };
  const invoiceMask = [
    "status",
    "bankAccountId",
    "paymentMethod",
    "cardProvider",
    "cardProviderRef",
    ...Object.keys(input.extraInvoiceFields ?? {}),
  ];

  await setFirestoreDoc(
    input.accessToken,
    input.projectId,
    `${INVOICES_COLLECTION}/${invoiceId}`,
    invoiceFields,
    invoiceMask,
  );

  await setFirestoreDoc(
    input.accessToken,
    input.projectId,
    `${BANK_ACCOUNTS_COLLECTION}/${input.bankAccountId}`,
    {
      balance: toFirestoreNumber(bankBalance + total),
    },
    ["balance"],
  );

  await createFirestoreDoc(
    input.accessToken,
    input.projectId,
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
      bankAccountId: toFirestoreString(input.bankAccountId),
      status: toFirestoreString("COMPLETED"),
      invoiceId: toFirestoreString(invoiceId),
      source: toFirestoreString("INVOICE"),
      createdAt: toFirestoreTimestamp(now),
    },
  );

  return "settled";
}
