// قالب HTML للإيميلات يطابق ألوان التطبيق (Point Agency)
// ألوان من lib/Utils/AppColors.dart: primary #514091, primaryDark #1f1957, primaryfontColor #344054, greyBackground #F2F3F5

const BRAND_COLOR = "#514091";
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
  heading: string;
  paragraphsHtml: string;
  metaText: string;
}): string {
  const dir = args.locale === "ar" ? "rtl" : "ltr";
  const lang = args.locale;
  const currentYear = new Date().getFullYear();
  const safeTitle = escapeHtml(args.title);
  const safeSubtitle = escapeHtml(args.subtitle);
  const safeHeading = escapeHtml(args.heading);
  const safeMeta = escapeHtml(args.metaText);
  const companyName = "Point Agency";
  const allRightsReservedText = args.locale === "ar" ? "جميع الحقوق محفوظة" : "All rights reserved";

  return `<!DOCTYPE html>
<html lang="${lang}" dir="${dir}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width">
  <title>${safeTitle}</title>

  <!-- Preheader (hidden preview text) -->
  <style>
    .preheader {
      display:none !important;
      visibility:hidden;
      opacity:0;
      color:transparent;
      height:0;
      width:0;
      overflow:hidden;
      mso-hide:all;
    }
  </style>
</head>

<body style="margin:0;padding:0;background-color:#F2F3F5;font-family:Segoe UI, Tahoma, Geneva, Verdana, sans-serif;">

  <!-- Preheader -->
  <div class="preheader">
    ${safeMeta}
  </div>

  <!-- Wrapper -->
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#F2F3F5;">
    <tr>
      <td align="center" style="padding:24px 12px;">

        <!-- Container -->
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
               style="max-width:600px;background-color:#FFFFFF;border:1px solid #E6E8EC;">

          <!-- Header -->
          <tr>
            <td align="center" dir="${dir}"
                style="background:linear-gradient(135deg,#1f1957 0%,#514091 100%);
                       padding:28px 24px;color:#FFFFFF;">

              <div style="direction:${dir}; text-align:center;">
                <p style="margin:0;font-size:20px;font-weight:700;">
                  ${companyName}
                </p>
                <p style="margin:6px 0 0 0;font-size:13px;opacity:0.9;">
                  ${safeSubtitle}
                </p>
              </div>

            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td align="center" dir="${dir}" style="padding:32px 24px;">

              <div style="max-width:480px;margin:0 auto;direction:${dir};text-align:center;unicode-bidi:embed;">

                <!-- Heading -->
                <h1 style="margin:0 0 16px 0;font-size:22px;line-height:1.4;font-weight:700;color:#101828;">
                  ${safeHeading}
                </h1>

                <!-- Content -->
                <div style="font-size:14px;line-height:1.7;color:#475467;">
                  ${args.paragraphsHtml}
                </div>

              </div>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" dir="${dir}"
                style="padding:20px;background-color:#FAFAFC;border-top:1px solid #E6E8EC;">

              <div style="max-width:480px;margin:0 auto;direction:${dir};text-align:center;">

                <p style="margin:0;font-size:12px;color:#98A2B3;">
                  © ${currentYear} ${companyName}. ${escapeHtml(allRightsReservedText)}
                </p>

              </div>

            </td>
          </tr>

        </table>

        <!-- Bottom spacing -->
        <div style="height:24px;"></div>

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
export function buildEmailHtml(bodyText: string, language?: EmailLocale): string {
  const locale = language ?? detectLocale(bodyText);
  const isArabic = locale === "ar";
  const lines = bodyText
    .split(/\n+/)
    .map((p) => p.trim())
    .filter((p) => p.length > 0);
  const paragraphsHtml = lines
    .map((p) => `<p style="margin:0 0 12px 0;font-size:14px;line-height:1.7;color:#475467;"><span dir="auto">${escapeHtml(p)}</span></p>`)
    .join("");
  const mergedParagraphsHtml =
    paragraphsHtml || `<p style="margin:0 0 12px 0;font-size:14px;line-height:1.7;color:#475467;"><span dir="auto">${escapeHtml(bodyText || "")}</span></p>`;
  return renderEmailShell({
    locale,
    title: "Point Agency",
    subtitle: isArabic ? "تحديث من تطبيق Point" : "Update from Point app",
    heading: isArabic ? "إشعار جديد" : "New Notification",
    paragraphsHtml: mergedParagraphsHtml,
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
  const paragraphsHtml = `
<p style="margin:0 0 12px 0;font-size:14px;line-height:1.7;color:#475467;"><span dir="auto">${safeIntro}</span></p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
  ${rowHtml}
</table>
`;
  return renderEmailShell({
    locale,
    title: "Point Agency",
    subtitle: isArabic ? "ملخص الرسائل" : "Messages digest",
    heading: isArabic ? "ملخص الرسائل غير المقروءة" : "Unread messages summary",
    paragraphsHtml,
    metaText: isArabic ? "Point Agency — إشعار من التطبيق" : "Point Agency — app notification",
  });
}
