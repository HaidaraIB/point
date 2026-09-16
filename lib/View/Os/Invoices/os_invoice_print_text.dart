import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/Print/os_brand_print.dart';
import 'package:point/View/Os/Print/os_print_codes.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_line_item_print_format.dart';
import 'package:point/View/Os/os_print_a4.dart';

String buildOsInvoicePlainText(OsInvoiceModel invoice) {
  final ref = OsFinanceFormat.invoiceRef(invoice);
  final buf = StringBuffer()
    ..writeln(AppLocaleKeys.osPrintAgencyAr.tr)
    ..writeln('${AppLocaleKeys.osInvoicesNumber.tr}: $ref')
    ..writeln('${AppLocaleKeys.osInvoicesClient.tr}: ${invoice.clientName}')
    ..writeln('${AppLocaleKeys.osInvoicesDate.tr}: ${invoice.date}')
    ..writeln('${AppLocaleKeys.osInvoicesDueDate.tr}: ${invoice.dueDate}')
    ..writeln(
      '${AppLocaleKeys.osPrintPaymentMethod.tr}: '
      '${OsFinanceFormat.paymentMethodLabel(invoice.paymentMethod)}',
    )
    ..writeln(
      '${AppLocaleKeys.osInvoicesStatus.tr}: '
      '${OsFinanceFormat.invoiceStatusLabel(invoice.status)}',
    )
    ..writeln('---');

  if (invoice.items.isEmpty) {
    buf.writeln(
      '1. ${AppLocaleKeys.osInvoicesItemsFallback.tr} — '
      '${OsFinanceFormat.money(invoice.amount > 0 ? invoice.amount : invoice.total)}',
    );
  } else {
    for (var i = 0; i < invoice.items.length; i++) {
      final it = invoice.items[i];
      buf.writeln(
        '${i + 1}. ${OsLineItemPrintFormat.plainDescription(it)} × '
        '${it.quantity} @ '
        '${OsFinanceFormat.money(it.unitPrice)} = '
        '${OsFinanceFormat.money(it.total)}',
      );
    }
  }

  buf
    ..writeln('---')
    ..writeln(
      '${AppLocaleKeys.osPrintSubtotal.tr}: ${OsFinanceFormat.money(invoice.amount)}',
    );
  if (invoice.discount > 0) {
    buf.writeln(
      '${AppLocaleKeys.osPrintDiscount.tr}: ${OsFinanceFormat.money(invoice.discount)}',
    );
  }
  if (invoice.vat > 0) {
    buf.writeln(
      '${AppLocaleKeys.osInvoicesVat.tr}: ${OsFinanceFormat.money(invoice.vat)}',
    );
  }
  buf.writeln(
    '${AppLocaleKeys.osInvoicesTotal.tr}: ${OsFinanceFormat.money(invoice.total)}',
  );
  final notes = invoice.notes?.trim() ?? '';
  if (notes.isNotEmpty) {
    buf
      ..writeln('---')
      ..writeln('${AppLocaleKeys.osPrintNotes.tr}: $notes');
  }

  if (Get.isRegistered<OsStampSettingsController>()) {
    final stamp = Get.find<OsStampSettingsController>();
    if (stamp.stampEnabled.value) {
      buf
        ..writeln('---')
        ..writeln(stamp.stampText.value);
    }
  }

  return buf.toString();
}

String buildOsInvoicePrintHtml(OsInvoiceModel invoice) {
  final ref = OsFinanceFormat.invoiceRef(invoice);
  final title = escapeHtml(AppLocaleKeys.osPrintInvoiceTitle.tr);

  final rows = <String>[];
  if (invoice.items.isEmpty) {
    final amt = invoice.amount > 0 ? invoice.amount : invoice.total;
    rows.add(
      '<tr>'
      '<td>1</td>'
      '<td class="desc">${escapeHtml(AppLocaleKeys.osInvoicesItemsFallback.tr)}</td>'
      '<td>${OsBrandPrint.moneyHtml(amt)}</td>'
      '<td>${OsBrandPrint.moneyHtml(amt)}</td>'
      '</tr>',
    );
  } else {
    for (var i = 0; i < invoice.items.length; i++) {
      final it = invoice.items[i];
      rows.add(
        '<tr>'
        '<td>${i + 1}</td>'
        '${OsLineItemPrintFormat.descHtml(it)}'
        '<td>${OsBrandPrint.moneyHtml(it.unitPrice)}</td>'
        '<td>${OsBrandPrint.moneyHtml(it.total)}</td>'
        '</tr>',
      );
    }
  }
  final padded = OsBrandPrint.padItemRows(rows, columnCount: 4);

  final phone = invoice.clientPhone?.trim() ?? '';
  final email = invoice.clientEmail?.trim() ?? '';
  final address = invoice.clientAddress?.trim() ?? '';
  final taxNo = invoice.clientTaxNumber?.trim() ?? '';
  final notes = invoice.notes?.trim() ?? '';
  final payLabel =
      OsFinanceFormat.paymentMethodLabel(invoice.paymentMethod);

  final qrData = osInvoicePaymentLink(invoice);
  final qr = OsPrintCodes.qrSvg(qrData);
  final barcode = OsPrintCodes.code128Svg(ref);

  final totals = OsBrandPrint.totalsHtml(
    subtotal: OsBrandPrint.moneyHtml(invoice.amount),
    discount: OsBrandPrint.moneyHtml(invoice.discount),
    tax: OsBrandPrint.moneyHtml(invoice.vat),
    grandTotal: OsBrandPrint.moneyHtml(invoice.total),
    taxLabel: AppLocaleKeys.osPrintTaxVat.tr,
  );

  final services = '''
<div class="invoice-services">
  <span class="svc"><span class="svc-ar">${escapeHtml(AppLocaleKeys.osPrintSvcSolutionsAr.tr)}</span><span class="svc-en">Digital Solutions</span></span>
  <span class="svc"><span class="svc-ar">${escapeHtml(AppLocaleKeys.osPrintSvcCreativeAr.tr)}</span><span class="svc-en">Creative Consulting</span></span>
  <span class="svc"><span class="svc-ar">${escapeHtml(AppLocaleKeys.osPrintSvcFilmAr.tr)}</span><span class="svc-en">Film Production</span></span>
  <span class="svc"><span class="svc-ar">${escapeHtml(AppLocaleKeys.osPrintSvcDigitalAr.tr)}</span><span class="svc-en">Digital Marketing</span></span>
</div>''';

  return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>$title — ${escapeHtml(ref)}</title>
<style>
$osPrintA4Css
${OsBrandPrint.brandCss()}
.invoice-print .brand-header {
  grid-template-columns: 2.17fr 1.76fr;
  column-gap: 0;
  align-items: stretch;
  margin-bottom: 4px;
}
.invoice-print .brand-primary-col {
  display: flex;
  flex-direction: column;
  min-width: 0;
}
.invoice-print .brand-lockup {
  width: 100%;
  overflow: visible;
}
.invoice-print .brand-lockup .brand-comp {
  display: block;
  width: 100%;
  max-width: 100%;
  height: auto;
  object-fit: fill;
}
.invoice-print .brand-header-end {
  align-self: stretch;
}
.invoice-print .brand-comp-info {
  margin: 0;
  padding: 0 6px;
}
.invoice-print .brand-comp-slogan {
  object-position: right center;
  height: auto;
  max-height: 32mm;
  width: auto;
  justify-self: end;
}
.invoice-services {
  direction: ltr;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  width: 100%;
  margin: 2px 0 0;
  padding: 0;
  color: var(--navy);
  box-sizing: border-box;
}
.invoice-services .svc {
  text-align: center;
  flex: 1 1 0;
  min-width: 0;
  font-size: 7.5px;
  font-weight: 700;
  line-height: 1.25;
  padding: 0 4px;
}
.invoice-services .svc + .svc {
  border-left: 1px solid rgba(43, 42, 107, 0.28);
}
.invoice-services .svc-ar {
  display: block;
  direction: rtl;
  unicode-bidi: isolate;
}
.invoice-services .svc-en {
  display: block;
  margin-top: 1px;
  font-size: 6px;
  font-weight: 500;
  color: var(--muted);
  direction: ltr;
  unicode-bidi: isolate;
}
.invoice-print .doc-title { font-size: 28px; }
.invoice-print .panel { padding: 7px 10px; }
.invoice-print .panel-head { padding: 5px 10px; font-size: 11px; }
.invoice-print .panel-body { padding: 6px 10px; }
.invoice-print .meta-row,
.invoice-print .client-row {
  margin-bottom: 3px;
  font-size: 10px;
}
.invoice-print .items-wrap {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  margin: 6px 0;
}
.invoice-print table.items {
  font-size: 10px;
  flex: 1;
  height: 100%;
}
.invoice-print table.items th { padding: 5px 4px; }
.invoice-print table.items td {
  padding: 3px 4px;
  height: auto;
}
${OsLineItemPrintFormat.itemMarketingCss()}
.invoice-print .notes-totals { margin-top: 6px; gap: 10px; }
.invoice-print .notes-box { min-height: 64px; padding: 6px 8px; }
.invoice-print .totals-table td { padding: 5px 8px; }
.invoice-print .title-meta {
  margin-bottom: 8px;
  gap: 12px;
}
.invoice-print .invoice-heading .doc-title-en {
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 5px;
  margin-top: 4px;
}
.invoice-print .brand-footer {
  page-break-inside: auto;
  break-inside: auto;
  margin-top: 8px;
  padding-top: 8px;
}
.invoice-print.sheet {
  min-height: 277mm;
}
.invoice-print .qr-block .qr-svg,
.invoice-print .qr-block .qr-svg svg {
  width: 56px;
  height: 56px;
}
.invoice-print .sign-block .sign-agency { margin-bottom: 8px; }
.invoice-print .sign-block .sign-agency-name { margin-bottom: 12px; }
.invoice-heading {
  text-align: right;
  margin-bottom: 8px;
}
.invoice-heading .doc-title,
.invoice-heading .doc-title-en { text-align: right; }
.title-meta {
  direction: ltr;
  display: grid;
  grid-template-columns: 0.85fr 1.15fr;
  gap: 14px;
  align-items: stretch;
  margin-bottom: 12px;
}
.invoice-heading .doc-title-en {
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 5px;
  margin-top: 4px;
}
.invoice-meta {
  direction: rtl;
}
.invoice-meta .meta-row {
  justify-content: space-between;
  gap: 12px;
}
.invoice-meta .meta-row .val {
  text-align: left;
  direction: ltr;
  unicode-bidi: isolate;
  flex: 1;
  min-width: 0;
}
.invoice-client {
  direction: rtl;
  margin-bottom: 0;
}
.invoice-client .panel-body {
  direction: rtl;
  text-align: right;
}
.invoice-client .client-row {
  direction: rtl;
  justify-content: flex-start;
  gap: 8px;
}
.invoice-client .client-row .lbl {
  text-align: right;
}
.invoice-client .client-row .val {
  text-align: right;
  direction: rtl;
  unicode-bidi: plaintext;
  flex: 1;
  min-width: 0;
}
.invoice-footer-top {
  direction: ltr;
  display: grid;
  grid-template-columns: 0.7fr 1.1fr 1.6fr;
  gap: 10px;
  align-items: center;
  margin-bottom: 12px;
}
.invoice-barcode {
  text-align: center;
  border-left: 1px solid var(--border);
  padding-left: 12px;
  min-width: 0;
}
.invoice-barcode .bc-svg svg {
  width: 100%;
  max-width: 180px;
  height: 36px;
  display: block;
  margin: 0 auto;
}
.invoice-sign {
  direction: rtl;
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: center;
  gap: 12px;
  min-width: 0;
}
.invoice-sign .sign-block {
  flex: 0 1 auto;
  min-width: 0;
}
.invoice-seal {
  display: block;
  width: 64px;
  height: auto;
  max-width: 100%;
  object-fit: contain;
  flex-shrink: 0;
}
.invoice-footer-top {
  margin-bottom: 8px;
}
@page { size: A4 portrait; margin: 10mm 12mm; }
.footer-bar.invoice-bar {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  gap: 12px;
}
.footer-bar.invoice-bar .ar { justify-self: start; }
.footer-bar.invoice-bar .en { grid-column: 2; justify-self: center; }
</style>
</head>
<body>
'''
      '${osPrintTwoCopies(sheetClass: 'invoice-print', innerHtml: '''
    ${OsBrandPrint.headerHtml(belowBrand: services)}
    ${OsBrandPrint.watermarkHtml()}
    <div class="content-layer">
      <div class="no-split">
        <div class="invoice-heading">
          <h1 class="doc-title">${escapeHtml(AppLocaleKeys.osPrintInvoiceAr.tr)}</h1>
          <div class="doc-title-en">INVOICE</div>
        </div>
        <div class="title-meta">
          <div class="panel invoice-meta">
            <div class="meta-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintInvoiceNo.tr)}</span><span class="val">${escapeHtml(ref)}</span></div>
            <div class="meta-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintDate.tr)}</span><span class="val">${escapeHtml(invoice.date)}</span></div>
            <div class="meta-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintDueDate.tr)}</span><span class="val">${escapeHtml(invoice.dueDate)}</span></div>
            <div class="meta-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintPaymentMethod.tr)}</span><span class="val">${escapeHtml(payLabel)}</span></div>
          </div>
          <div class="panel-bordered invoice-client">
            <div class="panel-head">${escapeHtml(AppLocaleKeys.osPrintClientDetails.tr)}</div>
            <div class="panel-body">
              <div class="client-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintClientName.tr)} :</span><span class="val">${escapeHtml(invoice.clientName)}</span></div>
              <div class="client-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintClientPhone.tr)} :</span><span class="val">${escapeHtml(phone)}</span></div>
              <div class="client-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintClientEmail.tr)} :</span><span class="val">${escapeHtml(email)}</span></div>
              <div class="client-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintClientAddress.tr)} :</span><span class="val">${escapeHtml(address)}</span></div>
              <div class="client-row"><span class="lbl">${escapeHtml(AppLocaleKeys.osPrintClientTax.tr)} :</span><span class="val">${escapeHtml(taxNo)}</span></div>
            </div>
          </div>
        </div>
      </div>

      <div class="items-wrap">
        <table class="items">
          <colgroup>
            <col class="col-n"/><col class="col-desc"/><col class="col-price"/><col class="col-total"/>
          </colgroup>
          <thead>
            <tr>
              <th>${escapeHtml(AppLocaleKeys.osPrintColIndex.tr)}</th>
              <th>${escapeHtml(AppLocaleKeys.osPrintColDesc.tr)}</th>
              <th>${escapeHtml(AppLocaleKeys.osPrintColPrice.tr)}</th>
              <th>${escapeHtml(AppLocaleKeys.osPrintColTotal.tr)}</th>
            </tr>
          </thead>
          <tbody>
            ${padded.join('\n')}
          </tbody>
        </table>
      </div>

      <div class="notes-totals no-split">
        <div class="notes-box">
          <h4>${escapeHtml(AppLocaleKeys.osPrintNotes.tr)}</h4>
          <p>${escapeHtml(notes)}</p>
        </div>
        $totals
      </div>

      ${OsBrandPrint.invoiceFooterHtml(qrSvg: qr, barcodeSvg: barcode, documentRef: ref)}
    </div>
''')}'
      '''
</body>
</html>
''';
}
