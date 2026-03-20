// Supabase Edge Function: إرسال إيميل إشعار عبر Resend (يتجنب CORS على الويب)
// ضع مفتاح Resend في Supabase: Dashboard → Project Settings → Edge Functions → Secrets
// أو: supabase secrets set RESEND_API_KEY=re_xxxx
// (المحرر قد يظهر خطأ "Cannot find name 'Deno'" لأن الكود لـ Deno وليس Node — الدالة تعمل عند النشر)

import "https://deno.land/std@0.177.0/http/server.ts";
import { buildEmailHtml } from "./email-template.ts";

const RESEND_URL = "https://api.resend.com/emails";
const FROM_EMAIL = "Point Agency <no-reply@mail.point-iq.app>";

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders() });
  }

  try {
    const apiKey = Deno.env.get("RESEND_API_KEY");
    if (!apiKey) {
      return jsonResponse({ error: "RESEND_API_KEY not set" }, 500);
    }

    const body = await req.json() as {
      toEmail?: string;
      subject?: string;
      body?: string;
      isHtml?: boolean;
    };
    const toEmail = body?.toEmail?.trim();
    const subject = body?.subject ?? "";
    const rawBody = body?.body ?? "";
    const isHtml = body?.isHtml === true;

    if (!toEmail) {
      return jsonResponse({ error: "toEmail required" }, 400);
    }

    let textPart: string;
    let htmlPart: string;
    if (isHtml) {
      htmlPart = rawBody;
      textPart = htmlToPlainText(rawBody);
      if (!textPart) textPart = subject.trim() || "إشعار من Point Agency";
    } else {
      textPart = rawBody;
      htmlPart = buildEmailHtml(rawBody);
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
      return jsonResponse({ error: "Resend error", details: data }, res.status);
    }

    return jsonResponse({ ok: true, id: data?.id }, 200);
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
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
