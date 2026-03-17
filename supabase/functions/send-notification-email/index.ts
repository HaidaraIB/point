// Supabase Edge Function: إرسال إيميل إشعار عبر Resend (يتجنب CORS على الويب)
// ضع مفتاح Resend في Supabase: Dashboard → Project Settings → Edge Functions → Secrets
// أو: supabase secrets set RESEND_API_KEY=re_xxxx
// (المحرر قد يظهر خطأ "Cannot find name 'Deno'" لأن الكود لـ Deno وليس Node — الدالة تعمل عند النشر)

import "https://deno.land/std@0.177.0/http/server.ts";
import { buildEmailHtml } from "./email-template.ts";

const RESEND_URL = "https://api.resend.com/emails";
const FROM_EMAIL = "Point <no-reply@mail.point-iq.app>";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders() });
  }

  try {
    const apiKey = Deno.env.get("RESEND_API_KEY");
    if (!apiKey) {
      return jsonResponse({ error: "RESEND_API_KEY not set" }, 500);
    }

    const body = await req.json() as { toEmail?: string; subject?: string; body?: string };
    const toEmail = body?.toEmail?.trim();
    const subject = body?.subject ?? "";
    const textBody = body?.body ?? "";

    if (!toEmail) {
      return jsonResponse({ error: "toEmail required" }, 400);
    }

    const htmlBody = buildEmailHtml(textBody);

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
        text: textBody,
        html: htmlBody,
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
