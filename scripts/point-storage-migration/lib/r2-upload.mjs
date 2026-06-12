import { randomUUID } from "node:crypto";

import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";

import {
  appendFailureLog,
  extractDownloadQuery,
  extractSupabaseObjectKey,
  normalizeSupabaseUrl,
} from "./migration-url-map.mjs";

/** Normalize to ".ext" (max 16 chars total). Mirrors workers/r2-presign/src/index.ts */
export function normalizeExt(raw) {
  let e = typeof raw === "string" ? raw.trim() : ".bin";
  if (!e.startsWith(".")) e = `.${e}`;
  if (e.length > 16) e = e.slice(0, 16);
  if (!/^\.[a-zA-Z0-9._-]+$/.test(e)) return ".bin";
  return e;
}

function sanitizeFilename(name) {
  const t = name.trim().slice(0, 200);
  if (!t) return "download";
  return t.replace(/[\r\n"<>]+/g, "_");
}

function asciiFallbackFilename(name) {
  const sanitized = sanitizeFilename(name);
  let ascii = sanitized.replace(/[^\x20-\x7E]+/g, "_").replace(/_+/g, "_");
  ascii = ascii.replace(/^\.+/, "").replace(/^_|_$/g, "");
  if (ascii.length > 0) return ascii.slice(0, 200);
  const dot = sanitized.lastIndexOf(".");
  if (dot > 0 && dot < sanitized.length - 1) {
    const ext = sanitized
      .slice(dot)
      .replace(/[^\x2E0-9A-Za-z_-]+/g, "")
      .slice(0, 16);
    return ext ? `download${ext}` : "download";
  }
  return "download";
}

function rfc5987EncodeFilename(name) {
  return encodeURIComponent(name).replace(
    /[!'()*]/g,
    (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

export function buildContentDisposition(friendly) {
  const sanitized = sanitizeFilename(friendly);
  const ascii = asciiFallbackFilename(sanitized);
  if (/^[\x20-\x7E]*$/.test(sanitized)) {
    return `attachment; filename="${ascii}"`;
  }
  const encoded = rfc5987EncodeFilename(sanitized);
  return `attachment; filename="${ascii}"; filename*=UTF-8''${encoded}`;
}

const MIME_TO_EXT = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/gif": ".gif",
  "image/webp": ".webp",
  "video/mp4": ".mp4",
  "video/quicktime": ".mov",
  "application/pdf": ".pdf",
  "audio/mpeg": ".mp3",
  "audio/mp4": ".m4a",
  "audio/ogg": ".ogg",
  "audio/webm": ".webm",
};

/**
 * @param {string} objectKey
 */
export function extFromObjectKey(objectKey) {
  const base = objectKey.split("/").pop() ?? objectKey;
  const dot = base.lastIndexOf(".");
  if (dot <= 0 || dot >= base.length - 1) return ".bin";
  return normalizeExt(base.slice(dot));
}

/**
 * @param {string} contentType
 */
export function extFromContentType(contentType) {
  const ct = contentType.split(";")[0]?.trim().toLowerCase() ?? "";
  return normalizeExt(MIME_TO_EXT[ct] ?? ".bin");
}

/**
 * @param {object} env
 */
export function createR2Client(env) {
  const accountId = env.R2_ACCOUNT_ID?.trim();
  const accessKey = env.R2_ACCESS_KEY_ID?.trim();
  const secretKey = env.R2_SECRET_ACCESS_KEY?.trim();
  if (!accountId || !accessKey || !secretKey) {
    throw new Error("Missing R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, or R2_SECRET_ACCESS_KEY");
  }
  return new S3Client({
    region: "auto",
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: accessKey,
      secretAccessKey: secretKey,
    },
  });
}

/**
 * @param {object} env
 */
export function readR2Env() {
  const bucket = process.env.R2_BUCKET?.trim();
  const publicBase = process.env.R2_PUBLIC_BASE_URL?.trim().replace(/\/+$/, "");
  if (!bucket || !publicBase) {
    throw new Error("Missing R2_BUCKET or R2_PUBLIC_BASE_URL");
  }
  return {
    R2_ACCOUNT_ID: process.env.R2_ACCOUNT_ID,
    R2_ACCESS_KEY_ID: process.env.R2_ACCESS_KEY_ID,
    R2_SECRET_ACCESS_KEY: process.env.R2_SECRET_ACCESS_KEY,
    R2_BUCKET: bucket,
    R2_PUBLIC_BASE_URL: publicBase,
  };
}

/**
 * Download from Supabase public URL and upload to R2.
 * @param {string} originalUrl
 * @param {{ projectId: string, forceRecopy?: boolean, urlConfig?: object }} opts
 * @param {S3Client} s3
 * @param {ReturnType<readR2Env>} r2Env
 */
export async function copySupabaseUrlToR2(originalUrl, opts, s3, r2Env) {
  const normalized = normalizeSupabaseUrl(originalUrl);
  const downloadUrl = normalized;
  const friendly = extractDownloadQuery(originalUrl);
  const objectKey = extractSupabaseObjectKey(originalUrl, opts.urlConfig);

  const response = await fetch(downloadUrl, { redirect: "follow" });
  if (!response.ok) {
    throw new Error(`Supabase GET failed: HTTP ${response.status} for ${normalized}`);
  }

  const bytes = Buffer.from(await response.arrayBuffer());
  const contentType =
    response.headers.get("content-type")?.split(";")[0]?.trim() ||
    "application/octet-stream";

  let ext = objectKey ? extFromObjectKey(objectKey) : ".bin";
  if (ext === ".bin") {
    ext = extFromContentType(contentType);
  }

  const key = `${randomUUID()}${ext}`;
  /** @type {Record<string, string>} */
  const putParams = {
    Bucket: r2Env.R2_BUCKET,
    Key: key,
    Body: bytes,
    ContentType: contentType,
  };
  if (friendly) {
    putParams.ContentDisposition = buildContentDisposition(friendly);
  }

  await s3.send(new PutObjectCommand(putParams));

  const newUrl = `${r2Env.R2_PUBLIC_BASE_URL}/${key}`;
  return {
    newUrl,
    r2Key: key,
    bytes: bytes.length,
    contentType,
    copiedAt: new Date().toISOString(),
    objectKey: objectKey ?? undefined,
    normalizedUrl: normalized,
  };
}

/**
 * @param {string} projectId
 * @param {string} originalUrl
 * @param {object} opts
 */
export async function copyWithFailureLog(projectId, originalUrl, opts) {
  try {
    const r2Env = readR2Env();
    const s3 = createR2Client(r2Env);
    return await copySupabaseUrlToR2(originalUrl, opts, s3, r2Env);
  } catch (error) {
    appendFailureLog(projectId, {
      url: originalUrl,
      normalizedUrl: normalizeSupabaseUrl(originalUrl),
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}
