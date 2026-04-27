// قالب HTML للإيميلات يطابق ألوان التطبيق (Point Agency)
// ألوان من lib/Utils/AppColors.dart: primary #6736AE, primaryfontColor #344054, greyBackground #F2F3F5

const BRAND_COLOR = "#6736AE";
const TEXT_COLOR = "#344054";
const BG_LIGHT = "#F2F3F5";
const GREY = "#778087";
const WHITE = "#ffffff";
const BORDER_COLOR = "#E6E8EC";

export type EmailLocale = "ar" | "en";

/** ي escap النص لاستخدامه داخل HTML */
function escapeHtml(raw: string): string {
  return raw
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function detectLocale(text: string): EmailLocale {
  return /[\u0600-\u06FF]/.test(text) ? "ar" : "en";
}

function renderEmailShell(args: {
  locale: EmailLocale;
  title: string;
  subtitle: string;
  contentHtml: string;
  metaText: string;
}): string {
  const dir = args.locale === "ar" ? "rtl" : "ltr";
  const align = args.locale === "ar" ? "right" : "left";
  const safeTitle = escapeHtml(args.title);
  const safeSubtitle = escapeHtml(args.subtitle);
  const safeMeta = escapeHtml(args.metaText);

  return `<!DOCTYPE html>
<html dir="${dir}" lang="${args.locale}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${safeTitle}</title>
</head>
<body style="margin:0;padding:0;background-color:${BG_LIGHT};font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${BG_LIGHT};min-height:100vh;">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:620px;background-color:${WHITE};border-radius:16px;border:1px solid ${BORDER_COLOR};box-shadow:0 8px 24px rgba(16,24,40,0.06);overflow:hidden;">
          <tr>
            <td style="background:linear-gradient(135deg, ${BRAND_COLOR} 0%, #552a8e 100%);padding:24px 28px;text-align:${align};">
              <p style="margin:0 0 6px 0;font-size:20px;font-weight:700;color:${WHITE};letter-spacing:-0.3px;">Point Agency</p>
              <p style="margin:0;font-size:13px;color:rgba(255,255,255,0.9);">${safeSubtitle}</p>
            </td>
          </tr>
          <tr>
            <td style="padding:24px 28px;text-align:${align};color:${TEXT_COLOR};">
              <div dir="${dir}" style="direction:${dir};text-align:${align};unicode-bidi:embed;">
                ${args.contentHtml}
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:14px 28px;border-top:1px solid ${BORDER_COLOR};background:#FAFAFC;">
              <p style="margin:0;font-size:12px;color:${GREY};text-align:${align};">${safeMeta}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/**
 * يُرجع HTML كامل للإيميل مع المحتوى المعطى.
 * @param bodyText النص الرئيسي (يُحوّل إلى فقرات إن احتوى أسطر جديدة)
 */
export function buildEmailHtml(bodyText: string): string {
  const locale = detectLocale(bodyText);
  const isArabic = locale === "ar";
  const lines = bodyText
    .split(/\n+/)
    .map((p) => p.trim())
    .filter((p) => p.length > 0);

  const keyValueRows: Array<{ key: string; value: string }> = [];
  const paragraphs: string[] = [];
  for (const line of lines) {
    const idx = line.indexOf(":");
    if (idx > 0 && idx < line.length - 1) {
      keyValueRows.push({
        key: line.slice(0, idx).trim(),
        value: line.slice(idx + 1).trim(),
      });
      continue;
    }
    paragraphs.push(line);
  }

  const paragraphsHtml = paragraphs
    .map((p) => `<p style="margin:0 0 10px 0;font-size:15px;line-height:1.65;color:${TEXT_COLOR};"><span dir="auto">${escapeHtml(p)}</span></p>`)
    .join("");
  const keyValueHtml = keyValueRows.length === 0
    ? ""
    : `
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin-top:10px;border:1px solid ${BORDER_COLOR};border-radius:10px;overflow:hidden;">
  ${keyValueRows
      .map((row) => `<tr>
    <td style="padding:10px 12px;font-size:13px;color:#667085;background:#FAFAFC;border-bottom:1px solid ${BORDER_COLOR};width:38%;font-weight:600;text-align:${isArabic ? "right" : "left"};"><span dir="auto">${escapeHtml(row.key)}</span></td>
    <td style="padding:10px 12px;font-size:14px;color:${TEXT_COLOR};border-bottom:1px solid ${BORDER_COLOR};text-align:${isArabic ? "right" : "left"};"><span dir="auto" style="unicode-bidi:isolate;">${escapeHtml(row.value)}</span></td>
  </tr>`)
      .join("")}
</table>
`;

  const primaryMessage = paragraphsHtml || `<p style="margin:0;font-size:15px;line-height:1.65;color:${TEXT_COLOR};">${escapeHtml(bodyText || "")}</p>`;
  const contentHtml = `
<h1 style="margin:0 0 12px 0;font-size:22px;line-height:1.3;color:${TEXT_COLOR};font-weight:700;">
  ${isArabic ? "إشعار جديد" : "New Notification"}
</h1>
${primaryMessage}
${keyValueHtml}
`;
  return renderEmailShell({
    locale,
    title: "Point Agency",
    subtitle: isArabic ? "تحديث من تطبيق Point" : "Update from Point app",
    contentHtml,
    metaText: isArabic ? "تم إرسال هذا الإشعار تلقائياً." : "This notification was sent automatically.",
  });
}

export type ChatDigestRow = {
  count: number;
  /** اسم المحادثة أو الطرف الآخر */
  label: string;
  /** رابط صورة HTTPS عامة أو فارغ */
  imageUrl?: string | null;
};

function digestUnreadRowLineAr(n: number, safeLabel: string): string {
  const k = Math.max(0, Math.floor(n));
  const word = k === 1 ? "رسالة" : k === 2 ? "رسالتان" : "رسائل";
  return `لديك ${k} ${word} غير مقروءة من ${safeLabel}`;
}

function digestUnreadRowLineEn(n: number, safeLabel: string): string {
  const k = Math.max(0, Math.floor(n));
  return `You have ${k} unread message${k === 1 ? "" : "s"} from ${safeLabel}`;
}

/**
 * بريد ملخص رسائل غير مقروءة (صف لكل محادثة) مع صور اختيارية.
 * @param language Recipient locale; when set, overrides guessing from [intro] (e.g. English UI with Arabic names in rows).
 */
export function buildChatUnreadDigestEmailHtml(args: {
  intro: string;
  rows: ChatDigestRow[];
  language?: EmailLocale;
}): string {
  const locale = args.language ?? detectLocale(args.intro);
  const isArabic = locale === "ar";
  const safeIntro = escapeHtml(args.intro);
  const rowHtml = args.rows
    .map((r) => {
      const safeLabel = escapeHtml(r.label);
      const n = Math.max(0, Math.floor(r.count));
      const line = isArabic ? digestUnreadRowLineAr(n, safeLabel) : digestUnreadRowLineEn(n, safeLabel);
      const img = r.imageUrl && /^https:\/\//i.test(r.imageUrl.trim())
        ? `<img src="${escapeHtml(r.imageUrl.trim())}" alt="" width="40" height="40" style="width:40px;height:40px;border-radius:50%;object-fit:cover;flex-shrink:0;border:1px solid ${BG_LIGHT};" />`
        : `<div style="width:40px;height:40px;border-radius:50%;background:${BG_LIGHT};flex-shrink:0;"></div>`;
      const cellPadding = isArabic ? "padding:12px 12px 12px 0;" : "padding:12px 0 12px 12px;";
      return `<tr>
  <td style="padding:12px 0;vertical-align:middle;width:48px;">${img}</td>
  <td style="${cellPadding}vertical-align:middle;font-size:15px;line-height:1.6;color:${TEXT_COLOR};">${line}</td>
</tr>`;
    })
    .join("");
  const contentHtml = `
<h1 style="margin:0 0 12px 0;font-size:22px;line-height:1.3;color:${TEXT_COLOR};font-weight:700;">
  ${isArabic ? "ملخص الرسائل غير المقروءة" : "Unread messages summary"}
</h1>
<p style="margin:0 0 12px 0;font-size:15px;line-height:1.65;color:${TEXT_COLOR};">${safeIntro}</p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
  ${rowHtml}
</table>
`;
  return renderEmailShell({
    locale,
    title: "Point Agency",
    subtitle: isArabic ? "ملخص الرسائل" : "Messages digest",
    contentHtml,
    metaText: isArabic ? "Point Agency — إشعار من التطبيق" : "Point Agency — app notification",
  });
}
