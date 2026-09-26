import 'package:point/Models/Os/OsEmailSettings.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Services/email/email_html_shell.dart';

/// Typed HTML builders for Point OS hub emails and app notifications.
class EmailHtmlBuilders {
  EmailHtmlBuilders._();

  static String _align(String locale) => locale == 'ar' ? 'right' : 'left';

  static String invoice({
    required String locale,
    required String subtitle,
    required String heading,
    required String greeting,
    required String intro,
    required String reference,
    required String totalLabel,
    required String totalAmount,
    required String dueDateLabel,
    required String dueDate,
    required List<OsLineItem> items,
    required String colItem,
    required String colQty,
    required String colTotal,
    String customNote = '',
    String paymentLink = '',
    String payCtaLabel = '',
    OsEmailSettings? settings,
    String signature = '',
    String preheader = '',
  }) {
    final align = _align(locale);
    final body = <String>[
      EmailHtmlShell.paragraph(greeting, align: align),
      EmailHtmlShell.paragraph(intro, align: align),
      if (customNote.trim().isNotEmpty)
        EmailHtmlShell.noteBox(customNote.trim(), align: align),
      if (items.isNotEmpty)
        EmailHtmlShell.dataTable(
          headers: [colItem, colQty, colTotal],
          rows: items
              .map(
                (item) => [
                  item.description,
                  '${item.quantity}',
                  _formatMoney(item.total),
                ],
              )
              .toList(growable: false),
          align: align,
        ),
      EmailHtmlShell.highlightBand(
        label: totalLabel,
        value: totalAmount,
        align: align,
        secondaryLabel: dueDateLabel,
        secondaryValue: dueDate,
      ),
      if (paymentLink.trim().isNotEmpty && payCtaLabel.trim().isNotEmpty)
        EmailHtmlShell.ctaButton(
          label: payCtaLabel,
          href: paymentLink.trim(),
        ),
      EmailHtmlShell.paragraph(reference, align: align),
    ].join();

    return EmailHtmlShell.render(
      locale: locale,
      subtitle: subtitle,
      heading: heading,
      bodyHtml: body,
      preheader: preheader.isNotEmpty ? preheader : totalAmount,
      settings: settings,
      signature: signature,
    );
  }

  static String quotation({
    required String locale,
    required String subtitle,
    required String heading,
    required String greeting,
    required String intro,
    required String reference,
    required String totalLabel,
    required String totalAmount,
    required String expiryLabel,
    required String expiryDate,
    String acceptLink = '',
    String acceptCtaLabel = '',
    OsEmailSettings? settings,
    String signature = '',
    String preheader = '',
  }) {
    final align = _align(locale);
    final body = <String>[
      EmailHtmlShell.paragraph(greeting, align: align),
      if (intro.trim().isNotEmpty)
        EmailHtmlShell.paragraph(intro.trim(), align: align),
      EmailHtmlShell.highlightBand(
        label: totalLabel,
        value: totalAmount,
        align: align,
        secondaryLabel: expiryLabel,
        secondaryValue: expiryDate,
      ),
      if (acceptLink.trim().isNotEmpty && acceptCtaLabel.trim().isNotEmpty)
        EmailHtmlShell.ctaButton(
          label: acceptCtaLabel,
          href: acceptLink.trim(),
        ),
      EmailHtmlShell.paragraph(reference, align: align),
    ].join();

    return EmailHtmlShell.render(
      locale: locale,
      subtitle: subtitle,
      heading: heading,
      bodyHtml: body,
      preheader: preheader.isNotEmpty ? preheader : totalAmount,
      settings: settings,
      signature: signature,
    );
  }

  static String payslip({
    required String locale,
    required String subtitle,
    required String heading,
    required String greeting,
    required String period,
    required String employeeName,
    required String positionLabel,
    required String position,
    required String emailLabel,
    required String email,
    required String earningsTitle,
    required String deductionsTitle,
    required String basicLabel,
    required String basicAmount,
    required String allowancesLabel,
    required String allowancesAmount,
    required String deductionsLabel,
    required String deductionsAmount,
    required String netPayLabel,
    required String netPayAmount,
    required String paymentMethodLabel,
    required String paymentMethod,
    String note = '',
    OsEmailSettings? settings,
    String signature = '',
    String preheader = '',
  }) {
    final align = _align(locale);
    final body = <String>[
      EmailHtmlShell.paragraph(greeting, align: align),
      EmailHtmlShell.keyValueTable(
        [
          EmailKeyValue(label: period, value: employeeName),
          EmailKeyValue(label: positionLabel, value: position),
          EmailKeyValue(label: emailLabel, value: email),
        ],
        align: align,
      ),
      EmailHtmlShell.sectionTitle(earningsTitle, align: align),
      EmailHtmlShell.moneyRow(
        label: basicLabel,
        amount: basicAmount,
        align: align,
      ),
      EmailHtmlShell.moneyRow(
        label: allowancesLabel,
        amount: allowancesAmount,
        align: align,
        color: EmailBrand.success,
        prefix: '+',
      ),
      EmailHtmlShell.sectionTitle(deductionsTitle, align: align),
      EmailHtmlShell.moneyRow(
        label: deductionsLabel,
        amount: deductionsAmount,
        align: align,
        color: EmailBrand.danger,
        prefix: '-',
      ),
      EmailHtmlShell.highlightBand(
        label: netPayLabel,
        value: netPayAmount,
        align: align,
        secondaryLabel: paymentMethodLabel,
        secondaryValue: paymentMethod,
        background: EmailBrand.primary,
      ),
      if (note.trim().isNotEmpty)
        EmailHtmlShell.paragraph(note.trim(), align: align),
    ].join();

    return EmailHtmlShell.render(
      locale: locale,
      subtitle: subtitle,
      heading: heading,
      bodyHtml: body,
      preheader: preheader.isNotEmpty ? preheader : netPayAmount,
      settings: settings,
      signature: signature,
    );
  }

  static String appreciation({
    required String locale,
    required String subtitle,
    required String heading,
    required String certificateTitle,
    required String bodyText,
    required String employeeName,
    required String positionLine,
    required String reason,
    String bonusLine = '',
    OsEmailSettings? settings,
    String signature = '',
    String preheader = '',
  }) {
    final align = _align(locale);
    final body = <String>[
      EmailHtmlShell.paragraph(bodyText, align: align),
      EmailHtmlShell.infoBox(
        '<p style="margin:0 0 8px 0;font-size:15px;font-weight:800;color:${EmailBrand.primary};text-align:center;">${EmailHtmlShell.escape(certificateTitle)}</p>'
        '<p style="margin:0 0 6px 0;font-size:18px;font-weight:800;color:#101828;text-align:center;"><span dir="auto">${EmailHtmlShell.escape(employeeName)}</span></p>'
        '<p style="margin:0;font-size:13px;color:${EmailBrand.textMuted};text-align:center;"><span dir="auto">${EmailHtmlShell.escape(positionLine)}</span></p>',
        align: align,
      ),
      if (reason.trim().isNotEmpty)
        EmailHtmlShell.quoteBlock(reason.trim(), align: align),
      if (bonusLine.trim().isNotEmpty)
        '<p style="margin:0 0 14px 0;text-align:center;">${EmailHtmlShell.badge(bonusLine.trim(), color: EmailBrand.warning)}</p>',
    ].join();

    return EmailHtmlShell.render(
      locale: locale,
      subtitle: subtitle,
      heading: heading,
      bodyHtml: body,
      preheader: preheader.isNotEmpty ? preheader : employeeName,
      settings: settings,
      signature: signature,
    );
  }

  static String penalty({
    required String locale,
    required String subtitle,
    required String heading,
    required String greeting,
    required String severityBadge,
    required String reasonTitle,
    required String reason,
    required String graceNote,
    String deductionLine = '',
    OsEmailSettings? settings,
    String signature = '',
    String preheader = '',
  }) {
    final align = _align(locale);
    final body = <String>[
      '<p style="margin:0 0 14px 0;text-align:$align;">${EmailHtmlShell.badge(severityBadge, color: EmailBrand.danger)}</p>',
      EmailHtmlShell.paragraph(greeting, align: align),
      EmailHtmlShell.sectionTitle(reasonTitle, align: align),
      EmailHtmlShell.noteBox(reason, align: align),
      if (deductionLine.trim().isNotEmpty)
        EmailHtmlShell.infoBox(
          '<span style="color:${EmailBrand.danger};font-weight:700;"><span dir="auto">${EmailHtmlShell.escape(deductionLine.trim())}</span></span>',
          align: align,
        ),
      EmailHtmlShell.paragraph(graceNote, align: align),
    ].join();

    return EmailHtmlShell.render(
      locale: locale,
      subtitle: subtitle,
      heading: heading,
      bodyHtml: body,
      preheader: preheader.isNotEmpty ? preheader : severityBadge,
      settings: settings,
      signature: signature,
    );
  }

  static String contract({
    required String locale,
    required String subtitle,
    required String heading,
    required String greeting,
    required String bodyText,
    required String contractNumberLabel,
    required String contractNumber,
    required String startDateLabel,
    required String startDate,
    required String amountLabel,
    required String amount,
    OsEmailSettings? settings,
    String signature = '',
    String preheader = '',
  }) {
    final align = _align(locale);
    final body = <String>[
      EmailHtmlShell.paragraph(greeting, align: align),
      EmailHtmlShell.paragraph(bodyText, align: align),
      EmailHtmlShell.keyValueTable(
        [
          EmailKeyValue(label: contractNumberLabel, value: contractNumber),
          EmailKeyValue(label: startDateLabel, value: startDate),
          EmailKeyValue(label: amountLabel, value: amount),
        ],
        align: align,
      ),
    ].join();

    return EmailHtmlShell.render(
      locale: locale,
      subtitle: subtitle,
      heading: heading,
      bodyHtml: body,
      preheader: preheader.isNotEmpty ? preheader : contractNumber,
      settings: settings,
      signature: signature,
    );
  }

  static String notification({
    required String locale,
    required String subtitle,
    required String title,
    required String greeting,
    required String summary,
    required String notificationTimeLabel,
    required String notificationTime,
    required String actionLabel,
    required String actionText,
    required String autoFooter,
    Map<String, String> details = const {},
    String quickDetailsTitle = '',
    OsEmailSettings? settings,
    String preheader = '',
  }) {
    final align = _align(locale);
    final detailRows = details.entries
        .where((e) => e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
        .map((e) => EmailKeyValue(label: e.key, value: e.value))
        .toList(growable: false);

    final body = <String>[
      EmailHtmlShell.paragraph(greeting, align: align),
      EmailHtmlShell.paragraph(summary, align: align),
      EmailHtmlShell.infoBox(
        '<strong>${EmailHtmlShell.escape(notificationTimeLabel)}:</strong> ${EmailHtmlShell.escape(notificationTime)}',
        align: align,
      ),
      if (detailRows.isNotEmpty && quickDetailsTitle.isNotEmpty) ...[
        EmailHtmlShell.sectionTitle(quickDetailsTitle, align: align),
        EmailHtmlShell.keyValueTable(detailRows, align: align),
      ],
      EmailHtmlShell.infoBox(
        '<strong>${EmailHtmlShell.escape(actionLabel)}:</strong> <span dir="auto">${EmailHtmlShell.escape(actionText)}</span>',
        align: align,
      ),
      EmailHtmlShell.paragraph(autoFooter, align: align),
    ].join();

    return EmailHtmlShell.render(
      locale: locale,
      subtitle: subtitle,
      heading: title,
      bodyHtml: body,
      preheader: preheader.isNotEmpty ? preheader : summary,
      settings: settings,
    );
  }

  static String chatDigest({
    required String locale,
    required String subtitle,
    required String heading,
    required String intro,
    required List<EmailChatDigestRow> rows,
    OsEmailSettings? settings,
    String preheader = '',
  }) {
    final align = _align(locale);
    final isArabic = locale == 'ar';
    final rowHtml = rows
        .map((row) {
          final line = isArabic
              ? 'لديك ${row.count} ${_arabicMessageWord(row.count)} غير مقروءة من ${row.label}'
              : 'You have ${row.count} unread message${row.count == 1 ? '' : 's'} from ${row.label}';
          final avatar = row.imageUrl != null && row.imageUrl!.startsWith('https://')
              ? '<img src="${EmailHtmlShell.escape(row.imageUrl!)}" alt="" width="40" height="40" style="width:40px;height:40px;border-radius:50%;object-fit:cover;border:1px solid ${EmailBrand.border};" />'
              : '<div style="width:40px;height:40px;border-radius:50%;background:${EmailBrand.bg};"></div>';
          final pad = isArabic ? 'padding:12px 12px 12px 0;' : 'padding:12px 0 12px 12px;';
          return '''
<tr>
  <td style="padding:12px 0;vertical-align:middle;width:48px;">$avatar</td>
  <td style="$pad vertical-align:middle;font-size:14px;line-height:1.6;color:${EmailBrand.text};"><span dir="auto">${EmailHtmlShell.escape(line)}</span></td>
</tr>''';
        })
        .join();

    final body = '''
${EmailHtmlShell.paragraph(intro, align: align)}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
  $rowHtml
</table>''';

    return EmailHtmlShell.render(
      locale: locale,
      subtitle: subtitle,
      heading: heading,
      bodyHtml: body,
      preheader: preheader.isNotEmpty ? preheader : intro,
      settings: settings,
    );
  }

  static String _formatMoney(double value) {
    final formatted = value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return formatted;
  }

  static String _arabicMessageWord(int count) {
    if (count == 1) return 'رسالة';
    if (count == 2) return 'رسالتان';
    return 'رسائل';
  }
}

class EmailChatDigestRow {
  const EmailChatDigestRow({
    required this.count,
    required this.label,
    this.imageUrl,
  });

  final int count;
  final String label;
  final String? imageUrl;
}
