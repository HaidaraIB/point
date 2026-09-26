/**
 * Stable invoice payment landing links (pay.html).
 */

import {
  getServiceAccountForFirebaseProject,
  listAllowedFirebaseProjectIds,
} from "./firebase-edge.ts";
import {
  firestoreString,
  getAccessToken,
  getFirestoreDoc,
  queryFirestoreCollection,
  setFirestoreDoc,
  toFirestoreString,
} from "./firestore-rest.ts";
import { INVOICES_COLLECTION } from "./card-settlement.ts";
import { buildPayHtmlUrl, RELEASE_APP_BASE } from "./card-return-url.ts";

export { RELEASE_APP_BASE, buildPayHtmlUrl };

const PAY_LINK_SHORT_LEN = 10;
const PAY_LINK_MIN_LEN = 8;
const PAY_LINK_ALPHABET =
  "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

export function generatePayLinkToken(): string {
  const bytes = new Uint8Array(PAY_LINK_SHORT_LEN);
  crypto.getRandomValues(bytes);
  let out = "";
  for (let i = 0; i < PAY_LINK_SHORT_LEN; i++) {
    out += PAY_LINK_ALPHABET[bytes[i] % PAY_LINK_ALPHABET.length];
  }
  return out;
}

function isShortPayLinkToken(token: string): boolean {
  const t = token.trim();
  return t.length >= PAY_LINK_MIN_LEN && t.length <= PAY_LINK_SHORT_LEN;
}

async function queryInvoiceByTokenField(
  accessToken: string,
  projectId: string,
  field: string,
  token: string,
): Promise<PayLinkInvoiceContext | null> {
  const matches = await queryFirestoreCollection(
    accessToken,
    projectId,
    INVOICES_COLLECTION,
    field,
    "EQUAL",
    token,
    1,
  );
  if (matches.length === 0) return null;
  return { invoiceId: matches[0].id, fields: matches[0].fields };
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
  if (existing.length > PAY_LINK_SHORT_LEN) {
    const short = generatePayLinkToken();
    await setFirestoreDoc(
      accessToken,
      projectId,
      path,
      {
        payLinkToken: toFirestoreString(short),
        legacyPayLinkToken: toFirestoreString(existing),
      },
      ["payLinkToken", "legacyPayLinkToken"],
    );
    return short;
  }
  if (isShortPayLinkToken(existing)) return existing;

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

export type PayLinkResolvedInvoice = PayLinkInvoiceContext & {
  projectId: string;
};

export async function resolveInvoiceByPayLinkToken(
  accessToken: string,
  projectId: string,
  token: string,
): Promise<PayLinkInvoiceContext | null> {
  const trimmed = token.trim();
  if (trimmed.length < PAY_LINK_MIN_LEN) return null;

  const byCurrent = await queryInvoiceByTokenField(
    accessToken,
    projectId,
    "payLinkToken",
    trimmed,
  );
  if (byCurrent) return byCurrent;

  return await queryInvoiceByTokenField(
    accessToken,
    projectId,
    "legacyPayLinkToken",
    trimmed,
  );
}

export async function resolveInvoiceByPayLinkTokenAcrossProjects(
  token: string,
): Promise<PayLinkResolvedInvoice | null> {
  const trimmed = token.trim();
  if (trimmed.length < PAY_LINK_MIN_LEN) return null;

  for (const projectId of listAllowedFirebaseProjectIds()) {
    try {
      getServiceAccountForFirebaseProject(projectId);
      const accessToken = await getAccessToken(
        getServiceAccountForFirebaseProject(projectId),
      );
      const resolved = await resolveInvoiceByPayLinkToken(
        accessToken,
        projectId,
        trimmed,
      );
      if (resolved) {
        return { projectId, invoiceId: resolved.invoiceId, fields: resolved.fields };
      }
    } catch {
      /* try next project */
    }
  }
  return null;
}
