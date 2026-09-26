import 'package:point/Models/Os/OsEmailSettings.dart';

/// Brand tokens aligned with [email-template.ts] and AppColors.
class EmailBrand {
  EmailBrand._();

  static const primary = '#514091';
  static const primaryDark = '#1f1957';
  static const text = '#344054';
  static const textMuted = '#667085';
  static const textLight = '#98A2B3';
  static const bg = '#F2F3F5';
  static const border = '#E6E8EC';
  static const surface = '#FFFFFF';
  static const surfaceMuted = '#FAFAFC';
  static const accentTint = '#F8F5FD';
  static const success = '#067647';
  static const danger = '#B42318';
  static const warning = '#B54708';
  static const companyName = 'Point Agency';
}

/// Shared email document shell (RTL/LTR, table layout, inline CSS).
class EmailHtmlShell {
  EmailHtmlShell._();

  static String escape(String raw) {
    return raw
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String detectLocale(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? 'ar' : 'en';
  }

  static String render({
    required String locale,
    required String subtitle,
    required String heading,
    required String bodyHtml,
    String preheader = '',
    OsEmailSettings? settings,
    String signature = '',
  }) {
    final isArabic = locale == 'ar';
    final dir = isArabic ? 'rtl' : 'ltr';
    final align = isArabic ? 'right' : 'left';
    final year = DateTime.now().year;
    final safeSubtitle = escape(subtitle);
    final safeHeading = escape(heading);
    final safePreheader = escape(preheader);
    final rights = isArabic ? 'جميع الحقوق محفوظة' : 'All rights reserved';
    final signatureBlock = _signatureBlock(signature, align);
    final footerContact = _footerContact(settings, align, isArabic);

    return '''
<!DOCTYPE html>
<html lang="$locale" dir="$dir">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escape(EmailBrand.companyName)}</title>
  <link href="https://fonts.googleapis.com/css2?family=Almarai:wght@400;700;800&display=swap" rel="stylesheet">
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
<body style="margin:0;padding:0;background-color:${EmailBrand.bg};font-family:'Almarai',Arial,sans-serif;">
  <div class="preheader">$safePreheader</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${EmailBrand.bg};">
    <tr>
      <td align="center" style="padding:24px 12px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:${EmailBrand.surface};border:1px solid ${EmailBrand.border};">
          <tr>
            <td style="background-color:${EmailBrand.primaryDark};padding:24px 24px 22px 24px;color:#FFFFFF;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="$align" dir="$dir" style="font-size:20px;font-weight:700;line-height:1.3;">
                    ${escape(EmailBrand.companyName)}
                  </td>
                </tr>
                <tr>
                  <td align="$align" dir="$dir" style="padding-top:6px;font-size:13px;line-height:1.5;opacity:0.92;">
                    $safeSubtitle
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="$align" dir="$dir" style="padding:28px 24px 24px 24px;">
              <h1 style="margin:0 0 18px 0;font-size:22px;line-height:1.35;font-weight:800;color:#101828;text-align:$align;">
                $safeHeading
              </h1>
              <div style="font-size:14px;line-height:1.7;color:${EmailBrand.text};text-align:$align;">
                $bodyHtml
              </div>
              $signatureBlock
            </td>
          </tr>
          <tr>
            <td align="$align" dir="$dir" style="padding:18px 24px;background-color:${EmailBrand.surfaceMuted};border-top:1px solid ${EmailBrand.border};">
              $footerContact
              <p style="margin:8px 0 0 0;font-size:12px;color:${EmailBrand.textLight};text-align:$align;">
                © $year ${escape(EmailBrand.companyName)}. ${escape(rights)}
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>''';
  }

  static String paragraph(String text, {String align = 'start'}) {
    final safe = escape(text);
    return '<p style="margin:0 0 14px 0;font-size:14px;line-height:1.7;color:${EmailBrand.text};text-align:$align;"><span dir="auto">$safe</span></p>';
  }

  static String noteBox(String text, {String align = 'start'}) {
    final borderSide = align == 'right' ? 'border-right' : 'border-left';
    return '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 16px 0;">
  <tr>
    <td style="padding:12px 14px;background-color:${EmailBrand.accentTint};$borderSide:3px solid ${EmailBrand.primary};border-radius:8px;font-size:14px;line-height:1.6;color:#101828;text-align:$align;">
      <span dir="auto">${escape(text)}</span>
    </td>
  </tr>
</table>''';
  }

  static String infoBox(String html, {String align = 'start'}) {
    return '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 16px 0;">
  <tr>
    <td style="padding:12px 14px;background-color:${EmailBrand.surfaceMuted};border:1px solid ${EmailBrand.border};border-radius:8px;font-size:13px;line-height:1.6;color:${EmailBrand.text};text-align:$align;">
      $html
    </td>
  </tr>
</table>''';
  }

  static String highlightBand({
    required String label,
    required String value,
    required String align,
    String? secondaryLabel,
    String? secondaryValue,
    String background = EmailBrand.primary,
  }) {
    final secondary = (secondaryLabel != null && secondaryValue != null)
        ? '''
      <td align="${align == 'right' ? 'left' : 'right'}" style="vertical-align:middle;font-size:12px;line-height:1.5;color:#FFFFFF;opacity:0.95;">
        <span style="display:block;font-weight:700;">${escape(secondaryLabel)}</span>
        <span dir="auto">${escape(secondaryValue)}</span>
      </td>'''
        : '';
    return '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:16px 0;border-collapse:collapse;">
  <tr>
    <td style="padding:16px 18px;background-color:$background;border-radius:10px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
        <tr>
          <td align="$align" style="vertical-align:middle;">
            <span style="display:block;font-size:12px;line-height:1.4;color:#FFFFFF;opacity:0.92;">${escape(label)}</span>
            <span dir="auto" style="display:block;font-size:22px;line-height:1.3;font-weight:800;color:#FFFFFF;">${escape(value)}</span>
          </td>
          $secondary
        </tr>
      </table>
    </td>
  </tr>
</table>''';
  }

  static String keyValueTable(
    List<EmailKeyValue> rows, {
    required String align,
  }) {
    if (rows.isEmpty) return '';
    final cells = rows
        .map(
          (row) => '''
<tr>
  <td style="padding:8px 10px;border-bottom:1px solid ${EmailBrand.border};font-size:12px;color:${EmailBrand.textMuted};text-align:$align;width:42%;">${escape(row.label)}</td>
  <td style="padding:8px 10px;border-bottom:1px solid ${EmailBrand.border};font-size:13px;font-weight:700;color:#101828;text-align:$align;"><span dir="auto">${escape(row.value)}</span></td>
</tr>''',
        )
        .join();
    return '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 16px 0;border:1px solid ${EmailBrand.border};border-radius:8px;overflow:hidden;border-collapse:collapse;">
  $cells
</table>''';
  }

  static String dataTable({
    required List<String> headers,
    required List<List<String>> rows,
    required String align,
  }) {
    if (rows.isEmpty) return '';
    final head = headers
        .map(
          (h) =>
              '<th style="padding:10px 12px;background-color:${EmailBrand.surfaceMuted};border-bottom:1px solid ${EmailBrand.border};font-size:12px;font-weight:800;color:${EmailBrand.textMuted};text-align:$align;">${escape(h)}</th>',
        )
        .join();
    final body = rows
        .map(
          (row) => '''
<tr>
${row.map((cell) => '<td style="padding:10px 12px;border-bottom:1px solid ${EmailBrand.border};font-size:13px;color:#101828;text-align:$align;"><span dir="auto">${escape(cell)}</span></td>').join()}
</tr>''',
        )
        .join();
    return '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 16px 0;border:1px solid ${EmailBrand.border};border-radius:8px;border-collapse:collapse;">
  <thead><tr>$head</tr></thead>
  <tbody>$body</tbody>
</table>''';
  }

  static String moneyRow({
    required String label,
    required String amount,
    required String align,
    String color = EmailBrand.text,
    String prefix = '',
  }) {
    return '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 6px 0;">
  <tr>
    <td style="font-size:13px;color:${EmailBrand.textMuted};text-align:$align;">${escape(label)}</td>
    <td style="font-size:13px;font-weight:800;color:$color;text-align:${align == 'right' ? 'left' : 'right'};white-space:nowrap;"><span dir="auto">$prefix${escape(amount)}</span></td>
  </tr>
</table>''';
  }

  static String sectionTitle(String title, {required String align}) {
    return '''
<p style="margin:18px 0 8px 0;font-size:13px;font-weight:800;color:#101828;text-align:$align;">${escape(title)}</p>''';
  }

  static String ctaButton({
    required String label,
    required String href,
    String backgroundColor = EmailBrand.primaryDark,
  }) {
    final safeHref = escape(href);
    final safeLabel = escape(label);
    return '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:18px 0;">
  <tr>
    <td align="center">
      <a href="$safeHref" style="display:inline-block;padding:12px 22px;background-color:$backgroundColor;color:#FFFFFF;text-decoration:none;border-radius:8px;font-size:14px;font-weight:700;">
        $safeLabel
      </a>
    </td>
  </tr>
</table>''';
  }

  static String badge(String text, {String color = EmailBrand.primary}) {
    return '''
<span style="display:inline-block;padding:4px 10px;background-color:${EmailBrand.accentTint};border:1px solid $color;border-radius:999px;font-size:11px;font-weight:800;color:$color;">${escape(text)}</span>''';
  }

  static String quoteBlock(String text, {required String align}) {
    return '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:12px 0 16px 0;">
  <tr>
    <td style="padding:14px 16px;background-color:${EmailBrand.surfaceMuted};border:1px solid ${EmailBrand.border};border-radius:10px;font-size:14px;line-height:1.7;color:#101828;font-style:italic;text-align:$align;">
      <span dir="auto">"${escape(text)}"</span>
    </td>
  </tr>
</table>''';
  }

  static String _signatureBlock(String signature, String align) {
    final trimmed = signature.trim();
    if (trimmed.isEmpty) return '';
    return '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:18px;border-top:1px solid ${EmailBrand.border};">
  <tr>
    <td style="padding-top:14px;font-size:12px;line-height:1.6;color:${EmailBrand.textMuted};text-align:$align;white-space:pre-line;">
      <span dir="auto">${escape(trimmed)}</span>
    </td>
  </tr>
</table>''';
  }

  static String _footerContact(
    OsEmailSettings? settings,
    String align,
    bool isArabic,
  ) {
    if (settings == null) return '';
    final parts = <String>[];
    final address = settings.companyAddress.trim();
    final phone = settings.companyPhone.trim();
    final website = settings.companyWebsite.trim();
    if (address.isNotEmpty) parts.add(address);
    if (phone.isNotEmpty) {
      parts.add(isArabic ? 'هاتف: $phone' : 'Phone: $phone');
    }
    if (website.isNotEmpty) parts.add(website);
    if (parts.isEmpty) return '';
    return '''
<p style="margin:0;font-size:12px;line-height:1.6;color:${EmailBrand.textMuted};text-align:$align;">
  ${escape(parts.join(' · '))}
</p>''';
  }
}

class EmailKeyValue {
  const EmailKeyValue({required this.label, required this.value});

  final String label;
  final String value;
}
