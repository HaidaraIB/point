/**
 * Point app URLs for hosted card payment return (static HTML page).
 * Supabase Edge Functions cannot render HTML on GET; the app serves the page.
 */

export const RELEASE_APP_BASE = "https://agency.point-iq.app";

const ALLOWED_RETURN_HOSTS = new Set([
  "localhost",
  "127.0.0.1",
  "agency.point-iq.app",
]);

function isAllowedReturnHost(hostname: string): boolean {
  const host = hostname.trim().toLowerCase();
  if (ALLOWED_RETURN_HOSTS.has(host)) return true;
  if (host.endsWith(".point-iq.app")) return true;
  return false;
}

/** Validates client-supplied base (e.g. http://localhost:8080 from Flutter web). */
export function normalizeReturnBaseUrl(input?: string): string | undefined {
  const raw = (input ?? "").trim();
  if (!raw) return undefined;

  try {
    const url = new URL(raw);
    if (url.protocol !== "http:" && url.protocol !== "https:") return undefined;
    if (!isAllowedReturnHost(url.hostname)) return undefined;
    return `${url.protocol}//${url.host}`;
  } catch {
    return undefined;
  }
}

/** Adds stable pay.html context (p, t) for "choose another method" on the result page. */
export function appendPayLinkContext(
  params: URLSearchParams,
  firebaseProjectId: string,
  payLinkToken?: string,
): void {
  const projectId = firebaseProjectId.trim();
  const token = (payLinkToken ?? "").trim();
  if (projectId) {
    if (!params.has("firebaseProjectId")) {
      params.set("firebaseProjectId", projectId);
    }
    params.set("p", projectId);
  }
  if (token) params.set("t", token);
}

export function buildPayHtmlUrl(
  firebaseProjectId: string,
  payLinkToken: string,
  returnBaseUrl?: string,
): string {
  const fromClient = normalizeReturnBaseUrl(returnBaseUrl);
  const base = fromClient || RELEASE_APP_BASE;
  const params = new URLSearchParams();
  appendPayLinkContext(params, firebaseProjectId, payLinkToken);
  return `${base}/pay.html?${params.toString()}`;
}

export function buildPaymentResultUrl(
  options: {
    provider: string;
    firebaseProjectId?: string;
    payLinkToken?: string;
    returnBaseUrl?: string;
    query?: Record<string, string>;
  },
): string {
  const fromClient = normalizeReturnBaseUrl(options.returnBaseUrl);
  const base = fromClient || RELEASE_APP_BASE;
  const params = new URLSearchParams();
  params.set("provider", options.provider.trim().toLowerCase());
  if (options.firebaseProjectId) {
    appendPayLinkContext(params, options.firebaseProjectId, options.payLinkToken);
  }
  if (options.query) {
    for (const [key, value] of Object.entries(options.query)) {
      const v = value.trim();
      if (v) params.set(key, v);
    }
  }
  return `${base}/payment-result.html?${params.toString()}`;
}

export function getAppCardPaymentReturnUrl(
  firebaseProjectId?: string,
  returnBaseUrl?: string,
  payLinkToken?: string,
): string {
  return buildPaymentResultUrl({
    provider: "alqaseh",
    firebaseProjectId,
    payLinkToken,
    returnBaseUrl,
  });
}

export function buildQicardFinishPaymentUrl(
  firebaseProjectId: string,
  requestId: string,
  payLinkToken: string,
  returnBaseUrl?: string,
): string {
  return buildPaymentResultUrl({
    provider: "qicard",
    firebaseProjectId,
    payLinkToken,
    returnBaseUrl,
    query: { ref: requestId.trim() },
  });
}

export function buildPaytabsAppReturnRedirect(
  appBase: string | undefined,
  firebaseProjectId: string,
  fields: Record<string, string>,
  payLinkToken?: string,
): string {
  const params: Record<string, string> = {};
  const tranRef = (fields.tranRef ?? fields.tran_ref ?? "").trim();
  if (tranRef) params.ref = tranRef;
  const cartId = (fields.cartId ?? fields.cart_id ?? "").trim();
  if (cartId) params.order_id = cartId;
  return buildPaymentResultUrl({
    provider: "paytabs",
    firebaseProjectId,
    payLinkToken,
    returnBaseUrl: appBase,
    query: params,
  });
}
