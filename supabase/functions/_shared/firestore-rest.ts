/**
 * Minimal Firestore REST helpers for Edge Functions (service-account access).
 */

export function firestoreString(
  fields: Record<string, unknown>,
  key: string,
): string {
  const v = fields[key] as { stringValue?: string } | undefined;
  return typeof v?.stringValue === "string" ? v.stringValue.trim() : "";
}

export function firestoreNumber(
  fields: Record<string, unknown>,
  key: string,
): number {
  const v = fields[key] as
    | { doubleValue?: number; integerValue?: string }
    | undefined;
  if (v?.doubleValue != null) return Number(v.doubleValue);
  if (v?.integerValue != null) return Number(v.integerValue);
  return 0;
}

export function firestoreBool(
  fields: Record<string, unknown>,
  key: string,
): boolean {
  const v = fields[key] as { booleanValue?: boolean } | undefined;
  return v?.booleanValue === true;
}

export function toFirestoreString(value: string): { stringValue: string } {
  return { stringValue: value };
}

export function toFirestoreNumber(value: number): { doubleValue: number } {
  return { doubleValue: value };
}

export function toFirestoreBool(value: boolean): { booleanValue: boolean } {
  return { booleanValue: value };
}

export function toFirestoreTimestamp(date: Date): { timestampValue: string } {
  return { timestampValue: date.toISOString() };
}

export function parseFirestoreFields(
  fields: Record<string, unknown>,
): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, raw] of Object.entries(fields)) {
    out[key] = parseFirestoreValue(raw);
  }
  return out;
}

function parseFirestoreValue(raw: unknown): unknown {
  if (!raw || typeof raw !== "object") return null;
  const v = raw as Record<string, unknown>;
  if ("stringValue" in v) return v.stringValue ?? "";
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("nullValue" in v) return null;
  if ("timestampValue" in v) return v.timestampValue;
  if ("mapValue" in v) {
    const map = v.mapValue as { fields?: Record<string, unknown> };
    return parseFirestoreFields(map.fields ?? {});
  }
  if ("arrayValue" in v) {
    const arr = v.arrayValue as { values?: unknown[] };
    return (arr.values ?? []).map((item) => parseFirestoreValue(item));
  }
  return null;
}

function docPathToUrl(projectId: string, docPath: string): string {
  const enc = docPath.split("/").map((p) => encodeURIComponent(p)).join("/");
  return `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${enc}`;
}

export async function getFirestoreDoc(
  accessToken: string,
  projectId: string,
  docPath: string,
): Promise<Record<string, unknown> | null> {
  const res = await fetch(docPathToUrl(projectId, docPath), {
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

export async function setFirestoreDoc(
  accessToken: string,
  projectId: string,
  docPath: string,
  fields: Record<string, unknown>,
  updateMask: string[],
): Promise<void> {
  const mask = updateMask
    .map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`)
    .join("&");
  const url = `${docPathToUrl(projectId, docPath)}?${mask}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Firestore PATCH ${docPath} failed: ${res.status} ${t}`);
  }
}

export async function createFirestoreDoc(
  accessToken: string,
  projectId: string,
  collectionPath: string,
  documentId: string,
  fields: Record<string, unknown>,
): Promise<"created" | "exists"> {
  const enc = collectionPath.split("/").map((p) => encodeURIComponent(p)).join("/");
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${enc}?documentId=${encodeURIComponent(documentId)}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields }),
  });
  if (res.status === 409) return "exists";
  if (!res.ok) {
    const t = await res.text();
    throw new Error(
      `Firestore CREATE ${collectionPath}/${documentId} failed: ${res.status} ${t}`,
    );
  }
  return "created";
}

export async function queryFirestoreCollection(
  accessToken: string,
  projectId: string,
  collectionId: string,
  field: string,
  op: "EQUAL",
  value: string,
  limit = 1,
): Promise<Array<{ id: string; fields: Record<string, unknown> }>> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId }],
        where: {
          fieldFilter: {
            field: { fieldPath: field },
            op,
            value: { stringValue: value },
          },
        },
        limit,
      },
    }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Firestore query ${collectionId} failed: ${res.status} ${t}`);
  }
  const rows = await res.json() as Array<{
    document?: { name?: string; fields?: Record<string, unknown> };
  }>;
  const out: Array<{ id: string; fields: Record<string, unknown> }> = [];
  for (const row of rows) {
    const name = row.document?.name ?? "";
    const parts = name.split("/");
    const id = parts[parts.length - 1] ?? "";
    if (!id || !row.document?.fields) continue;
    out.push({ id, fields: row.document.fields });
  }
  return out;
}

export async function listFirestoreCollection(
  accessToken: string,
  projectId: string,
  collectionId: string,
  limit = 500,
): Promise<Array<{ id: string; fields: Record<string, unknown> }>> {
  const enc = encodeURIComponent(collectionId);
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${enc}?pageSize=${limit}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Firestore list ${collectionId} failed: ${res.status} ${t}`);
  }
  const data = await res.json() as {
    documents?: Array<{ name?: string; fields?: Record<string, unknown> }>;
  };
  const out: Array<{ id: string; fields: Record<string, unknown> }> = [];
  for (const doc of data.documents ?? []) {
    const name = doc.name ?? "";
    const parts = name.split("/");
    const id = parts[parts.length - 1] ?? "";
    if (!id || !doc.fields) continue;
    out.push({ id, fields: doc.fields });
  }
  return out;
}

export async function getAccessToken(sa: {
  client_email: string;
  private_key: string;
}): Promise<string> {
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
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
