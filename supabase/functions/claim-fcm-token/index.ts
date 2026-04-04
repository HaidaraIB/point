import "https://deno.land/std@0.177.0/http/server.ts";
import type { ServiceAccountJson } from "../_shared/firebase-edge.ts";
import {
  getServiceAccountForFirebaseProject,
  verifyFirebaseIdToken,
} from "../_shared/firebase-edge.ts";

/**
 * يزيل توكن FCM من كل مستندات employees/clients ثم يسجّله للمستهدف الحالي فقط.
 * يتطلب Firebase ID Token + مطابقة authRoles/{uid} مع employeeId أو clientId في الطلب.
 * يستخدم حساب الخدمة (مثل send-fcm) لأن قواعد Firestore لا تسمح للموظف بتعديل مستندات الآخرين.
 */

const GOOGLE_SCOPE = "https://www.googleapis.com/auth/cloud-platform";
const TOKEN_URL = "https://oauth2.googleapis.com/token";

async function getAccessToken(sa: ServiceAccountJson): Promise<string> {
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 55 * 60;
  const claim = base64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: GOOGLE_SCOPE,
      aud: TOKEN_URL,
      iat,
      exp,
    }),
  );
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

async function runQuery(
  accessToken: string,
  projectId: string,
  structuredQuery: unknown,
): Promise<Array<{ name: string; fields: Record<string, unknown> }>> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ structuredQuery }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Firestore runQuery error: ${JSON.stringify(data)}`);
  const out: Array<{ name: string; fields: Record<string, unknown> }> = [];
  for (const row of data as Array<Record<string, unknown>>) {
    const doc = row?.document as { name?: string; fields?: Record<string, unknown> } | undefined;
    if (doc?.name && doc?.fields) {
      out.push({ name: doc.name, fields: doc.fields });
    }
  }
  return out;
}

function parseFcmArray(fields: Record<string, unknown>): string[] {
  const vals = (fields.fcmTokens as { arrayValue?: { values?: unknown[] } })?.arrayValue?.values;
  if (!Array.isArray(vals)) return [];
  return vals
    .map((v) => (v as { stringValue?: string })?.stringValue ?? "")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

function parseFcmScalar(fields: Record<string, unknown>): string {
  const s = (fields.fcmToken as { stringValue?: string })?.stringValue;
  return typeof s === "string" ? s.trim() : "";
}

function docPathToCollectionAndId(name: string): { collection: string; id: string } | null {
  const m = name.match(/\/documents\/(employees|clients)\/([^/]+)$/);
  if (!m) return null;
  return { collection: m[1], id: decodeURIComponent(m[2]) };
}

/** يطابق FirestoreServices._removeEmployeeFcmToken / _stripFcmTokenFromUserDoc */
function buildFieldsAfterRemovingToken(
  fields: Record<string, unknown>,
  token: string,
): { fcmToken: { nullValue: null } | { stringValue: string }; fcmTokens: { arrayValue: { values: { stringValue: string }[] } } } {
  const arr = parseFcmArray(fields);
  const single = parseFcmScalar(fields);
  const newArr = arr.filter((t) => t !== token);
  const nextSingle = single === token ? null : single;
  const values = newArr.map((t) => ({ stringValue: t }));
  return {
    fcmToken: nextSingle && nextSingle.length > 0 ? { stringValue: nextSingle } : { nullValue: null },
    fcmTokens: { arrayValue: { values } },
  };
}

/** يطابق addEmployeeFcmToken / addClientFcmToken */
function buildFieldsAfterAssigningToken(
  fields: Record<string, unknown>,
  token: string,
): { fcmToken: { stringValue: string }; fcmTokens: { arrayValue: { values: { stringValue: string }[] } } } {
  const arr = parseFcmArray(fields);
  const single = parseFcmScalar(fields);
  const set = new Set<string>(arr);
  if (single) set.add(single);
  set.add(token);
  const values = [...set].map((t) => ({ stringValue: t }));
  return {
    fcmToken: { stringValue: token },
    fcmTokens: { arrayValue: { values } },
  };
}

async function patchDocFields(
  accessToken: string,
  projectId: string,
  collection: string,
  docId: string,
  patchFields: Record<string, unknown>,
): Promise<void> {
  const enc = encodeURIComponent(docId);
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${enc}?updateMask.fieldPaths=fcmToken&updateMask.fieldPaths=fcmTokens`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields: patchFields }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`PATCH ${collection}/${docId} failed: ${res.status} ${t}`);
  }
}

async function getDoc(
  accessToken: string,
  projectId: string,
  collection: string,
  docId: string,
): Promise<Record<string, unknown> | null> {
  const enc = encodeURIComponent(docId);
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${enc}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (res.status === 404) return null;
  if (!res.ok) return null;
  const j = await res.json() as { fields?: Record<string, unknown> };
  return j.fields ?? {};
}

async function collectDocNamesWithToken(
  accessToken: string,
  projectId: string,
  collection: "employees" | "clients",
  token: string,
): Promise<Set<string>> {
  const names = new Set<string>();
  const q1 = {
    from: [{ collectionId: collection }],
    where: {
      fieldFilter: {
        field: { fieldPath: "fcmToken" },
        op: "EQUAL",
        value: { stringValue: token },
      },
    },
    limit: 500,
  };
  const q2 = {
    from: [{ collectionId: collection }],
    where: {
      fieldFilter: {
        field: { fieldPath: "fcmTokens" },
        op: "ARRAY_CONTAINS",
        value: { stringValue: token },
      },
    },
    limit: 500,
  };
  for (const d of await runQuery(accessToken, projectId, q1)) {
    names.add(d.name);
  }
  for (const d of await runQuery(accessToken, projectId, q2)) {
    names.add(d.name);
  }
  return names;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200, headers: corsHeaders() });
  if (req.method !== "POST") return json({ errorCode: "ERR_METHOD_NOT_ALLOWED" }, 405);

  try {
    const firebaseAuthz = req.headers.get("x-firebase-id-token") ?? "";
    const idToken = firebaseAuthz.toLowerCase().startsWith("bearer ")
      ? firebaseAuthz.slice(7).trim()
      : firebaseAuthz.trim();
    if (!idToken) return json({ errorCode: "ERR_MISSING_TOKEN" }, 401);

    const caller = await verifyFirebaseIdToken(idToken);
    const sa = getServiceAccountForFirebaseProject(caller.firebaseProjectId);
    const accessToken = await getAccessToken(sa);
    const projectId = sa.project_id;

    const body = await req.json().catch(() => ({})) as {
      fcmToken?: string;
      employeeId?: string;
      clientId?: string;
    };
    const fcmToken = (body.fcmToken ?? "").trim();
    const employeeId = (body.employeeId ?? "").trim();
    const clientId = (body.clientId ?? "").trim();

    if (!fcmToken) return json({ errorCode: "ERR_INVALID_DATA", details: "missing fcmToken" }, 400);
    if ((employeeId && clientId) || (!employeeId && !clientId)) {
      return json({ errorCode: "ERR_INVALID_DATA", details: "send exactly one of employeeId or clientId" }, 400);
    }

    const roleUrl =
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/authRoles/${encodeURIComponent(caller.uid)}`;
    const roleRes = await fetch(roleUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
    if (!roleRes.ok) {
      return json({ errorCode: "ERR_FORBIDDEN", details: "authRoles not found" }, 403);
    }
    const roleDoc = await roleRes.json() as { fields?: Record<string, unknown> };
    const rf = roleDoc.fields ?? {};
    const role = (rf.role as { stringValue?: string })?.stringValue?.trim() ?? "";
    const authEmployeeId = (rf.employeeId as { stringValue?: string })?.stringValue?.trim() ?? "";
    const authClientId = (rf.clientId as { stringValue?: string })?.stringValue?.trim() ?? "";

    if (employeeId) {
      if (role === "client") {
        return json({ errorCode: "ERR_FORBIDDEN", details: "client cannot claim employee token" }, 403);
      }
      if (authEmployeeId !== employeeId) {
        return json({ errorCode: "ERR_FORBIDDEN", details: "employeeId does not match authRoles" }, 403);
      }
    } else {
      if (role !== "client" || authClientId !== clientId) {
        return json({ errorCode: "ERR_FORBIDDEN", details: "clientId does not match authRoles" }, 403);
      }
    }

    const empHits = await collectDocNamesWithToken(accessToken, projectId, "employees", fcmToken);
    const cliHits = await collectDocNamesWithToken(accessToken, projectId, "clients", fcmToken);
    const uniqueNames = [...new Set([...empHits, ...cliHits])];

    let stripped = 0;
    for (const name of uniqueNames) {
      const parsed = docPathToCollectionAndId(name);
      if (!parsed) continue;
      const fields = await getDoc(accessToken, projectId, parsed.collection, parsed.id);
      if (!fields) continue;
      const patch = buildFieldsAfterRemovingToken(fields, fcmToken);
      await patchDocFields(accessToken, projectId, parsed.collection, parsed.id, patch);
      stripped++;
    }

    const targetCollection = employeeId ? "employees" : "clients";
    const targetId = employeeId || clientId;
    const targetFields = await getDoc(accessToken, projectId, targetCollection, targetId);
    if (targetFields === null) {
      return json({ errorCode: "ERR_INVALID_DATA", details: "target document missing" }, 400);
    }
    const assignPatch = buildFieldsAfterAssigningToken(targetFields, fcmToken);
    await patchDocFields(accessToken, projectId, targetCollection, targetId, assignPatch);

    return json({ ok: true, strippedCount: stripped }, 200);
  } catch (e) {
    return json({ errorCode: "ERR_SERVER", details: String(e) }, 500);
  }
});
