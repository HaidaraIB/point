/**
 * Stable invoice payment landing links (pay.html).
 */

import {
  firestoreString,
  getFirestoreDoc,
  queryFirestoreCollection,
  setFirestoreDoc,
  toFirestoreString,
} from "./firestore-rest.ts";
import { INVOICES_COLLECTION } from "./card-settlement.ts";
import { buildPayHtmlUrl, RELEASE_APP_BASE } from "./card-return-url.ts";

export { RELEASE_APP_BASE, buildPayHtmlUrl };

export function generatePayLinkToken(): string {
  const a = crypto.randomUUID().replace(/-/g, "");
  const b = crypto.randomUUID().replace(/-/g, "");
  return `${a}${b}`.slice(0, 64);
}

export async function ensureInvoicePayLinkToken(
  accessToken: string,
  projectId: string,
  invoiceId: string,
): Promise<string> {
  const path = `${INVOICES_COLLECTION}/${invoiceId}`;
  const fields = await getFirestoreDoc(accessToken, projectId, path);
  if (!fields) throw new Error("ERR_INVOICE_NOT_FOUND");

  const existing = firestoreString(fields, "payLinkToken");
  if (existing.length >= 32) return existing;

  const token = generatePayLinkToken();
  await setFirestoreDoc(
    accessToken,
    projectId,
    path,
    { payLinkToken: toFirestoreString(token) },
    ["payLinkToken"],
  );
  return token;
}

export type PayLinkInvoiceContext = {
  invoiceId: string;
  fields: Record<string, unknown>;
};

export async function resolveInvoiceByPayLinkToken(
  accessToken: string,
  projectId: string,
  token: string,
): Promise<PayLinkInvoiceContext | null> {
  const trimmed = token.trim();
  if (trimmed.length < 16) return null;

  const matches = await queryFirestoreCollection(
    accessToken,
    projectId,
    INVOICES_COLLECTION,
    "payLinkToken",
    "EQUAL",
    trimmed,
    1,
  );
  if (matches.length === 0) return null;
  return { invoiceId: matches[0].id, fields: matches[0].fields };
}
