import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/Models/Os/os_expense_constants.dart';
import 'package:web/web.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

Future<void> printOsExpensesSheet({
  required List<OsDailyExpenseModel> expenses,
  required String Function(OsDailyExpenseModel) categoryLabel,
  required String Function(OsDailyExpenseModel) amountLabel,
}) async {
  final rows = expenses.map((e) {
    final pay = OsExpensePaymentMethod.labelKey(e.paymentMethod).tr;
    return '<tr>'
        '<td>${_esc(e.date)} ${_esc(e.time)}</td>'
        '<td>${_esc(e.title)}</td>'
        '<td>${_esc(categoryLabel(e))}</td>'
        '<td>${_esc(e.vendor ?? '')}</td>'
        '<td>${_esc(e.paidBy.startsWith('os.') ? e.paidBy.tr : e.paidBy)}</td>'
        '<td>${_esc(pay)}</td>'
        '<td style="text-align:left;font-weight:700">${_esc(amountLabel(e))}</td>'
        '</tr>';
  }).join();

  final html = '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>${_esc(AppLocaleKeys.osExpensesPrintTitle.tr)}</title>
<style>
  body { font-family: Tahoma, Arial, sans-serif; padding: 24px; color: #111; }
  h1 { font-size: 20px; margin: 0 0 16px; }
  table { width: 100%; border-collapse: collapse; font-size: 12px; }
  th, td { border: 1px solid #ccc; padding: 8px; text-align: right; }
  th { background: #f3f4f6; }
</style>
</head>
<body>
  <h1>${_esc(AppLocaleKeys.osExpensesPrintTitle.tr)}</h1>
  <table>
    <thead>
      <tr>
        <th>${_esc(AppLocaleKeys.osExpensesDate.tr)}</th>
        <th>${_esc(AppLocaleKeys.osExpensesTitleField.tr)}</th>
        <th>${_esc(AppLocaleKeys.osExpensesCategory.tr)}</th>
        <th>${_esc(AppLocaleKeys.osExpensesVendor.tr)}</th>
        <th>${_esc(AppLocaleKeys.osExpensesPaidBy.tr)}</th>
        <th>${_esc(AppLocaleKeys.osExpensesPaymentMethod.tr)}</th>
        <th>${_esc(AppLocaleKeys.osExpensesAmount.tr)}</th>
      </tr>
    </thead>
    <tbody>$rows</tbody>
  </table>
</body>
</html>
''';

  final bytes = Uint8List.fromList(utf8.encode(html));
  final blob = Blob(
    <BlobPart>[bytes.toJS].toJS,
    BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = URL.createObjectURL(blob);
  final win = window.open(url, '_blank');
  if (win == null) {
    URL.revokeObjectURL(url);
    return;
  }
  Future<void>.delayed(const Duration(milliseconds: 400), () {
    win.focus();
    win.print();
    URL.revokeObjectURL(url);
  });
}
