/**
 * Retry Firestore operations on transient / quota errors.
 */

const RETRYABLE_CODES = new Set([4, 8, 10, 14]); // DEADLINE, RESOURCE_EXHAUSTED, ABORTED, UNAVAILABLE

/**
 * @param {unknown} error
 */
export function isRetryableFirestoreError(error) {
  const code = /** @type {{ code?: number }} */ (error)?.code;
  if (typeof code === "number" && RETRYABLE_CODES.has(code)) return true;
  const message = error instanceof Error ? error.message : String(error);
  return /RESOURCE_EXHAUSTED|Quota exceeded|UNAVAILABLE|DEADLINE_EXCEEDED|429|503/i.test(
    message,
  );
}

/**
 * @param {unknown} error
 */
export function formatFirestoreQuotaHelp(error) {
  const code = /** @type {{ code?: number }} */ (error)?.code;
  if (code !== 8 && !String(error).includes("Quota exceeded")) return "";
  return `
Firestore quota exceeded (RESOURCE_EXHAUSTED). This is a Firebase limit, not Supabase.

What to try:
  1. Wait and retry later (daily read quotas reset; rate limits are per-minute).
  2. Run one collection at a time: --collection tasks (then contents, employees, …).
  3. Use smaller pages and delays: --page-size 10 --delay-ms 1000
  4. Resume a partial scan: --resume (progress saved under .migration-cache/)
  5. If on Spark/free tier with heavy app usage, upgrade to Blaze or run scan off-peak.

The script saves progress before exit so you can continue without re-reading completed pages.
`.trim();
}

/**
 * @template T
 * @param {() => Promise<T>} fn
 * @param {{ label?: string, maxAttempts?: number, baseDelayMs?: number }} [opts]
 */
export async function retryFirestore(fn, opts = {}) {
  const maxAttempts = opts.maxAttempts ?? 8;
  const baseDelayMs = opts.baseDelayMs ?? 2000;
  const label = opts.label ?? "Firestore operation";

  let lastError;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (!isRetryableFirestoreError(error) || attempt === maxAttempts) {
        throw error;
      }
      const delayMs = baseDelayMs * 2 ** (attempt - 1);
      console.warn(
        `${label}: attempt ${attempt}/${maxAttempts} failed (${error instanceof Error ? error.message : error}). Retrying in ${delayMs}ms…`,
      );
      await sleep(delayMs);
    }
  }
  throw lastError;
}

/**
 * @param {number} ms
 */
export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
