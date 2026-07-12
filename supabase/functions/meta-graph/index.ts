import "https://deno.land/std@0.177.0/http/server.ts";
import type { ServiceAccountJson } from "../_shared/firebase-edge.ts";
import {
  getServiceAccountForFirebaseProject,
  verifyFirebaseIdToken,
} from "../_shared/firebase-edge.ts";

const GRAPH_TIMEOUT_MS = 30_000;
const ALLOWED_GET_PATHS = new Set(["/me/accounts", "/me"]);

type GraphProxyBody = {
  graphVersion?: string;
  path?: string;
  query?: Record<string, string>;
  accessToken?: string;
};

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-firebase-id-token, x-supabase-client-platform, x-supabase-client-platform-version, x-region",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

async function getAccessToken(sa: ServiceAccountJson): Promise<string> {
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 55 * 60;
  const claim = base64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/cloud-platform",
      aud: "https://oauth2.googleapis.com/token",
      iat,
      exp,
    }),
  );
  const unsigned = `${header}.${claim}`;
  const signature = await signRs256(unsigned, sa.private_key);
  const jwt = `${unsigned}.${signature}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Token error: ${JSON.stringify(data)}`);
  return data.access_token as string;
}

async function signRs256(unsigned: string, privateKeyPem: string): Promise<string> {
  const pkcs8 = pemToArrayBuffer(privateKeyPem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pkcs8,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  return base64url(new Uint8Array(sig));
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return bytes.buffer;
}

function base64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function firestoreString(fields: Record<string, unknown>, key: string): string {
  const v = fields[key] as { stringValue?: string } | undefined;
  return typeof v?.stringValue === "string" ? v.stringValue.trim() : "";
}

async function getFirestoreDoc(
  accessToken: string,
  projectId: string,
  docPath: string,
): Promise<Record<string, unknown> | null> {
  const enc = docPath.split("/").map((p) => encodeURIComponent(p)).join("/");
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${enc}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Firestore GET ${docPath} failed: ${res.status} ${t}`);
  }
  const data = await res.json() as { fields?: Record<string, unknown> };
  return data.fields ?? null;
}

async function assertMetaGraphManager(
  saAccessToken: string,
  projectId: string,
  uid: string,
): Promise<void> {
  const authFields = await getFirestoreDoc(saAccessToken, projectId, `authRoles/${uid}`);
  if (!authFields) throw new Error("Forbidden");

  const authRole = firestoreString(authFields, "role").toLowerCase();
  if (authRole === "admin" || authRole === "supervisor") return;

  const employeeId = firestoreString(authFields, "employeeId");
  if (!employeeId) throw new Error("Forbidden");

  const employeeFields = await getFirestoreDoc(
    saAccessToken,
    projectId,
    `employees/${employeeId}`,
  );
  if (!employeeFields) throw new Error("Forbidden");

  const employeeRole = firestoreString(employeeFields, "role").toLowerCase();
  if (employeeRole !== "admin" && employeeRole !== "supervisor") {
    throw new Error("Forbidden");
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return json({ errorCode: "ERR_METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    const firebaseAuthz = req.headers.get("x-firebase-id-token") ?? "";
    const idToken = firebaseAuthz.toLowerCase().startsWith("bearer ")
      ? firebaseAuthz.slice(7).trim()
      : firebaseAuthz.trim();
    if (!idToken) return json({ errorCode: "ERR_MISSING_TOKEN" }, 401);

    const caller = await verifyFirebaseIdToken(idToken);
    const sa = getServiceAccountForFirebaseProject(caller.firebaseProjectId);
    const saAccessToken = await getAccessToken(sa);
    await assertMetaGraphManager(saAccessToken, caller.firebaseProjectId, caller.uid);

    const body = await req.json().catch(() => ({})) as GraphProxyBody;
    const graphVersion = (body.graphVersion ?? "v25.0").trim() || "v25.0";
    const path = (body.path ?? "").trim();
    const accessToken = (body.accessToken ?? "").trim();
    const query = body.query ?? {};

    if (!path.startsWith("/")) {
      return json({ errorCode: "ERR_INVALID_PATH" }, 400);
    }
    if (!ALLOWED_GET_PATHS.has(path)) {
      return json({ errorCode: "ERR_PATH_NOT_ALLOWED" }, 403);
    }
    if (!accessToken) {
      return json({ errorCode: "ERR_MISSING_META_TOKEN" }, 400);
    }

    const params = new URLSearchParams({ access_token: accessToken, ...query });
    const graphUrl =
      `https://graph.facebook.com/${graphVersion}${path}?${params.toString()}`;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), GRAPH_TIMEOUT_MS);
    let graphRes: Response;
    try {
      graphRes = await fetch(graphUrl, {
        method: "GET",
        signal: controller.signal,
      });
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") {
        return json({ errorCode: "ERR_GRAPH_TIMEOUT" }, 504);
      }
      throw e;
    } finally {
      clearTimeout(timer);
    }

    const raw = await graphRes.text();
    let graphBody: unknown;
    try {
      graphBody = raw ? JSON.parse(raw) : {};
    } catch {
      graphBody = { raw: raw.slice(0, 2000) };
    }

    return json(
      {
        ok: graphRes.ok,
        status: graphRes.status,
        body: graphBody,
      },
      // Always HTTP 200 so Supabase client returns data instead of throwing
      // FunctionException — Graph errors live in `body.error`.
      200,
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg === "Forbidden") {
      return json({ errorCode: "ERR_FORBIDDEN" }, 403);
    }
    console.error("meta-graph error:", msg);
    return json({ errorCode: "ERR_INTERNAL", message: msg }, 500);
  }
});
