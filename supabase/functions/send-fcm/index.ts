import "https://deno.land/std@0.177.0/http/server.ts";

type ServiceAccountJson = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const FIREBASE_ID_TOKEN_CERTS_URL =
  "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200, headers: corsHeaders() });
  if (req.method !== "POST") return json({ errorCode: "ERR_METHOD_NOT_ALLOWED" }, 405);

  try {
    // Web-safe auth: require a Firebase Auth ID token (no shared secret in client builds).
    const sa = getServiceAccount();
    const authz = req.headers.get("authorization") ?? "";
    const idToken = authz.toLowerCase().startsWith("bearer ") ? authz.slice(7).trim() : "";
    if (!idToken) return json({ errorCode: "ERR_MISSING_TOKEN" }, 401);
    const caller = await verifyFirebaseIdToken(idToken, sa.project_id);

    // Authorization: only allow admin/supervisor (matched by uid doc id OR by email field).
    const accessToken = await getAccessToken(sa);
    const role = await getEmployeeRole({
      accessToken,
      projectId: sa.project_id,
      uid: caller.uid,
      email: caller.email,
    });
    if (role !== "admin" && role !== "supervisor") {
      return json({ errorCode: "ERR_FORBIDDEN" }, 403);
    }

    const { token, topic, title, body, data } = await req.json().catch(() => ({})) as {
      token?: string;
      topic?: string;
      title?: string;
      body?: string;
      data?: Record<string, string>;
    };

    if (!title || !body) return json({ errorCode: "ERR_INVALID_DATA" }, 400);
    if ((!token && !topic) || (token && topic)) {
      return json({ errorCode: "ERR_INVALID_DATA" }, 400);
    }

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    const res = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          ...(token ? { token } : {}),
          ...(topic ? { topic } : {}),
          notification: { title, body },
          ...(data ? { data } : {}),
        },
      }),
    });

    const out = await res.json().catch(() => ({}));
    if (!res.ok) return json({ errorCode: "ERR_SERVER", details: out }, 500);
    return json({ ok: true, result: out }, 200);
  } catch (e) {
    return json({ errorCode: "ERR_SERVER", details: String(e) }, 500);
  }
});

function getServiceAccount(): ServiceAccountJson {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON not set");
  const sa = JSON.parse(raw) as ServiceAccountJson;
  if (!sa?.project_id || !sa?.client_email || !sa?.private_key) {
    throw new Error("Invalid FIREBASE_SERVICE_ACCOUNT_JSON");
  }
  return sa;
}

async function getAccessToken(sa: ServiceAccountJson): Promise<string> {
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 55 * 60;
  const claim = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: TOKEN_URL,
    iat,
    exp,
  }));
  const unsigned = `${header}.${claim}`;
  const signature = await signRs256(unsigned, sa.private_key);
  const jwt = `${unsigned}.${signature}`;

  const res = await fetch(TOKEN_URL, {
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
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
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

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

function decodeJwtPart(input: string): Record<string, unknown> {
  const pad = "=".repeat((4 - (input.length % 4)) % 4);
  const b64 = (input + pad).replace(/-/g, "+").replace(/_/g, "/");
  const jsonStr = new TextDecoder().decode(Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)));
  return JSON.parse(jsonStr) as Record<string, unknown>;
}

async function verifyFirebaseIdToken(idToken: string, projectId: string): Promise<{ uid: string; email?: string }> {
  const parts = idToken.split(".");
  if (parts.length !== 3) throw new Error("Invalid ID token");
  const header = decodeJwtPart(parts[0]);
  const payload = decodeJwtPart(parts[1]);
  const kid = String(header["kid"] ?? "");
  if (!kid) throw new Error("Missing kid");

  const now = Math.floor(Date.now() / 1000);
  const aud = String(payload["aud"] ?? "");
  const iss = String(payload["iss"] ?? "");
  const sub = String(payload["sub"] ?? "");
  const exp = Number(payload["exp"] ?? 0);
  if (!sub) throw new Error("Missing sub");
  if (aud !== projectId) throw new Error("Invalid aud");
  if (iss !== `https://securetoken.google.com/${projectId}`) throw new Error("Invalid iss");
  if (!exp || now >= exp) throw new Error("Token expired");

  const certsRes = await fetch(FIREBASE_ID_TOKEN_CERTS_URL);
  const certs = await certsRes.json() as Record<string, string>;
  const certPem = certs[kid];
  if (!certPem) throw new Error("Unknown kid");

  const dataToVerify = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const sigBytes = base64urlToBytes(parts[2]);
  const key = await importX509(certPem);
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, sigBytes, dataToVerify);
  if (!ok) throw new Error("Invalid signature");

  const email = typeof payload["email"] === "string" ? payload["email"] : undefined;
  return { uid: sub, email };
}

function base64urlToBytes(input: string): Uint8Array {
  const pad = "=".repeat((4 - (input.length % 4)) % 4);
  const b64 = (input + pad).replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

async function importX509(pem: string): Promise<CryptoKey> {
  const b64 = pem
    .replace(/-----BEGIN CERTIFICATE-----/g, "")
    .replace(/-----END CERTIFICATE-----/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)).buffer;
  return await crypto.subtle.importKey(
    "spki",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
}

async function getEmployeeRole(args: {
  accessToken: string;
  projectId: string;
  uid: string;
  email?: string;
}): Promise<string | null> {
  // 1) Try doc id == uid
  {
    const url =
      `https://firestore.googleapis.com/v1/projects/${args.projectId}/databases/(default)/documents/employees/${encodeURIComponent(args.uid)}`;
    const res = await fetch(url, { headers: { Authorization: `Bearer ${args.accessToken}` } });
    if (res.ok) {
      const doc = await res.json() as any;
      const role = doc?.fields?.role?.stringValue;
      if (typeof role === "string") return role;
    }
  }

  // 2) Fallback: query by email field
  if (!args.email) return null;
  const runQueryUrl =
    `https://firestore.googleapis.com/v1/projects/${args.projectId}/databases/(default)/documents:runQuery`;
  const structuredQuery = {
    from: [{ collectionId: "employees" }],
    where: {
      fieldFilter: {
        field: { fieldPath: "email" },
        op: "EQUAL",
        value: { stringValue: args.email },
      },
    },
    limit: 1,
  };
  const res = await fetch(runQueryUrl, {
    method: "POST",
    headers: { Authorization: `Bearer ${args.accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({ structuredQuery }),
  });
  const out = await res.json() as any[];
  const doc = out?.find((r) => r?.document)?.document;
  const role = doc?.fields?.role?.stringValue;
  return typeof role === "string" ? role : null;
}
