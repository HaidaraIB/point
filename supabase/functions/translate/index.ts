import "https://deno.land/std@0.177.0/http/server.ts";
import {
  createFirestoreDoc,
  getFirestoreDoc,
  parseFirestoreFields,
  setFirestoreDoc,
  toFirestoreString,
} from "../_shared/firestore-rest.ts";
import type { ServiceAccountJson } from "../_shared/firebase-edge.ts";
import {
  getServiceAccountForFirebaseProject,
  verifyFirebaseIdToken,
} from "../_shared/firebase-edge.ts";

const GEMINI_MODEL = "gemini-2.5-flash-lite";
const GEMINI_TIMEOUT_MS = 8000;
const MAX_UNCACHED_PER_USER_PER_DAY = 80;
const OS_SETTINGS_DOC = "os_settings/default";

type TranslateBody = {
  action?: string;
  text?: string;
  title?: string;
  description?: string;
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

async function sha256Hex(text: string): Promise<string> {
  const data = new TextEncoder().encode(text.trim());
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function getGeminiApiKeyFromEnv(): string | null {
  const key = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();
  return key.length > 0 ? key : null;
}

async function loadGeminiApiKeyFromFirestore(
  accessToken: string,
  projectId: string,
): Promise<string | null> {
  const fields = await getFirestoreDoc(accessToken, projectId, OS_SETTINGS_DOC);
  if (!fields) return null;
  const key = firestoreString(fields, "geminiApiKey");
  return key.length > 0 ? key : null;
}

async function resolveGeminiApiKey(
  accessToken: string,
  projectId: string,
): Promise<string | null> {
  const fromFirestore = await loadGeminiApiKeyFromFirestore(accessToken, projectId);
  if (fromFirestore) return fromFirestore;
  return getGeminiApiKeyFromEnv();
}

function shouldSkipTranslation(text: string): boolean {
  const t = text.trim();
  if (!t) return true;
  if (/^\s*(https?:\/\/|www\.)[^\s]+\s*$/i.test(t)) return true;
  if (/^[\s\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{200D}\u{20E3}]+$/u.test(t)) {
    return true;
  }
  return false;
}

async function callGeminiJson(
  prompt: string,
  accessToken: string,
  projectId: string,
): Promise<Record<string, string>> {
  const apiKey = await resolveGeminiApiKey(accessToken, projectId);
  if (!apiKey) throw new Error("No API key");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);

  try {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${encodeURIComponent(apiKey)}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0,
          maxOutputTokens: 1024,
          responseMimeType: "application/json",
        },
      }),
      signal: controller.signal,
    });

    const data = await res.json();
    if (!res.ok) {
      const msg = JSON.stringify(data);
      if (res.status === 429 || msg.includes("RESOURCE_EXHAUSTED")) {
        const e = new Error(`429 ${msg}`);
        (e as Error & { status?: number }).status = 429;
        throw e;
      }
      throw new Error(`Gemini error ${res.status}: ${msg}`);
    }

    const parts = data?.candidates?.[0]?.content?.parts;
    const text = Array.isArray(parts)
      ? parts.map((p: { text?: string }) => p?.text ?? "").join("").trim()
      : "";
    if (!text) throw new Error("Empty Gemini response");

    const parsed = JSON.parse(text) as Record<string, unknown>;
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(parsed)) {
      if (typeof v === "string" && v.trim()) out[k] = v.trim();
    }
    return out;
  } finally {
    clearTimeout(timer);
  }
}

function toFirestoreMap(values: Record<string, string>) {
  const fields: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(values)) {
    fields[k] = toFirestoreString(v);
  }
  return { mapValue: { fields } };
}

async function readCache(
  accessToken: string,
  projectId: string,
  hash: string,
): Promise<Record<string, string> | null> {
  const fields = await getFirestoreDoc(
    accessToken,
    projectId,
    `translation_cache/${hash}`,
  );
  if (!fields) return null;
  const raw = fields.translations as
    | { mapValue?: { fields?: Record<string, unknown> } }
    | undefined;
  const mapFields = raw?.mapValue?.fields;
  if (!mapFields) return null;
  const parsed = parseFirestoreFields(mapFields) as Record<string, unknown>;
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(parsed)) {
    if (typeof v === "string" && v.trim()) out[k] = v.trim();
  }
  return Object.keys(out).length > 0 ? out : null;
}

async function writeCache(
  accessToken: string,
  projectId: string,
  hash: string,
  translations: Record<string, string>,
  scope: string,
): Promise<void> {
  const now = new Date().toISOString();
  await createFirestoreDoc(
    accessToken,
    projectId,
    "translation_cache",
    hash,
    {
      translations: toFirestoreMap(translations),
      scope: toFirestoreString(scope),
      createdAt: toFirestoreString(now),
    },
  ).catch(async () => {
    await setFirestoreDoc(
      accessToken,
      projectId,
      `translation_cache/${hash}`,
      {
        translations: toFirestoreMap(translations),
        scope: toFirestoreString(scope),
        updatedAt: toFirestoreString(now),
      },
      ["translations", "scope", "updatedAt"],
    );
  });
}

function utcDayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

async function assertUserRateLimit(
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<void> {
  const day = utcDayKey();
  const docId = `${uid}_${day}`;
  const fields = await getFirestoreDoc(
    accessToken,
    projectId,
    `translation_usage/${docId}`,
  );
  const count = fields
    ? Number(
      (fields.uncachedCalls as { integerValue?: string } | undefined)
        ?.integerValue ?? "0",
    )
    : 0;
  if (count >= MAX_UNCACHED_PER_USER_PER_DAY) {
    throw new Error("ERR_RATE_LIMITED");
  }
  const next = count + 1;
  const payload = {
    uncachedCalls: { integerValue: String(next) },
    day: toFirestoreString(day),
    uid: toFirestoreString(uid),
    updatedAt: toFirestoreString(new Date().toISOString()),
  };
  if (!fields) {
    await createFirestoreDoc(
      accessToken,
      projectId,
      "translation_usage",
      docId,
      payload,
    );
  } else {
    await setFirestoreDoc(
      accessToken,
      projectId,
      `translation_usage/${docId}`,
      payload,
      ["uncachedCalls", "day", "uid", "updatedAt"],
    );
  }
}

async function assertSignedInUser(
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<void> {
  const authFields = await getFirestoreDoc(accessToken, projectId, `authRoles/${uid}`);
  if (!authFields) throw new Error("Forbidden");
  const role = firestoreString(authFields, "role").toLowerCase();
  if (!role) throw new Error("Forbidden");
}

function detectLikelyLang(text: string): "ar" | "en" {
  const arCount = (text.match(/[\u0600-\u06FF]/g) ?? []).length;
  const latinCount = (text.match(/[A-Za-z]/g) ?? []).length;
  return arCount >= latinCount ? "ar" : "en";
}

async function handleTranslateChat(
  body: TranslateBody,
  accessToken: string,
  projectId: string,
  uid: string,
) {
  const text = (body.text ?? "").trim();
  if (shouldSkipTranslation(text)) {
    return json({ errorCode: "ERR_EMPTY_TEXT" }, 400);
  }

  const sourceHash = await sha256Hex(text);
  const cached = await readCache(accessToken, projectId, sourceHash);
  if (cached?.ar && cached?.en && cached?.fa) {
    return json({
      success: true,
      translations: cached,
      sourceHash,
      source: "cache",
    });
  }

  await assertUserRateLimit(accessToken, projectId, uid);

  const prompt =
    `Translate the following message into Arabic (ar), English (en), and Farsi/Persian (fa). ` +
    `Return ONLY valid JSON with keys ar, en, fa and string values. No markdown.\n\n${text}`;
  const translations = await callGeminiJson(prompt, accessToken, projectId);
  if (!translations.ar || !translations.en || !translations.fa) {
    return json({ errorCode: "ERR_INVALID_RESPONSE" }, 502);
  }

  await writeCache(accessToken, projectId, sourceHash, translations, "chat");

  return json({
    success: true,
    translations,
    sourceHash,
    source: "gemini",
  });
}

async function translateTaskField(
  text: string,
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<{ translations: Record<string, string>; sourceHash: string; source: string }> {
  const sourceHash = await sha256Hex(text);
  const cached = await readCache(accessToken, projectId, sourceHash);
  const sourceLang = detectLikelyLang(text);
  const targetLang = sourceLang === "ar" ? "en" : "ar";

  if (cached?.[targetLang]) {
    return {
      translations: { [targetLang]: cached[targetLang] },
      sourceHash,
      source: "cache",
    };
  }

  await assertUserRateLimit(accessToken, projectId, uid);

  const langName = targetLang === "ar" ? "Arabic" : "English";
  const prompt =
    `Translate the following text into ${langName} only. ` +
    `Return ONLY valid JSON with a single key "${targetLang}" and the translation as its value. No markdown.\n\n${text}`;
  const result = await callGeminiJson(prompt, accessToken, projectId);
  const translated = result[targetLang]?.trim();
  if (!translated) {
    throw new Error("ERR_INVALID_RESPONSE");
  }

  const toCache = { ...cached, [targetLang]: translated };
  await writeCache(accessToken, projectId, sourceHash, toCache, "task");

  return {
    translations: { [targetLang]: translated },
    sourceHash,
    source: "gemini",
  };
}

async function handleTranslateTask(
  body: TranslateBody,
  accessToken: string,
  projectId: string,
  uid: string,
) {
  const title = (body.title ?? "").trim();
  const description = (body.description ?? "").trim();
  if (!title && !description) {
    return json({ errorCode: "ERR_EMPTY_TEXT" }, 400);
  }

  let titleTranslations: Record<string, string> = {};
  let descriptionTranslations: Record<string, string> = {};
  let titleSourceHash = "";
  let descriptionSourceHash = "";

  if (title && !shouldSkipTranslation(title)) {
    const r = await translateTaskField(title, accessToken, projectId, uid);
    titleTranslations = r.translations;
    titleSourceHash = r.sourceHash;
  }
  if (description && !shouldSkipTranslation(description)) {
    const r = await translateTaskField(
      description,
      accessToken,
      projectId,
      uid,
    );
    descriptionTranslations = r.translations;
    descriptionSourceHash = r.sourceHash;
  }

  return json({
    success: true,
    titleTranslations,
    descriptionTranslations,
    titleSourceHash,
    descriptionSourceHash,
    source: "gemini",
  });
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

    await assertSignedInUser(saAccessToken, caller.firebaseProjectId, caller.uid);

    const body = await req.json().catch(() => ({})) as TranslateBody;
    const action = (body.action ?? "").trim();

    if (action === "translate-chat") {
      return await handleTranslateChat(
        body,
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
      );
    }
    if (action === "translate-task") {
      return await handleTranslateTask(
        body,
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
      );
    }

    return json({ errorCode: "ERR_INVALID_ACTION" }, 400);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg === "Forbidden") {
      return json({ errorCode: "ERR_FORBIDDEN" }, 403);
    }
    if (msg === "ERR_RATE_LIMITED") {
      return json({ errorCode: "ERR_RATE_LIMITED" }, 429);
    }
    console.error("translate error:", msg);
    return json({ errorCode: "ERR_INTERNAL" }, 500);
  }
});
