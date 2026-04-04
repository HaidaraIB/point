/**
 * مشترك بين دوال Edge التي تتصل بـ Firebase:
 * - اختيار حساب الخدمة حسب project_id (أسرار prod / test).
 * - التحقق من Firebase ID Token واستخراج aud.
 * - مسار الكرون لـ scheduled-notifications (body.firebaseProjectId + قائمة بيضاء).
 */

export type ServiceAccountJson = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const FIREBASE_ID_TOKEN_CERTS_URL =
  "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

/**
 * Prod: `FIREBASE_SERVICE_ACCOUNT_JSON` (required).
 * Test: `FIREBASE_SERVICE_ACCOUNT_JSON_TEST` — نفس الشكل (project_id، client_email، private_key).
 * يُختار الحساب حسب `aud` في رمز Firebase بعد التحقق من التوقيع (التطبيق على test → test SA، على prod → prod SA).
 */
export function getServiceAccountForFirebaseProject(
  firebaseProjectId: string,
): ServiceAccountJson {
  const prodRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!prodRaw) throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON not set");
  const prod = JSON.parse(prodRaw) as ServiceAccountJson;
  if (!prod?.project_id || !prod?.client_email || !prod?.private_key) {
    throw new Error("Invalid FIREBASE_SERVICE_ACCOUNT_JSON");
  }
  if (prod.project_id === firebaseProjectId) return prod;

  const testRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON_TEST");
  if (testRaw) {
    const test = JSON.parse(testRaw) as ServiceAccountJson;
    if (!test?.project_id || !test?.client_email || !test?.private_key) {
      throw new Error("Invalid FIREBASE_SERVICE_ACCOUNT_JSON_TEST");
    }
    if (test.project_id === firebaseProjectId) return test;
  }

  throw new Error(
    `No service account for Firebase project "${firebaseProjectId}". ` +
      "Add Supabase secret FIREBASE_SERVICE_ACCOUNT_JSON_TEST for the test Firebase project, or use the prod app build.",
  );
}

/** معرفات المشاريع المعرّفة في الأسرار (للتحقق من body الكرون). */
export function listAllowedFirebaseProjectIds(): string[] {
  const ids: string[] = [];
  const prodRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (prodRaw) {
    try {
      const p = JSON.parse(prodRaw) as ServiceAccountJson;
      if (p?.project_id) ids.push(p.project_id);
    } catch {
      /* ignore */
    }
  }
  const testRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON_TEST");
  if (testRaw) {
    try {
      const t = JSON.parse(testRaw) as ServiceAccountJson;
      if (t?.project_id && !ids.includes(t.project_id)) ids.push(t.project_id);
    } catch {
      /* ignore */
    }
  }
  return ids;
}

function getDefaultCronFirebaseProjectId(): string {
  const prodRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!prodRaw) throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON not set");
  const prod = JSON.parse(prodRaw) as ServiceAccountJson;
  if (!prod?.project_id) throw new Error("Invalid FIREBASE_SERVICE_ACCOUNT_JSON");
  return prod.project_id;
}

/**
 * كرون scheduled-notifications: يقرأ `firebaseProjectId` من body؛ إن وُجد يجب أن يكون ضمن المشاريع المُعرّفة في الأسرار.
 * إن لم يُرسل الحقل يُستخدم مشروع الإنتاج الافتراضي (project_id من FIREBASE_SERVICE_ACCOUNT_JSON).
 */
export function resolveServiceAccountForScheduledCron(
  firebaseProjectId: string | undefined,
): ServiceAccountJson {
  const allowed = listAllowedFirebaseProjectIds();
  if (allowed.length === 0) {
    throw new Error("No Firebase service accounts configured");
  }
  const requested = (firebaseProjectId ?? "").trim();
  const id = requested.length > 0 ? requested : getDefaultCronFirebaseProjectId();
  if (!allowed.includes(id)) {
    throw new Error(
      `firebaseProjectId "${id}" is not allowed. Configured projects: ${allowed.join(", ")}`,
    );
  }
  return getServiceAccountForFirebaseProject(id);
}

export async function verifyFirebaseIdToken(
  idToken: string,
): Promise<{ uid: string; email?: string; firebaseProjectId: string }> {
  const parts = idToken.split(".");
  if (parts.length !== 3) throw new Error("Invalid ID token");
  const header = decodeJwtPart(parts[0]);
  const payload = decodeJwtPart(parts[1]);
  const kid = String(header["kid"] ?? "");
  if (!kid) throw new Error("Missing kid");

  const certsRes = await fetch(FIREBASE_ID_TOKEN_CERTS_URL);
  const certs = await certsRes.json() as Record<string, string>;
  const certPem = certs[kid];
  if (!certPem) throw new Error("Unknown kid");

  const dataToVerify = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const sigBytes = base64urlToBytes(parts[2]);
  const key = await importX509(certPem);
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, sigBytes, dataToVerify);
  if (!ok) throw new Error("Invalid signature");

  const now = Math.floor(Date.now() / 1000);
  const rawAud = payload["aud"];
  const aud = typeof rawAud === "string" ? rawAud.trim() : "";
  const iss = String(payload["iss"] ?? "");
  const sub = String(payload["sub"] ?? "");
  const exp = Number(payload["exp"] ?? 0);
  if (!sub) throw new Error("Missing sub");
  if (!aud) throw new Error("Invalid aud");
  if (iss !== `https://securetoken.google.com/${aud}`) throw new Error("Invalid iss");
  if (!exp || now >= exp) throw new Error("Token expired");

  const email = typeof payload["email"] === "string" ? payload["email"] : undefined;
  return { uid: sub, email, firebaseProjectId: aud };
}

function decodeJwtPart(input: string): Record<string, unknown> {
  const pad = "=".repeat((4 - (input.length % 4)) % 4);
  const b64 = (input + pad).replace(/-/g, "+").replace(/_/g, "/");
  const jsonStr = new TextDecoder().decode(Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)));
  return JSON.parse(jsonStr) as Record<string, unknown>;
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
  const certDer = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const spkiDer = extractSubjectPublicKeyInfoDer(certDer);
  return await crypto.subtle.importKey(
    "spki",
    spkiDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
}

function extractSubjectPublicKeyInfoDer(certDer: Uint8Array): Uint8Array {
  const readLength = (der: Uint8Array, offset: number) => {
    const first = der[offset];
    if (first < 0x80) return { len: first, lenBytes: 1 };
    const numBytes = first & 0x7f;
    let len = 0;
    for (let i = 0; i < numBytes; i++) {
      len = (len << 8) | der[offset + 1 + i];
    }
    return { len, lenBytes: 1 + numBytes };
  };

  const readElement = (der: Uint8Array, offset: number) => {
    const tag = der[offset];
    const { len, lenBytes } = readLength(der, offset + 1);
    const headerBytes = 1 + lenBytes;
    const start = offset;
    const end = offset + headerBytes + len;
    return { tag, start, end };
  };

  const certSeq = readElement(certDer, 0);
  if (certSeq.tag !== 0x30) {
    throw new Error("Invalid certificate DER (expected SEQUENCE)");
  }

  const { lenBytes: outerLenBytes } = readLength(certDer, 1);
  const outerContentStart = 1 + outerLenBytes;

  const tbs = readElement(certDer, outerContentStart);
  if (tbs.tag !== 0x30) throw new Error("Invalid certificate DER (expected tbsCertificate SEQUENCE)");

  const { lenBytes: tbsLenBytes } = readLength(certDer, tbs.start + 1);
  const tbsHeaderBytes = 1 + tbsLenBytes;
  let tbsOff = tbs.start + tbsHeaderBytes;

  const firstEl = readElement(certDer, tbsOff);
  if (firstEl.tag === 0xa0) {
    tbsOff = firstEl.end;
  }

  // Skip 5 elements to reach subjectPublicKeyInfo:
  // 1. serialNumber, 2. signature, 3. issuer, 4. validity, 5. subject
  tbsOff = readElement(certDer, tbsOff).end;
  tbsOff = readElement(certDer, tbsOff).end;
  tbsOff = readElement(certDer, tbsOff).end;
  tbsOff = readElement(certDer, tbsOff).end;
  tbsOff = readElement(certDer, tbsOff).end;

  const spki = readElement(certDer, tbsOff);
  if (spki.tag !== 0x30) throw new Error("Invalid certificate DER (expected subjectPublicKeyInfo SEQUENCE)");

  return certDer.slice(spki.start, spki.end);
}
