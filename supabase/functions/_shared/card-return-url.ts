/**
 * Point app URLs for hosted card payment return (static HTML page).
 * Supabase Edge Functions cannot render HTML on GET; the app serves the page.
 */

const RELEASE_APP_BASE = "https://agency.point-iq.app";

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

export function getAppCardPaymentReturnUrl(
  firebaseProjectId?: string,
  returnBaseUrl?: string,
): string {
  const projectId = (firebaseProjectId ?? "").trim();
  const fromClient = normalizeReturnBaseUrl(returnBaseUrl);
  const base = fromClient || RELEASE_APP_BASE;

  const params = new URLSearchParams();
  params.set("provider", "alqaseh");
  if (projectId) params.set("firebaseProjectId", projectId);
  return `${base}/payment-result.html?${params.toString()}`;
}

export function buildPaytabsAppReturnRedirect(
  appBase: string | undefined,
  firebaseProjectId: string,
  fields: Record<string, string>,
): string {
  const base = normalizeReturnBaseUrl(appBase) || RELEASE_APP_BASE;
  const params = new URLSearchParams();
  params.set("provider", "paytabs");
  if (firebaseProjectId.trim()) {
    params.set("firebaseProjectId", firebaseProjectId.trim());
  }
  const tranRef = (fields.tranRef ?? fields.tran_ref ?? "").trim();
  if (tranRef) params.set("ref", tranRef);
  const cartId = (fields.cartId ?? fields.cart_id ?? "").trim();
  if (cartId) params.set("order_id", cartId);
  return `${base}/payment-result.html?${params.toString()}`;
}
