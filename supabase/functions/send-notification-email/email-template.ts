// قالب HTML للإيميلات يطابق ألوان التطبيق (Point Agency)
// ألوان من lib/Utils/AppColors.dart: primary #6736AE, primaryfontColor #344054, greyBackground #F2F3F5

const BRAND_COLOR = "#6736AE";
const TEXT_COLOR = "#344054";
const BG_LIGHT = "#F2F3F5";
const GREY = "#778087";
const WHITE = "#ffffff";

/** ي escap النص لاستخدامه داخل HTML */
function escapeHtml(raw: string): string {
  return raw
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/**
 * يُرجع HTML كامل للإيميل مع المحتوى المعطى.
 * @param bodyText النص الرئيسي (يُحوّل إلى فقرات إن احتوى أسطر جديدة)
 */
export function buildEmailHtml(bodyText: string): string {
  const safeBody = escapeHtml(bodyText);
  const bodyParagraphs = safeBody
    .split(/\n+/)
    .filter((p) => p.trim())
    .map((p) => `<p style="margin:0 0 12px 0;font-size:15px;line-height:1.5;color:${TEXT_COLOR};">${p.trim()}</p>`)
    .join("");

  return `<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Point Agency</title>
</head>
<body style="margin:0;padding:0;background-color:${BG_LIGHT};font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${BG_LIGHT};min-height:100vh;">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background-color:${WHITE};border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.06);overflow:hidden;">
          <tr>
            <td style="background:linear-gradient(135deg, ${BRAND_COLOR} 0%, #552a8e 100%);padding:24px 28px;text-align:center;">
              <span style="font-size:22px;font-weight:700;color:${WHITE};letter-spacing:-0.5px;">Point Agency</span>
            </td>
          </tr>
          <tr>
            <td style="padding:28px;">
              <div style="color:${TEXT_COLOR};">
                ${bodyParagraphs || `<p style="margin:0;font-size:15px;line-height:1.5;">${safeBody || ""}</p>`}
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 28px;border-top:1px solid ${BG_LIGHT};">
              <p style="margin:0;font-size:12px;color:${GREY};text-align:center;">Point Agency — إشعار من التطبيق</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

export type ChatDigestRow = {
  count: number;
  /** اسم المحادثة أو الطرف الآخر */
  label: string;
  /** رابط صورة HTTPS عامة أو فارغ */
  imageUrl?: string | null;
};

/**
 * بريد ملخص رسائل غير مقروءة (صف لكل محادثة) مع صور اختيارية.
 */
export function buildChatUnreadDigestEmailHtml(args: {
  intro: string;
  rows: ChatDigestRow[];
}): string {
  const safeIntro = escapeHtml(args.intro);
  const rowHtml = args.rows
    .map((r) => {
      const safeLabel = escapeHtml(r.label);
      const n = Math.max(0, Math.floor(r.count));
      const line = `You have ${n} unread message${n === 1 ? "" : "s"} from ${safeLabel}`;
      const img = r.imageUrl && /^https:\/\//i.test(r.imageUrl.trim())
        ? `<img src="${escapeHtml(r.imageUrl.trim())}" alt="" width="40" height="40" style="width:40px;height:40px;border-radius:50%;object-fit:cover;flex-shrink:0;border:1px solid ${BG_LIGHT};" />`
        : `<div style="width:40px;height:40px;border-radius:50%;background:${BG_LIGHT};flex-shrink:0;"></div>`;
      return `<tr>
  <td style="padding:12px 0;vertical-align:middle;width:48px;">${img}</td>
  <td style="padding:12px 0 12px 12px;vertical-align:middle;font-size:15px;line-height:1.5;color:${TEXT_COLOR};">${line}</td>
</tr>`;
    })
    .join("");

  return `<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Point Agency</title>
</head>
<body style="margin:0;padding:0;background-color:${BG_LIGHT};font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${BG_LIGHT};min-height:100vh;">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background-color:${WHITE};border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.06);overflow:hidden;">
          <tr>
            <td style="background:linear-gradient(135deg, ${BRAND_COLOR} 0%, #552a8e 100%);padding:24px 28px;text-align:center;">
              <span style="font-size:22px;font-weight:700;color:${WHITE};letter-spacing:-0.5px;">Point Agency</span>
            </td>
          </tr>
          <tr>
            <td style="padding:28px 28px 8px 28px;">
              <p style="margin:0 0 16px 0;font-size:15px;line-height:1.5;color:${TEXT_COLOR};">${safeIntro}</p>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
                ${rowHtml}
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 28px;border-top:1px solid ${BG_LIGHT};">
              <p style="margin:0;font-size:12px;color:${GREY};text-align:center;">Point Agency — إشعار من التطبيق</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}
