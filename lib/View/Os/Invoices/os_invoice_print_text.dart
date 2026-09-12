import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_print_a4.dart';

String buildOsInvoicePlainText(OsInvoiceModel invoice) {
  final ref = OsFinanceFormat.invoiceRef(invoice);
  final buf = StringBuffer()
    ..writeln(AppLocaleKeys.osInvoicesAgencyHeader.tr)
    ..writeln('${AppLocaleKeys.osInvoicesNumber.tr}: $ref')
    ..writeln('${AppLocaleKeys.osInvoicesClient.tr}: ${invoice.clientName}')
    ..writeln('${AppLocaleKeys.osInvoicesDate.tr}: ${invoice.date}')
    ..writeln('${AppLocaleKeys.osInvoicesDueDate.tr}: ${invoice.dueDate}')
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
        '${i + 1}. ${it.description} × ${it.quantity} @ '
        '${OsFinanceFormat.money(it.unitPrice)} = '
        '${OsFinanceFormat.money(it.total)}',
      );
    }
  }

  buf
    ..writeln('---')
    ..writeln(
      '${AppLocaleKeys.osInvoicesAmount.tr}: ${OsFinanceFormat.money(invoice.amount)}',
    );
  if (invoice.vat > 0) {
    buf.writeln(
      '${AppLocaleKeys.osInvoicesVat.tr}: ${OsFinanceFormat.money(invoice.vat)}',
    );
  }
  buf.writeln(
    '${AppLocaleKeys.osInvoicesTotal.tr}: ${OsFinanceFormat.money(invoice.total)}',
  );

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
  final agency = escapeHtml(AppLocaleKeys.osInvoicesAgencyHeader.tr);
  final rows = <String>[];
  if (invoice.items.isEmpty) {
    final amt = invoice.amount > 0 ? invoice.amount : invoice.total;
    rows.add(
      '<tr><td>1</td><td>${escapeHtml(AppLocaleKeys.osInvoicesItemsFallback.tr)}</td>'
      '<td style="text-align:center">1</td>'
      '<td>${escapeHtml(OsFinanceFormat.money(amt))}</td>'
      '<td>${escapeHtml(OsFinanceFormat.money(amt))}</td></tr>',
    );
  } else {
    for (var i = 0; i < invoice.items.length; i++) {
      final it = invoice.items[i];
      rows.add(
        '<tr><td>${i + 1}</td><td>${escapeHtml(it.description)}</td>'
        '<td style="text-align:center">${it.quantity}</td>'
        '<td>${escapeHtml(OsFinanceFormat.money(it.unitPrice))}</td>'
        '<td>${escapeHtml(OsFinanceFormat.money(it.total))}</td></tr>',
      );
    }
  }

  var stampBlock = '';
  if (Get.isRegistered<OsStampSettingsController>()) {
    final stamp = Get.find<OsStampSettingsController>();
    if (stamp.stampEnabled.value) {
      final hex =
          '#${stamp.stampColor.toARGB32().toRadixString(16).substring(2)}';
      stampBlock =
          '<div class="stamp no-split" style="border-color:$hex;color:$hex">'
          '${escapeHtml(stamp.stampText.value)}</div>';
    }
  }

  final vatRow = invoice.vat > 0
      ? '<div>${escapeHtml(AppLocaleKeys.osInvoicesVat.tr)}: '
          '${escapeHtml(OsFinanceFormat.money(invoice.vat))}</div>'
      : '';

  return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>$agency — ${escapeHtml(ref)}</title>
<style>
$osPrintA4Css
body { padding: 16px; }
h1 { font-size: 18px; margin: 0 0 4px; }
.meta {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin: 16px 0;
  font-size: 13px;
}
table { margin: 16px 0; font-size: 12px; }
th, td { border: 1px solid #cbd5e1; padding: 8px; text-align: right; }
th { background: #f1f5f9; }
.totals { margin-top: 12px; font-size: 13px; }
.grand { font-size: 16px; font-weight: 800; color: #4f46e5; margin-top: 6px; }
.stamp {
  display: inline-block;
  margin-top: 20px;
  border: 2px solid;
  padding: 10px 18px;
  border-radius: 12px;
  font-weight: 800;
  transform: rotate(2deg);
}
</style>
</head>
<body>
  <div class="a4">
    <h1>$agency</h1>
    <div>${escapeHtml(AppLocaleKeys.osInvoicesNumber.tr)}: <strong>${escapeHtml(ref)}</strong></div>
    <div class="meta">
      <div>${escapeHtml(AppLocaleKeys.osInvoicesClient.tr)}: <strong>${escapeHtml(invoice.clientName)}</strong></div>
      <div>${escapeHtml(AppLocaleKeys.osInvoicesStatus.tr)}: ${escapeHtml(OsFinanceFormat.invoiceStatusLabel(invoice.status))}</div>
      <div>${escapeHtml(AppLocaleKeys.osInvoicesDate.tr)}: ${escapeHtml(invoice.date)}</div>
      <div>${escapeHtml(AppLocaleKeys.osInvoicesDueDate.tr)}: ${escapeHtml(invoice.dueDate)}</div>
    </div>
    <table>
      <thead>
        <tr>
          <th>#</th>
          <th>${escapeHtml(AppLocaleKeys.osInvoicesItemDesc.tr)}</th>
          <th>${escapeHtml(AppLocaleKeys.osInvoicesQty.tr)}</th>
          <th>${escapeHtml(AppLocaleKeys.osInvoicesUnitPrice.tr)}</th>
          <th>${escapeHtml(AppLocaleKeys.osInvoicesLineTotal.tr)}</th>
        </tr>
      </thead>
      <tbody>
        ${rows.join('\n')}
      </tbody>
    </table>
    <div class="totals no-split">
      <div>${escapeHtml(AppLocaleKeys.osInvoicesAmount.tr)}: ${escapeHtml(OsFinanceFormat.money(invoice.amount))}</div>
      $vatRow
      <div class="grand">${escapeHtml(AppLocaleKeys.osInvoicesTotal.tr)}: ${escapeHtml(OsFinanceFormat.money(invoice.total))}</div>
    </div>
    $stampBlock
  </div>
</body>
</html>
''';
}
