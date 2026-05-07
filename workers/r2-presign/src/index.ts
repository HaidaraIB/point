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

function sanitizeFilename(name: string): string {
  const t = name.trim().slice(0, 200);
  if (!t) return "download";
  return t.replace(/[\r\n"<>]+/g, "_");
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
      return json({ ok: false, error: "not_found" }, 404);
    }

    if (request.method !== "POST") {
      return json({ ok: false, error: "method_not_allowed" }, 405);
    }

    const auth = request.headers.get("Authorization") ?? "";
    if (!auth.startsWith("Bearer ")) {
      return json({ ok: false, error: "missing_bearer" }, 401);
    }
    const token = auth.slice(7).trim();
    if (!token) {
      return json({ ok: false, error: "empty_token" }, 401);
    }

    const projectIds = resolveFirebaseProjectIds(env);
    if (projectIds.length === 0) {
      return json({ ok: false, error: "server_misconfigured" }, 500);
    }

    try {
      await verifyFirebaseIdToken(token, projectIds);
    } catch {
      return json({ ok: false, error: "invalid_token" }, 401);
    }

    let body: {
      contentType?: string;
      ext?: string;
      friendlyDownloadName?: string;
    };
    try {
      body = (await request.json()) as typeof body;
    } catch {
      return json({ ok: false, error: "invalid_json" }, 400);
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
      return json({ ok: false, error: "r2_misconfigured" }, 500);
    }

    // R2 S3-compatible keys: Access Key ID is 32 hex chars; Secret is 64 hex chars.
    // Swapping them or pasting the secret into R2_ACCESS_KEY_ID yields HTTP 400 from R2:
    // "Credential access key has length 64, should be 32"
    if (accessKey.length !== 32 || secretKey.length !== 64) {
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
            ContentDisposition: `attachment; filename="${sanitizeFilename(friendly)}"`,
          }
        : {}),
    });

    const expiresIn = 15 * 60;
    const uploadUrl = await getSignedUrl(client, put, { expiresIn });

    const signedHeaders: Record<string, string> = {
      "Content-Type": contentType,
    };
    if (friendly.length > 0) {
      signedHeaders["Content-Disposition"] =
        `attachment; filename="${sanitizeFilename(friendly)}"`;
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
