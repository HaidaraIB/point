import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Services/os_quote_template_settings.dart';
import 'package:point/View/Os/Print/os_brand_print.dart';
import 'package:point/View/Os/Print/os_print_codes.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_line_item_print_format.dart';
import 'package:point/View/Os/os_print_a4.dart';

String buildOsQuotationPlainText(OsQuotationModel quote) {
  final ref = OsFinanceFormat.quotationRef(quote);
  final template = Get.isRegistered<OsQuoteTemplateController>()
      ? Get.find<OsQuoteTemplateController>()
      : null;
  final header = template?.headerText.value.trim().isNotEmpty == true
      ? template!.headerText.value
      : AppLocaleKeys.osQuotationsTemplateHeaderDefault.tr;
  final footer = template?.footerText.value.trim().isNotEmpty == true
      ? template!.footerText.value
      : AppLocaleKeys.osQuotationsTemplateFooterDefault.tr;

  final buf = StringBuffer()
    ..writeln(AppLocaleKeys.osPrintAgencyAr.tr)
    ..writeln('')
    ..writeln('${AppLocaleKeys.osQuotationsHeaderLabel.tr}: $header')
    ..writeln('${AppLocaleKeys.osQuotationsClient.tr}: ${quote.clientName}')
    ..writeln('${AppLocaleKeys.osQuotationsNumber.tr}: $ref')
    ..writeln('${AppLocaleKeys.osQuotationsIssueDate.tr}: ${quote.date}')
    ..writeln('${AppLocaleKeys.osQuotationsExpires.tr}: ${quote.expiryDate}')
    ..writeln('---');

  if (quote.items.isEmpty) {
    buf.writeln(
      '1. ${AppLocaleKeys.osInvoicesItemsFallback.tr} — '
      '${OsFinanceFormat.money(quote.amount > 0 ? quote.amount : quote.total)}',
    );
  } else {
    for (var i = 0; i < quote.items.length; i++) {
      final it = quote.items[i];
      buf.writeln(
        '${i + 1}. ${OsLineItemPrintFormat.plainDescription(it)} — '
        '${OsFinanceFormat.money(it.total)}',
      );
    }
  }

  buf
    ..writeln('---')
    ..writeln(
      '${AppLocaleKeys.osPrintSubtotal.tr}: '
      '${OsFinanceFormat.money(quote.amount > 0 ? quote.amount : quote.total)}',
    );
  if (quote.discount > 0) {
    buf.writeln(
      '${AppLocaleKeys.osPrintDiscount.tr}: ${OsFinanceFormat.money(quote.discount)}',
    );
  }
  if (quote.vat > 0) {
    buf.writeln(
      '${AppLocaleKeys.osInvoicesVat.tr}: ${OsFinanceFormat.money(quote.vat)}',
    );
  }
  buf
    ..writeln(
      '${AppLocaleKeys.osQuotationsTotal.tr}: ${OsFinanceFormat.money(quote.total)}',
    )
    ..writeln(
      '${AppLocaleKeys.osQuotationsApprovalStatus.tr}: '
      '${OsFinanceFormat.quotationStatusLabel(quote.status)}',
    );
  final notes = quote.notes?.trim() ?? '';
  if (notes.isNotEmpty) {
    buf
      ..writeln('')
      ..writeln('${AppLocaleKeys.osPrintNotes.tr}: $notes');
  }
  buf
    ..writeln('')
    ..writeln(footer);

  return buf.toString();
}

String buildOsQuotationPrintHtml(OsQuotationModel quote) {
  final ref = OsFinanceFormat.quotationRef(quote);

  final notesRaw = (quote.notes?.trim().isNotEmpty == true)
      ? quote.notes!.trim()
      : AppLocaleKeys.osPrintQuoteNotesDefault.tr;

  final rows = <String>[];
  if (quote.items.isEmpty) {
    final amt = quote.amount > 0 ? quote.amount : quote.total;
    rows.add(
      '<tr>'
      '<td>1</td>'
      '<td class="desc">${escapeHtml(AppLocaleKeys.osInvoicesItemsFallback.tr)}</td>'
      '<td>${OsBrandPrint.moneyHtml(amt)}</td>'
      '</tr>',
    );
  } else {
    for (var i = 0; i < quote.items.length; i++) {
      final it = quote.items[i];
      rows.add(
        '<tr>'
        '<td>${i + 1}</td>'
        '${OsLineItemPrintFormat.descHtml(it)}'
        '<td>${OsBrandPrint.moneyHtml(it.total)}</td>'
        '</tr>',
      );
    }
  }
  final padded = OsBrandPrint.padItemRows(rows, columnCount: 3);

  final phone = quote.clientPhone?.trim() ?? '';
  final email = quote.clientEmail?.trim() ?? '';
  final address = quote.clientAddress?.trim() ?? '';
  final clientName = quote.clientName.trim().isEmpty
      ? AppLocaleKeys.osPrintQuoteClientPlaceholder.tr
      : quote.clientName.trim();

  final validity = AppLocaleKeys.osPrintQuoteValidity.trParams({
    'days': '30',
  });

  final notesLines = notesRaw
      .split(RegExp(r'[\n•]+'))
      .map((e) => e.replaceFirst(RegExp(r'^[-–—]\s*'), '').trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final notesHtml = notesLines.isEmpty
      ? '<p></p>'
      : '<ul>${notesLines.map((l) => '<li>${escapeHtml(l)}</li>').join()}</ul>';

  final qr = OsPrintCodes.qrSvg(OsBrandPrint.agencySiteUrl);
  final totals = OsBrandPrint.totalsHtml(
    subtotal: OsBrandPrint.moneyHtml(quote.amount),
    discount: OsBrandPrint.moneyHtml(quote.discount),
    tax: OsBrandPrint.moneyHtml(quote.vat),
    grandTotal: OsBrandPrint.moneyHtml(quote.total),
    taxLabel: AppLocaleKeys.osPrintTaxIfAny.tr,
  );

  return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>${escapeHtml(AppLocaleKeys.osPrintQuoteTitle.tr)} — ${escapeHtml(ref)}</title>
<style>
$osPrintA4Css
${OsBrandPrint.brandCss()}
.quote-print.sheet { min-height: 277mm; }
.quote-print .brand-header {
  margin-bottom: 12px;
}
.quote-print .quote-client-col .panel { min-height: 0; }
.quote-print .items-wrap {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  margin: 6px 0;
}
.quote-print table.items {
  font-size: 10px;
  flex: 1;
  height: 100%;
}
.quote-print table.items th { padding: 5px 4px; }
.quote-print table.items td {
  padding: 3px 4px;
  height: auto;
}
${OsLineItemPrintFormat.itemMarketingCss()}
.quote-print .notes-totals { margin-top: 6px; gap: 10px; }
.quote-print .notes-box { min-height: 64px; padding: 6px 8px; }
.quote-print .totals-table td { padding: 5px 8px; }
.quote-print .brand-footer {
  margin-top: 8px;
  padding-top: 8px;
}
.quote-print .brand-footer-top { margin-bottom: 8px; }
.quote-print .qr-block .qr-svg,
.quote-print .qr-block .qr-svg svg {
  width: 56px;
  height: 56px;
}
.quote-print .sign-agency { margin-bottom: 8px; }
.quote-print .panel { padding: 7px 10px; }
.quote-print .meta-row,
.quote-print .client-row {
  margin-bottom: 3px;
  font-size: 10px;
}
.quote-print .brand-header,
.quote-print .quote-top,
.quote-print .notes-totals,
.quote-print .brand-footer {
  flex-shrink: 0;
}
.quote-print .items-wrap { min-height: 0; }
.quote-print .greeting {
  font-size: 10px;
  line-height: 1.5;
  overflow-wrap: break-word;
}
.quote-top {
  direction: ltr;
  display: grid;
  grid-template-columns: minmax(0, 1.05fr) minmax(0, 0.95fr);
  gap: 14px;
  align-items: start;
  margin-bottom: 4px;
}
.quote-client-col, .quote-meta-col {
  direction: rtl;
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}
.quote-meta-col .doc-title,
.quote-meta-col .doc-title-en { text-align: right; }
.quote-print .doc-title { font-size: 28px; }
.quote-meta-col .val.ltr { direction: ltr; unicode-bidi: isolate; }
.quote-meta-col .val.rtl-val { direction: rtl; }
.greeting { margin: 0; }
</style>
</head>
<body>
'''
      '${osPrintTwoCopies(sheetClass: 'quote-print', innerHtml: '''
    ${OsBrandPrint.headerHtml()}
    <div class="content-layer">
      <div class="quote-top no-split">
        <div class="quote-client-col">
          <div class="panel">
            <div class="client-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintQuoteTo.tr)} :</span><span class="val">${escapeHtml(clientName)}</span></div>
            <div class="client-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintClientAddress.tr)} :</span><span class="val">${escapeHtml(address)}</span></div>
            <div class="client-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintClientPhone.tr)} :</span><span class="val ltr">${escapeHtml(phone)}</span></div>
            <div class="client-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintClientEmail.tr)} :</span><span class="val">${escapeHtml(email)}</span></div>
          </div>
          <div class="greeting">${escapeHtml(AppLocaleKeys.osPrintQuoteGreeting.tr)}</div>
        </div>
        <div class="quote-meta-col">
          <div>
            <h1 class="doc-title">${escapeHtml(AppLocaleKeys.osPrintQuoteAr.tr)}</h1>
            <div class="doc-title-en">QUOTATION</div>
          </div>
          <div class="panel">
            <div class="meta-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintQuoteNo.tr)} :</span><span class="val ltr">${escapeHtml(ref)}</span></div>
            <div class="meta-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintDate.tr)} :</span><span class="val ltr">${escapeHtml(quote.date)}</span></div>
            <div class="meta-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintQuoteValidityLabel.tr)} :</span><span class="val rtl-val">${escapeHtml(validity)}</span></div>
          </div>
        </div>
      </div>

      <div class="items-wrap">
        <table class="items quote">
          <colgroup>
            <col class="col-n"/><col class="col-desc"/><col class="col-total"/>
          </colgroup>
          <thead>
            <tr>
              <th>${escapeHtml(AppLocaleKeys.osPrintColIndex.tr)}</th>
              <th>${escapeHtml(AppLocaleKeys.osPrintColDesc.tr)}</th>
              <th>${escapeHtml(AppLocaleKeys.osPrintColTotalPrice.tr)}</th>
            </tr>
          </thead>
          <tbody>
            ${padded.join('\n')}
          </tbody>
        </table>
      </div>

      <div class="notes-totals no-split">
        <div class="notes-box">
          <h4>${escapeHtml(AppLocaleKeys.osPrintNotes.tr)}:</h4>
          $notesHtml
        </div>
        $totals
      </div>

      ${OsBrandPrint.quotationFooterHtml(qrSvg: qr)}
    </div>
''')}'
      '''
</body>
</html>
''';
}
