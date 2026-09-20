import "https://deno.land/std@0.177.0/http/server.ts";
import type { ServiceAccountJson } from "../_shared/firebase-edge.ts";
import {
  getServiceAccountForFirebaseProject,
  verifyFirebaseIdToken,
} from "../_shared/firebase-edge.ts";
import { assertOsAdmin, assertOsAccess } from "../_shared/os-admin.ts";

const GEMINI_TIMEOUT_MS = 4000;
const GEMINI_MODEL = "gemini-2.0-flash";
const COOLDOWN_MS = 180_000;
const SUMMARY_CACHE_TTL_MS = 600_000;

type OsAiBody = {
  action?: string;
  serviceName?: string;
  category?: string;
  data?: Record<string, unknown>;
  field?: string;
  context?: Record<string, unknown>;
  geminiApiKey?: string;
};

const OS_SETTINGS_DOC = "os_settings/default";

let geminiCooldownUntil = 0;
let cachedFinancialSummary: { key: string; text: string; timestamp: number } | null =
  null;
const cachedServiceDescriptions = new Map<string, string>();
const cachedContractFields = new Map<string, string>();

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

async function setFirestoreDoc(
  accessToken: string,
  projectId: string,
  docPath: string,
  fields: Record<string, unknown>,
  updateMask: string[],
): Promise<void> {
  const enc = docPath.split("/").map((p) => encodeURIComponent(p)).join("/");
  const mask = updateMask
    .map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`)
    .join("&");
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${enc}?${mask}`;
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

function callWithTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error("Timeout")), ms)
    ),
  ]);
}

function getGeminiApiKeyFromEnv(): string | null {
  const key = (Deno.env.get("GEMINI_API_KEY") ?? Deno.env.get("API_KEY"))?.trim();
  return key && key.length > 0 ? key : null;
}

function maskApiKey(key: string): string {
  if (key.length <= 8) return "••••••••";
  return `${key.slice(0, 4)}••••${key.slice(-4)}`;
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

function isRateLimitError(err: unknown): boolean {
  const errStr = String(err instanceof Error ? err.message : err);
  return (
    errStr.includes("429") ||
    errStr.includes("quota") ||
    errStr.includes("rate_limit") ||
    errStr.includes("RESOURCE_EXHAUSTED")
  );
}

async function callGemini(
  prompt: string,
  accessToken: string,
  projectId: string,
): Promise<string> {
  const apiKey = await resolveGeminiApiKey(accessToken, projectId);
  if (!apiKey) {
    throw new Error("No API key");
  }

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
          temperature: 0.7,
          maxOutputTokens: 512,
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
    if (!text) {
      throw new Error("Empty Gemini response");
    }
    return text;
  } finally {
    clearTimeout(timer);
  }
}

function defaultServiceDescription(serviceName: string): string {
  return `خدمة ${serviceName} من وكالة نقطة: حل إبداعي متكامل مصمم بأحدث تقنيات الإنتاج والتسويق لتعزيز حضور علامتكم التجارية وتحقيق تفاعل نوعي مع الجمهور المستهدف.`;
}

function defaultFinancialSummary(data: Record<string, unknown>): string {
  const rev = Number(data?.totalRevenue || 0).toLocaleString("en-US");
  const won = Number(data?.wonClients || 0);
  const total = Number(data?.clientCount || 0);
  const conv = total > 0 ? Math.round((won / total) * 100) : 0;
  const active = Number(data?.activeProjects || won);
  return `يُظهر الأداء المالي لوكالة نقطة استقراراً تشغيلياً بإجمالي إيرادات مسجلة ${rev} د.ع، ونسبة تحويل بلغت ${conv}% مع ${active} مشاريع نشطة. يُنصح بالتركيز على تحصيل المبالغ المستحقة للفواتير وإطلاق باقات تسويق مدمجة لتعظيم الربحية.`;
}

async function handleGetSettings(
  accessToken: string,
  projectId: string,
) {
  const fromFirestore = await loadGeminiApiKeyFromFirestore(accessToken, projectId);
  const fromEnv = getGeminiApiKeyFromEnv();
  const activeKey = fromFirestore ?? fromEnv;
  const source = fromFirestore ? "firestore" : (fromEnv ? "env" : "none");

  return json({
    success: true,
    hasGeminiKey: !!activeKey,
    keyPreview: activeKey ? maskApiKey(activeKey) : "",
    source,
    configuredInFirestore: !!fromFirestore,
    configuredInEnv: !!fromEnv,
  });
}

async function handleSaveSettings(
  body: OsAiBody,
  accessToken: string,
  projectId: string,
  uid: string,
) {
  const geminiApiKey = (body.geminiApiKey ?? "").trim();
  const now = new Date().toISOString();

  if (geminiApiKey.length === 0) {
    await setFirestoreDoc(
      accessToken,
      projectId,
      OS_SETTINGS_DOC,
      {
        geminiApiKey: { nullValue: null },
        updatedAt: { stringValue: now },
        updatedBy: { stringValue: uid },
      },
      ["geminiApiKey", "updatedAt", "updatedBy"],
    );
    const fromEnv = getGeminiApiKeyFromEnv();
    return json({
      success: true,
      hasGeminiKey: !!fromEnv,
      keyPreview: fromEnv ? maskApiKey(fromEnv) : "",
      source: fromEnv ? "env" : "none",
      configuredInFirestore: false,
      configuredInEnv: !!fromEnv,
    });
  }

  if (geminiApiKey.length < 20) {
    return json({ errorCode: "ERR_INVALID_API_KEY" }, 400);
  }

  await setFirestoreDoc(
    accessToken,
    projectId,
    OS_SETTINGS_DOC,
    {
      geminiApiKey: { stringValue: geminiApiKey },
      updatedAt: { stringValue: now },
      updatedBy: { stringValue: uid },
    },
    ["geminiApiKey", "updatedAt", "updatedBy"],
  );

  return json({
    success: true,
    hasGeminiKey: true,
    keyPreview: maskApiKey(geminiApiKey),
    source: "firestore",
    configuredInFirestore: true,
    configuredInEnv: !!getGeminiApiKeyFromEnv(),
  });
}

async function handleServiceDescription(
  body: OsAiBody,
  accessToken: string,
  projectId: string,
) {
  const serviceName = (body.serviceName ?? "").trim() || "خدمة إبداعية";
  const category = (body.category ?? "").trim() || "الإنتاج الإبداعي";
  const cacheKey = `${serviceName}_${category}`;
  const fallback = defaultServiceDescription(serviceName);

  if (cachedServiceDescriptions.has(cacheKey)) {
    return json({
      success: true,
      text: cachedServiceDescriptions.get(cacheKey),
      source: "cache",
    });
  }

  if (Date.now() < geminiCooldownUntil) {
    return json({ success: true, text: fallback, source: "smart_fallback" });
  }

  try {
    const prompt =
      `اكتب وصفاً تسويقياً جذاباً وموجزاً (سطرين إلى 3 أسطر) لخدمة إبداعية باسم "${serviceName}" ضمن تصنيف "${category}" تقدمها وكالة نقطة للإنتاج الفني والتسويق باللغة العربية.`;
    const resultText = await callWithTimeout(
      callGemini(prompt, accessToken, projectId),
      GEMINI_TIMEOUT_MS,
    );
    cachedServiceDescriptions.set(cacheKey, resultText);
    return json({ success: true, text: resultText, source: "gemini" });
  } catch (err) {
    if (isRateLimitError(err)) {
      geminiCooldownUntil = Date.now() + COOLDOWN_MS;
    }
    return json({ success: true, text: fallback, source: "smart_fallback" });
  }
}

function contractContext(body: OsAiBody): Record<string, unknown> {
  return body.context ?? {};
}

function defaultContractTitle(ctx: Record<string, unknown>): string {
  const target = String(ctx.targetName ?? "الطرف الثاني").trim() || "الطرف الثاني";
  const template = String(ctx.templateTitle ?? ctx.contractTitle ?? "عقد خدمات إبداعية").trim();
  return `عقد ${template} — ${target}`;
}

function defaultContractScope(ctx: Record<string, unknown>): string {
  const target = String(ctx.targetName ?? "العميل").trim() || "العميل";
  const title = String(ctx.contractTitle ?? "الخدمات الإبداعية").trim();
  const value = Number(ctx.totalValue || 0).toLocaleString("en-US");
  const currency = String(ctx.currency ?? "IQD").trim();
  const money = currency === "USD" ? `${value} $` : `${value} د.ع`;
  return `يلتزم الطرف الأول (وكالة نقطة) بتنفيذ ${title} للطرف الثاني (${target}) وفق المواصفات المعتمدة وجداول التسليم المتفق عليها، بقيمة إجمالية قدرها ${money}، وتشمل المخرجات الإبداعية والتنسيق والمتابعة حتى الاعتماد النهائي.`;
}

function defaultContractClause(ctx: Record<string, unknown>): string {
  const clauseTitle = String(ctx.clauseTitle ?? "بند تعاقدي").trim() || "بند تعاقدي";
  return `اتفق الطرفان على ${clauseTitle} بما يتوافق مع القوانين العراقية النافذة وبنود هذا العقد، ويلتزمان بتنفيذه بحسن نية ودون إخلال بالحقوق والالتزامات المتبادلة.`;
}

function defaultTemplateClauses(ctx: Record<string, unknown>): string {
  const name = String(
    ctx.templateTitle ?? ctx.contractTitle ?? "عقد خدمات إبداعية",
  ).trim();
  const subType = String(ctx.subType ?? "خدمات إبداعية وتسويق").trim();
  const months = Number(ctx.defaultDurationMonths || 6);
  const law = String(
    ctx.governingLaw ??
      "القانون المدني العراقي رقم (40) لسنة 1951 وأنظمة العقود النافذة في جمهورية العراق",
  ).trim();
  const desc = String(ctx.templateDescription ?? "").trim();
  const scopeHint = desc.length > 0 ? desc : subType;

  const clauses = [
    {
      title: "المادة الأولى: التمهيد وأهلية التعاقد",
      content:
        `لما كان الطرف الأول (وكالة نقطة للإنتاج الإبداعي) متخصصاً في ${subType}، ولما كان الطرف الثاني يرغب بالاستفادة من خبراته لتنفيذ ${name}، فقد اتفق الطرفان بكامل أهليتهما القانونية وفق أحكام المادة (146) من القانون المدني العراقي على أن العقد شريعة المتعاقدين.`,
    },
    {
      title: "المادة الثانية: نطاق الخدمات والمخرجات",
      content:
        `يلتزم الطرف الأول بتنفيذ ${name} وفق المواصفات المعتمدة وملحق العمل، بما يشمل ${scopeHint}، والتنسيق والمتابعة حتى الاعتماد النهائي من الطرف الثاني.`,
    },
    {
      title: "المادة الثالثة: الأتعاب والالتزامات المالية",
      content:
        "يلتزم الطرف الثاني بسداد الأتعاب المتفق عليها وفق جدول الدفعات المرفق. وفي حال التأخر عن السداد لأكثر من المدة المتفق عليها، يحق للطرف الأول إيقاف الخدمات مؤقتاً دون مسؤولية عن أضرار ناتجة عن ذلك، مع احتفاظه بحق المطالبة بالمستحقات.",
    },
    {
      title: "المادة الرابعة: الملكية الفكرية",
      content:
        "تؤول حقوق المخرجات المنفذة والمدفوعة بالكامل للطرف الثاني، مع احتفاظ الطرف الأول بحق إدراج نماذج من الأعمال في سابقة أعماله لأغراض الترويج غير التجاري للوكالة.",
    },
    {
      title: "المادة الخامسة: السرية وحماية البيانات",
      content:
        "يلتزم الطرفان بالحفاظ على سرية المعلومات والبيانات التي يطلع عليها أي منهما بمناسبة تنفيذ هذا العقد، ولا يجوز إفشاؤها لطرف ثالث أثناء سريان العقد أو بعده لمدة ثلاث سنوات.",
    },
    {
      title: "المادة السادسة: مدة العقد والإنهاء",
      content:
        `يسري هذا العقد لمدة ${months} أشهر من تاريخ التوقيع، ويجوز تجديده بموافقة خطية. ويجوز لأي طرف إنهاء العقد بإشعار خطي قبل (30) يوماً من تاريخ الإنهاء المرغوب، مع مراعاة المستحقات عن الأعمال المنفذة.`,
    },
    {
      title: "المادة السابعة: القانون الحاكم والاختصاص القضائي",
      content:
        `يخضع هذا العقد ويفسر وفقاً لـ${law}. وتختص محاكم بغداد / الكرخ حصرياً بالنظر في أي نزاع يتعذر حله ودياً خلال (15) يوماً.`,
    },
  ];
  return JSON.stringify(clauses);
}

async function handleContractField(
  body: OsAiBody,
  accessToken: string,
  projectId: string,
) {
  const field = (body.field ?? "").trim();
  const ctx = contractContext(body);
  const cacheKey = `${field}_${JSON.stringify(ctx)}`;

  let fallback = "";
  let prompt = "";

  if (field === "title") {
    fallback = defaultContractTitle(ctx);
    prompt =
      `اكتب عنواناً عربياً رسمياً وموجزاً لعقد قانوني لوكالة نقطة للإنتاج الإبداعي والتسويق بناءً على: ${JSON.stringify(ctx)}. أعد العنوان فقط بدون شرح.`;
  } else if (field === "scope") {
    fallback = defaultContractScope(ctx);
    prompt =
      `اكتب نطاق عمل ومخرجات تنفيذية عربية احترافية (3 إلى 5 جمل) لعقد وكالة نقطة بناءً على: ${JSON.stringify(ctx)}. ركز على الخدمات، المخرجات، والالتزامات التشغيلية.`;
  } else if (field === "clause") {
    fallback = defaultContractClause(ctx);
    prompt =
      `صغ بنداً قانونياً عربياً رسمياً (فقرة إلى فقرتين) لعقد وكالة نقطة بعنوان "${String(ctx.clauseTitle ?? "")}" مع مراعاة السياق: ${JSON.stringify(ctx)}. أعد نص البند فقط.`;
  } else if (field === "governing-law") {
    fallback = String(
      ctx.governingLaw ??
        "القانون المدني العراقي رقم (40) لسنة 1951 وأنظمة العقود النافذة في جمهورية العراق",
    );
    prompt =
      `اكتب سطراً أو سطرين عربياً رسمياً يحددان السند والغطاء القانوني (القانون الحاكم) لعقد وكالة نقطة بناءً على: ${JSON.stringify(ctx)}. أعد النص فقط مع ذكر القوانين العراقية المناسبة (مدني، عمل، مؤلف).`;
  } else if (field === "custom-terms") {
    fallback =
      "أي تعديل على العقد يجب أن يكون مكتوباً وموقعاً من الطرفين. تُحل النزاعات ودياً أولاً خلال خمسة عشر يوماً.";
    prompt =
      `اكتب شروطاً خاصة إضافية عربية مختصرة (2-4 جمل) لعقد وكالة نقطة بناءً على: ${JSON.stringify(ctx)}. ركز على التعديلات، الإشعارات، وحل النزاعات. أعد النص فقط.`;
  } else if (field === "jurisdiction") {
    const targetType = String(ctx.targetType ?? "").toUpperCase();
    fallback =
      targetType === "EMPLOYEE"
        ? "محاكم العمل المختصة في بغداد / الكرخ"
        : "محاكم بغداد / الكرخ المختصة نزاعياً وفق القانون المدني العراقي";
    prompt =
      `اكتب جملة عربية رسمية واحدة تحدد الاختصاص القضائي المكاني لعقد وكالة نقطة بناءً على: ${JSON.stringify(ctx)}. أعد النص فقط.`;
  } else if (field === "template-description") {
    const name = String(ctx.templateTitle ?? ctx.contractTitle ?? "نموذج عقد");
    fallback = `نموذج قانوني جاهز لـ${name} يغطي نطاق الخدمات والالتزامات وفق المرجعيات العراقية المعتمدة.`;
    prompt =
      `اكتب وصفاً عربياً تسويقياً-قانونياً مختصراً (2-3 جمل) لكتالوج نموذج عقد لوكالة نقطة باسم "${name}" مع السياق: ${JSON.stringify(ctx)}. أعد الوصف فقط.`;
  } else if (field === "payment-schedule") {
    fallback = JSON.stringify([
      {
        milestone: "الدفعة الأولى (مقدمة تعاقد)",
        percentage: 50,
        dueDateDescription: "فور توقيع العقد",
      },
      {
        milestone: "الدفعة الثانية (مرحلية)",
        percentage: 30,
        dueDateDescription: "منتصف مدة التنفيذ",
      },
      {
        milestone: "الدفعة الثالثة (تسليم نهائي)",
        percentage: 20,
        dueDateDescription: "عند التسليم النهائي المعتمد",
      },
    ]);
    prompt =
      `اقترح جدول دفعات عربياً لعقد وكالة نقطة بناءً على: ${JSON.stringify(ctx)}. أعد JSON فقط كمصفوفة من 2 إلى 4 عناصر بالشكل: [{"milestone":"...","percentage":50,"dueDateDescription":"..."}] حيث مجموع percentage = 100. لا تضف شرحاً.`;
  } else if (field === "template-clauses") {
    fallback = defaultTemplateClauses(ctx);
    prompt =
      `صغ مجموعة مواد وبنود قانونية عراقية رسمية (من 6 إلى 10 مواد) لعقد أو نموذج عقد لوكالة نقطة للإنتاج الإبداعي والتسويق، بناءً على السياق: ${JSON.stringify(ctx)}. استخدم عناوين بالشكل "المادة الأولى: ..." ثم "المادة الثانية: ..." وهكذا. لكل مادة فقرة إلى ثلاث فقرات عربية رسمية تغطي التمهيد، نطاق الخدمات، الأتعاب، الملكية الفكرية، السرية، مدة العقد والإنهاء، والقانون الحاكم بما يناسب نوع الطرف (عميل/موظف/مستقل) والتصنيف والمدة. أعد JSON فقط كمصفوفة: [{"title":"...","content":"..."}] بدون أي شرح أو markdown.`;
  } else {
    return json({ errorCode: "ERR_INVALID_FIELD" }, 400);
  }

  if (cachedContractFields.has(cacheKey)) {
    return json({
      success: true,
      text: cachedContractFields.get(cacheKey),
      source: "cache",
    });
  }

  if (Date.now() < geminiCooldownUntil) {
    return json({ success: true, text: fallback, source: "smart_fallback" });
  }

  try {
    const resultText = await callWithTimeout(
      callGemini(prompt, accessToken, projectId),
      GEMINI_TIMEOUT_MS,
    );
    cachedContractFields.set(cacheKey, resultText);
    return json({ success: true, text: resultText, source: "gemini" });
  } catch (err) {
    if (isRateLimitError(err)) {
      geminiCooldownUntil = Date.now() + COOLDOWN_MS;
    }
    return json({ success: true, text: fallback, source: "smart_fallback" });
  }
}

async function handleSummarize(
  body: OsAiBody,
  accessToken: string,
  projectId: string,
) {
  const data = body.data ?? {};
  const fallback = defaultFinancialSummary(data);

  const rev = Number(data?.totalRevenue || 0).toLocaleString("en-US");
  const won = Number(data?.wonClients || 0);
  const total = Number(data?.clientCount || 0);
  const active = Number(data?.activeProjects || won);
  const cacheKey = `${rev}_${won}_${total}_${active}`;

  if (
    cachedFinancialSummary &&
    cachedFinancialSummary.key === cacheKey &&
    Date.now() - cachedFinancialSummary.timestamp < SUMMARY_CACHE_TTL_MS
  ) {
    return json({
      success: true,
      text: cachedFinancialSummary.text,
      source: "cache",
    });
  }

  if (Date.now() < geminiCooldownUntil) {
    return json({ success: true, text: fallback, source: "smart_fallback" });
  }

  try {
    const prompt =
      `أنت المستشار المالي والتشغيلي لوكالة نقطة للإنتاج الإبداعي والتسويق. حلل هذه البيانات المالية بدقة واكتب تحليلاً احترافياً موجزاً باللغة العربية (بين 3 و 4 أسطر) يركز على العائد، خط المشاريع، وتوصية عملية لزيادة التدفقات النقدية: ${JSON.stringify(data)}`;
    const resultText = await callWithTimeout(
      callGemini(prompt, accessToken, projectId),
      GEMINI_TIMEOUT_MS,
    );
    cachedFinancialSummary = {
      key: cacheKey,
      text: resultText,
      timestamp: Date.now(),
    };
    return json({ success: true, text: resultText, source: "gemini" });
  } catch (err) {
    if (isRateLimitError(err)) {
      geminiCooldownUntil = Date.now() + COOLDOWN_MS;
    }
    return json({ success: true, text: fallback, source: "smart_fallback" });
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

    const body = await req.json().catch(() => ({})) as OsAiBody;
    const action = (body.action ?? "").trim();

    if (action === "get-settings") {
      await assertOsAdmin(saAccessToken, caller.firebaseProjectId, caller.uid);
      return await handleGetSettings(saAccessToken, caller.firebaseProjectId);
    }
    if (action === "save-settings") {
      await assertOsAdmin(saAccessToken, caller.firebaseProjectId, caller.uid);
      return await handleSaveSettings(
        body,
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
      );
    }
    if (action === "service-description") {
      await assertOsAccess(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
        "services",
      );
      return await handleServiceDescription(
        body,
        saAccessToken,
        caller.firebaseProjectId,
      );
    }
    if (action === "summarize") {
      await assertOsAccess(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
        "finance",
      );
      return await handleSummarize(
        body,
        saAccessToken,
        caller.firebaseProjectId,
      );
    }
    if (action === "contract-field") {
      await assertOsAccess(
        saAccessToken,
        caller.firebaseProjectId,
        caller.uid,
        "contracts",
      );
      return await handleContractField(
        body,
        saAccessToken,
        caller.firebaseProjectId,
      );
    }

    return json({ errorCode: "ERR_INVALID_ACTION" }, 400);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg === "Forbidden") {
      return json({ errorCode: "ERR_FORBIDDEN" }, 403);
    }
    console.error("os-ai error:", msg);
    return json({ errorCode: "ERR_INTERNAL", message: msg }, 500);
  }
});
