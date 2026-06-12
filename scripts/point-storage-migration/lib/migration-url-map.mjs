import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CACHE_ROOT = path.join(__dirname, "..", ".migration-cache");

/** @typedef {{ newUrl: string, r2Key: string, bytes: number, contentType: string, copiedAt: string, objectKey?: string }} UrlMapEntry */

/**
 * @param {{ supabaseBucket?: string, supabaseStorageBaseUrl?: string }} config
 */
export function buildSupabaseObjectPathRe(config = {}) {
  const bucket = (config.supabaseBucket ?? process.env.SUPABASE_BUCKET ?? "point")
    .trim()
    .replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(
    `/storage/v1/object/(?:public/)?${bucket}/([^?#]+)`,
    "i",
  );
}

/**
 * @param {string} url
 * @param {{ supabaseBucket?: string, supabaseStorageBaseUrl?: string }} [config]
 */
export function isSupabaseStorageUrl(url, config = {}) {
  if (typeof url !== "string" || !url.trim()) return false;
  const trimmed = url.trim();
  const objectRe = buildSupabaseObjectPathRe(config);
  if (!objectRe.test(trimmed)) return false;

  const customBase = (
    config.supabaseStorageBaseUrl ??
    process.env.SUPABASE_STORAGE_BASE_URL ??
    ""
  ).trim();
  if (customBase) {
    try {
      const baseHost = new URL(customBase).host;
      const urlHost = new URL(trimmed).host;
      if (baseHost && urlHost !== baseHost) {
        return trimmed.includes(".supabase.co");
      }
    } catch {
      // ignore invalid custom base
    }
  }

  return trimmed.includes(".supabase.co") || Boolean(customBase);
}

/**
 * Normalize for dedup: origin + pathname (no query/hash).
 * @param {string} url
 */
export function normalizeSupabaseUrl(url) {
  const u = new URL(url.trim());
  return `${u.origin}${u.pathname}`;
}

/**
 * @param {string} url
 */
export function extractDownloadQuery(url) {
  try {
    const u = new URL(url.trim());
    return u.searchParams.get("download")?.trim() ?? "";
  } catch {
    return "";
  }
}

/**
 * @param {string} url
 * @param {{ supabaseBucket?: string }} [config]
 */
export function extractSupabaseObjectKey(url, config = {}) {
  const objectRe = buildSupabaseObjectPathRe(config);
  const m = url.trim().match(objectRe);
  return m?.[1] ? decodeURIComponent(m[1]) : null;
}

/**
 * @param {string} projectId
 */
export function getProjectCacheDir(projectId) {
  return path.join(CACHE_ROOT, projectId);
}

/**
 * @param {string} projectId
 */
export function getUrlMapPath(projectId) {
  return path.join(getProjectCacheDir(projectId), "url-map.json");
}

/**
 * @param {string} projectId
 * @returns {Record<string, UrlMapEntry>}
 */
export function loadUrlMap(projectId) {
  const mapPath = getUrlMapPath(projectId);
  if (!fs.existsSync(mapPath)) return {};
  try {
    return JSON.parse(fs.readFileSync(mapPath, "utf8"));
  } catch {
    return {};
  }
}

/**
 * @param {string} projectId
 * @param {Record<string, UrlMapEntry>} map
 */
export function saveUrlMap(projectId, map) {
  const dir = getProjectCacheDir(projectId);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(getUrlMapPath(projectId), `${JSON.stringify(map, null, 2)}\n`);
}

/**
 * @param {string} projectId
 */
export function getChangesLogPath(projectId) {
  return path.join(getProjectCacheDir(projectId), "changes.jsonl");
}

/**
 * @param {string} projectId
 * @param {object} entry
 */
export function appendChangeLog(projectId, entry) {
  const dir = getProjectCacheDir(projectId);
  fs.mkdirSync(dir, { recursive: true });
  fs.appendFileSync(
    getChangesLogPath(projectId),
    `${JSON.stringify({ ...entry, timestamp: new Date().toISOString() })}\n`,
  );
}

/**
 * @param {string} projectId
 * @param {object} entry
 */
export function appendFailureLog(projectId, entry) {
  const dir = getProjectCacheDir(projectId);
  fs.mkdirSync(dir, { recursive: true });
  const failPath = path.join(dir, "failures.jsonl");
  fs.appendFileSync(
    failPath,
    `${JSON.stringify({ ...entry, timestamp: new Date().toISOString() })}\n`,
  );
}

/**
 * @param {string} projectId
 * @param {object} entry
 */
export function appendPurgeLog(projectId, entry) {
  const dir = getProjectCacheDir(projectId);
  fs.mkdirSync(dir, { recursive: true });
  const purgePath = path.join(dir, "purge.jsonl");
  fs.appendFileSync(
    purgePath,
    `${JSON.stringify({ ...entry, timestamp: new Date().toISOString() })}\n`,
  );
}

/**
 * @param {string} projectId
 * @param {object} report
 */
export function writeScanReport(projectId, report) {
  const dir = getProjectCacheDir(projectId);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(
    path.join(dir, "scan-report.json"),
    `${JSON.stringify(report, null, 2)}\n`,
  );
}

/**
 * @param {string} projectId
 */
export function getScanProgressPath(projectId) {
  return path.join(getProjectCacheDir(projectId), "scan-progress.json");
}

/**
 * @param {string} projectId
 */
export function loadScanProgress(projectId) {
  const progressPath = getScanProgressPath(projectId);
  if (!fs.existsSync(progressPath)) {
    return { hits: [], byCollection: {}, completedSteps: [] };
  }
  try {
    const raw = JSON.parse(fs.readFileSync(progressPath, "utf8"));
    return {
      hits: Array.isArray(raw.hits) ? raw.hits : [],
      byCollection:
        raw.byCollection && typeof raw.byCollection === "object"
          ? raw.byCollection
          : {},
      completedSteps: Array.isArray(raw.completedSteps) ? raw.completedSteps : [],
    };
  } catch {
    return { hits: [], byCollection: {}, completedSteps: [] };
  }
}

/**
 * @param {string} projectId
 * @param {{ hits: unknown[], byCollection: Record<string, number>, completedSteps: string[] }} progress
 */
export function saveScanProgress(projectId, progress) {
  const dir = getProjectCacheDir(projectId);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(
    getScanProgressPath(projectId),
    `${JSON.stringify(progress, null, 2)}\n`,
  );
}

/**
 * @param {string} projectId
 */
export function clearScanProgress(projectId) {
  const progressPath = getScanProgressPath(projectId);
  if (fs.existsSync(progressPath)) {
    fs.unlinkSync(progressPath);
  }
}

/**
 * @param {Array<{ docPath: string, fieldPath: string, rawUrl: string, normalizedUrl: string }>} hits
 */
export function buildRawUrlByNormalized(hits) {
  /** @type {Record<string, string>} */
  const rawUrlByNormalized = {};
  for (const hit of hits) {
    if (!rawUrlByNormalized[hit.normalizedUrl]) {
      rawUrlByNormalized[hit.normalizedUrl] = hit.rawUrl;
    }
  }
  return rawUrlByNormalized;
}

/**
 * @param {Array<{ normalizedUrl: string }>} hits
 */
export function uniqueUrlsFromHits(hits) {
  return [...new Set(hits.map((h) => h.normalizedUrl))];
}
