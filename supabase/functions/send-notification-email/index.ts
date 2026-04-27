// Supabase Edge Function: إرسال إيميل إشعار عبر Resend (يتجنب CORS على الويب)
// ضع مفتاح Resend في Supabase: Dashboard → Project Settings → Edge Functions → Secrets
// أو: supabase secrets set RESEND_API_KEY=re_xxxx
// (المحرر قد يظهر خطأ "Cannot find name 'Deno'" لأن الكود لـ Deno وليس Node — الدالة تعمل عند النشر)

import "https://deno.land/std@0.177.0/http/server.ts";
import { buildEmailHtml, type EmailLocale } from "./email-template.ts";

const RESEND_URL = "https://api.resend.com/emails";
const FROM_EMAIL = "Point Agency <no-reply@mail.point-iq.app>";
const MAX_EMAIL_BATCH = 40;

/** نسخة نصية بسيطة عندما يكون الجسم HTML كاملاً (لجزء text/plain في MIME). */
function htmlToPlainText(html: string): string {
  const noScripts = html
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, " ")
    .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, " ");
  const withBreaks = noScripts
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|div|tr|h[1-6])\s*>/gi, "\n");
  const stripped = withBreaks.replace(/<[^>]+>/g, " ");
  return stripped
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]{2,}/g, " ")
    .trim();
}

async function sendOneViaResend(
  apiKey: string,
  toEmail: string,
  subject: string,
  rawBody: string,
  isHtml: boolean,
  language?: EmailLocale,
): Promise<{ ok: boolean; status: number; id?: string; details?: unknown }> {
  let textPart: string;
  let htmlPart: string;
  if (isHtml) {
    htmlPart = rawBody;
    textPart = htmlToPlainText(rawBody);
    if (!textPart) textPart = subject.trim() || "إشعار من Point Agency";
  } else {
    textPart = rawBody;
    htmlPart = buildEmailHtml(rawBody, language);
  }

  const res = await fetch(RESEND_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: FROM_EMAIL,
      to: [toEmail],
      subject,
      text: textPart,
      html: htmlPart,
    }),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    return { ok: false, status: res.status, details: data };
  }
  return { ok: true, status: res.status, id: (data as { id?: string })?.id };
}

function normalizeLanguageCode(value: unknown): EmailLocale | undefined {
  const raw = typeof value === "string" ? value.trim().toLowerCase() : "";
  if (!raw) return undefined;
  if (raw === "ar" || raw.startsWith("ar-")) return "ar";
  if (raw === "en" || raw.startsWith("en-")) return "en";
  return undefined;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders() });
  }

  try {
    const apiKey = Deno.env.get("RESEND_API_KEY");
    if (!apiKey) {
      return jsonResponse({ errorCode: "ERR_SERVER" }, 500);
    }

    const body = await req.json() as {
      toEmail?: string;
      subject?: string;
      body?: string;
      isHtml?: boolean;
      language?: string;
      messages?: Array<{
        toEmail?: string;
        subject?: string;
        body?: string;
        isHtml?: boolean;
        language?: string;
      }>;
    };

    if (Array.isArray(body.messages) && body.messages.length > 0) {
      if (body.toEmail) {
        return jsonResponse(
          { errorCode: "ERR_INVALID_DATA", details: "use either messages[] or toEmail, not both" },
          400,
        );
      }
      if (body.messages.length > MAX_EMAIL_BATCH) {
        return jsonResponse(
          { errorCode: "ERR_BATCH_TOO_LARGE", max: MAX_EMAIL_BATCH },
          400,
        );
      }
      const results: Array<{
        index: number;
        toEmail: string;
        ok: boolean;
        id?: string;
        status?: number;
        details?: unknown;
      }> = [];
      let okCount = 0;
      for (let i = 0; i < body.messages.length; i++) {
        const m = body.messages[i];
        const toEmail = m?.toEmail?.trim() ?? "";
        if (!toEmail) {
          results.push({
            index: i,
            toEmail: "",
            ok: false,
            details: { reason: "missing_toEmail" },
          });
          continue;
        }
        const subject = m?.subject ?? "";
        const rawBody = m?.body ?? "";
        const isHtml = m?.isHtml === true;
        const language = normalizeLanguageCode(m?.language);
        const out = await sendOneViaResend(apiKey, toEmail, subject, rawBody, isHtml, language);
        if (out.ok) okCount++;
        results.push({
          index: i,
          toEmail,
          ok: out.ok,
          id: out.id,
          status: out.status,
          details: out.ok ? undefined : out.details,
        });
      }
      return jsonResponse({
        ok: true,
        batch: true,
        results,
        summary: { ok: okCount, failed: results.length - okCount, total: results.length },
      }, 200);
    }

    const toEmail = body?.toEmail?.trim();
    const subject = body?.subject ?? "";
    const rawBody = body?.body ?? "";
    const isHtml = body?.isHtml === true;
    const language = normalizeLanguageCode(body?.language);

    if (!toEmail) {
      return jsonResponse({ errorCode: "ERR_EMAIL_REQUIRED" }, 400);
    }

    const out = await sendOneViaResend(apiKey, toEmail, subject, rawBody, isHtml, language);
    if (!out.ok) {
      return jsonResponse({ errorCode: "ERR_SERVER", details: out.details }, out.status);
    }

    return jsonResponse({ ok: true, id: out.id }, 200);
  } catch (e) {
    return jsonResponse({ errorCode: "ERR_SERVER", details: String(e) }, 500);
  }
});

function jsonResponse(obj: object, status: number): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}
