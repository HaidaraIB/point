/**
 * Presigned PUT for Cloudflare R2. Auth: Firebase ID token (same project as the app).
 */
import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import * as jose from "jose";

export interface Env {
  R2_ACCOUNT_ID: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_BUCKET: string;
  R2_PUBLIC_BASE_URL: string;
  /**
   * Comma-separated Firebase / GCP project IDs allowed for ID tokens (`aud`).
   * Include `.firebaserc` `default` and `legacy` if you use both (debug vs prod).
   * Example: `point-agency-production,point-f33cb`
   */
  FIREBASE_PROJECT_IDS: string;
}

const JWKS = jose.createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
    "Access-Control-Max-Age": "86400",
  };
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

function logSignFailure(error: string, httpStatus: number): Response {
  console.log(
    JSON.stringify({
      event: "sign_upload_fail",
      error,
      httpStatus,
      at: new Date().toISOString(),
    }),
  );
  return json({ ok: false, error }, httpStatus);
}

function sanitizeFilename(name: string): string {
  const t = name.trim().slice(0, 200);
  if (!t) return "download";
  return t.replace(/[\r\n"<>]+/g, "_");
}

/** ASCII-only fallback for legacy `filename=` in Content-Disposition. */
function asciiFallbackFilename(name: string): string {
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

/** RFC 5987 `filename*` value (UTF-8, percent-encoded, ASCII-safe for XHR headers). */
function rfc5987EncodeFilename(name: string): string {
  return encodeURIComponent(name).replace(
    /[!'()*]/g,
    (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

/**
 * Content-Disposition safe for browser XHR (ISO-8859-1 header values) while
 * preserving Unicode download names via `filename*=UTF-8''…`.
 */
function buildContentDisposition(friendly: string): string {
  const sanitized = sanitizeFilename(friendly);
  const ascii = asciiFallbackFilename(sanitized);
  if (/^[\x20-\x7E]*$/.test(sanitized)) {
    return `attachment; filename="${ascii}"`;
  }
  const encoded = rfc5987EncodeFilename(sanitized);
  return `attachment; filename="${ascii}"; filename*=UTF-8''${encoded}`;
}

/** Normalize to ".ext" (max 16 chars total). */
function normalizeExt(raw: unknown): string {
  let e = typeof raw === "string" ? raw.trim() : ".bin";
  if (!e.startsWith(".")) e = `.${e}`;
  if (e.length > 16) e = e.slice(0, 16);
  if (!/^\.[a-zA-Z0-9._-]+$/.test(e)) return ".bin";
  return e;
}

function resolveFirebaseProjectIds(env: Env): string[] {
  const raw = env.FIREBASE_PROJECT_IDS?.trim() ?? "";
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

async function verifyFirebaseIdToken(
  token: string,
  projectIds: string[],
): Promise<void> {
  const issuers = projectIds.map(
    (id) => `https://securetoken.google.com/${id}`,
  );
  await jose.jwtVerify(token, JWKS, {
    issuer: issuers.length === 1 ? issuers[0] : issuers,
    audience: projectIds.length === 1 ? projectIds[0] : projectIds,
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    const url = new URL(request.url);
    if (!url.pathname.endsWith("/sign-upload")) {
      return logSignFailure("not_found", 404);
    }

    if (request.method !== "POST") {
      return logSignFailure("method_not_allowed", 405);
    }

    const auth = request.headers.get("Authorization") ?? "";
    if (!auth.startsWith("Bearer ")) {
      return logSignFailure("missing_bearer", 401);
    }
    const token = auth.slice(7).trim();
    if (!token) {
      return logSignFailure("empty_token", 401);
    }

    const projectIds = resolveFirebaseProjectIds(env);
    if (projectIds.length === 0) {
      return logSignFailure("server_misconfigured", 500);
    }

    try {
      await verifyFirebaseIdToken(token, projectIds);
    } catch {
      return logSignFailure("invalid_token", 401);
    }

    let body: {
      contentType?: string;
      ext?: string;
      friendlyDownloadName?: string;
    };
    try {
      body = (await request.json()) as typeof body;
    } catch {
      return logSignFailure("invalid_json", 400);
    }

    const contentType =
      typeof body.contentType === "string" && body.contentType.trim().length > 0
        ? body.contentType.trim().slice(0, 200)
        : "application/octet-stream";

    const ext = normalizeExt(body.ext);
    const friendly =
      typeof body.friendlyDownloadName === "string"
        ? body.friendlyDownloadName.trim()
        : "";

    const accountId = env.R2_ACCOUNT_ID?.trim();
    const accessKey = env.R2_ACCESS_KEY_ID?.trim();
    const secretKey = env.R2_SECRET_ACCESS_KEY?.trim();
    const bucket = env.R2_BUCKET?.trim();
    const publicBase = env.R2_PUBLIC_BASE_URL?.trim().replace(/\/+$/, "");

    if (!accountId || !accessKey || !secretKey || !bucket || !publicBase) {
      return logSignFailure("r2_misconfigured", 500);
    }

    // R2 S3-compatible keys: Access Key ID is 32 hex chars; Secret is 64 hex chars.
    // Swapping them or pasting the secret into R2_ACCESS_KEY_ID yields HTTP 400 from R2:
    // "Credential access key has length 64, should be 32"
    if (accessKey.length !== 32 || secretKey.length !== 64) {
      console.log(
        JSON.stringify({
          event: "sign_upload_fail",
          error: "r2_keys_wrong_shape",
          httpStatus: 500,
          at: new Date().toISOString(),
        }),
      );
      return json(
        {
          ok: false,
          error: "r2_keys_wrong_shape",
          hint:
            "R2_ACCESS_KEY_ID must be 32 characters and R2_SECRET_ACCESS_KEY must be 64. They are often swapped when setting Worker secrets.",
        },
        500,
      );
    }

    const key = `${crypto.randomUUID()}${ext}`;

    const client = new S3Client({
      region: "auto",
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: accessKey,
        secretAccessKey: secretKey,
      },
    });

    const put = new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      ContentType: contentType,
      ...(friendly.length > 0
        ? {
            ContentDisposition: buildContentDisposition(friendly),
          }
        : {}),
    });

    const expiresIn = 15 * 60;
    const uploadUrl = await getSignedUrl(client, put, { expiresIn });

    const signedHeaders: Record<string, string> = {
      "Content-Type": contentType,
    };
    if (friendly.length > 0) {
      signedHeaders["Content-Disposition"] = buildContentDisposition(friendly);
    }

    const publicUrl = `${publicBase}/${key}`;

    return json({
      ok: true,
      uploadUrl,
      headers: signedHeaders,
      publicUrl,
      key,
    });
  },
};
