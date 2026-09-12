import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/Models/Os/os_expense_constants.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_print_a4.dart';
import 'package:point/View/Os/os_print_document.dart';

/// Builds and opens the point_os-style daily expenses A4 print sheet (web).
Future<void> printOsExpensesSheet({
  required List<OsDailyExpenseModel> expenses,
  required String Function(OsDailyExpenseModel) categoryLabel,
  required String Function(OsDailyExpenseModel) amountLabel,
}) {
  return openOsPrintDocument(
    html: buildOsExpensesPrintHtml(
      expenses: expenses,
      categoryLabel: categoryLabel,
      amountLabel: amountLabel,
    ),
    titleKey: AppLocaleKeys.osExpensesPrint,
    fallbackKey: AppLocaleKeys.osExpensesPrintFallback,
  );
}

String buildOsExpensesPrintHtml({
  required List<OsDailyExpenseModel> expenses,
  required String Function(OsDailyExpenseModel) categoryLabel,
  required String Function(OsDailyExpenseModel) amountLabel,
}) {
  final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
  final printDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final agency = escapeHtml(AppLocaleKeys.osInvoicesAgencyHeader.tr);
  final subtitle = escapeHtml(AppLocaleKeys.osExpensesPrintSubtitle.tr);
  final dateLine = escapeHtml(
    AppLocaleKeys.osExpensesPrintDate.trParams({'date': printDate}),
  );
  final countLine = escapeHtml(
    AppLocaleKeys.osExpensesPrintCount.trParams({
      'count': '${expenses.length}',
    }),
  );

  final rows = <String>[];
  for (var i = 0; i < expenses.length; i++) {
    final e = expenses[i];
    final paidBy =
        e.paidBy.startsWith('os.') ? e.paidBy.tr : e.paidBy;
    final pay = OsExpensePaymentMethod.labelKey(e.paymentMethod).tr;
    final receiptNo = _receiptCell(e);
    final dateTime = e.time.isEmpty ? e.date : '${e.date} ${e.time}';
    rows.add(
      '<tr>'
      '<td class="idx">${i + 1}</td>'
      '<td>${escapeHtml(dateTime)}</td>'
      '<td>${escapeHtml(e.title)}</td>'
      '<td>${escapeHtml(categoryLabel(e))}</td>'
      '<td>${escapeHtml(e.vendor?.trim().isNotEmpty == true ? e.vendor! : AppLocaleKeys.osCommonDash.tr)}</td>'
      '<td>${escapeHtml(paidBy)}</td>'
      '<td>${escapeHtml(receiptNo)}</td>'
      '<td>${escapeHtml(pay)}</td>'
      '<td class="amt">${escapeHtml(amountLabel(e))}</td>'
      '</tr>',
    );
  }

  return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>${escapeHtml(AppLocaleKeys.osExpensesPrintTitle.tr)}</title>
<style>
$osPrintA4Css
body { padding: 0; }
.header {
  border-bottom: 2px solid #4f46e5;
  padding-bottom: 12px;
  margin-bottom: 16px;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
}
.logo { font-size: 18px; font-weight: 800; color: #4338ca; margin: 0; }
.sub { margin: 4px 0 0; font-size: 11px; color: #64748b; }
.meta { text-align: left; font-size: 11px; color: #64748b; line-height: 1.6; }
table { margin-top: 8px; font-size: 11px; }
th {
  background: #f1f5f9;
  padding: 8px 6px;
  border: 1px solid #cbd5e1;
  text-align: right;
  font-weight: 700;
}
td {
  padding: 6px;
  border: 1px solid #cbd5e1;
  text-align: right;
  vertical-align: top;
}
td.idx { width: 28px; text-align: center; }
td.amt, th.amt { text-align: left; font-weight: 700; }
.col-idx { width: 5%; }
.col-date { width: 11%; }
.col-title { width: 18%; }
.col-cat { width: 12%; }
.col-vendor { width: 12%; }
.col-paid { width: 10%; }
.col-receipt { width: 10%; }
.col-pay { width: 10%; }
.col-amt { width: 12%; }
.total-row { background: #f8fafc; font-weight: 700; font-size: 12px; }
.total-row .amt { font-size: 14px; color: #15803d; }
.signatures {
  margin-top: 40px;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  text-align: center;
  gap: 20px;
}
.sig-box {
  border-top: 1px dashed #94a3b8;
  padding-top: 10px;
  font-size: 11px;
  color: #475569;
  font-weight: 600;
}
</style>
</head>
<body>
  <div class="a4">
    <div class="header">
      <div>
        <p class="logo">$agency</p>
        <p class="sub">$subtitle</p>
      </div>
      <div class="meta">
        <div>$dateLine</div>
        <div>$countLine</div>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th class="col-idx">${escapeHtml(AppLocaleKeys.osExpensesPrintIndex.tr)}</th>
          <th class="col-date">${escapeHtml(AppLocaleKeys.osExpensesDate.tr)}</th>
          <th class="col-title">${escapeHtml(AppLocaleKeys.osExpensesColStatement.tr)}</th>
          <th class="col-cat">${escapeHtml(AppLocaleKeys.osExpensesCategory.tr)}</th>
          <th class="col-vendor">${escapeHtml(AppLocaleKeys.osExpensesColVendor.tr)}</th>
          <th class="col-paid">${escapeHtml(AppLocaleKeys.osExpensesColResponsible.tr)}</th>
          <th class="col-receipt">${escapeHtml(AppLocaleKeys.osExpensesPrintReceiptNo.tr)}</th>
          <th class="col-pay">${escapeHtml(AppLocaleKeys.osExpensesPaymentMethod.tr)}</th>
          <th class="col-amt amt">${escapeHtml(AppLocaleKeys.osExpensesAmount.tr)}</th>
        </tr>
      </thead>
      <tbody>
        ${rows.join('\n')}
        <tr class="total-row no-split">
          <td colspan="8" style="text-align:left;padding:10px 8px">
            ${escapeHtml(AppLocaleKeys.osExpensesPrintTotal.tr)}
          </td>
          <td class="amt">${escapeHtml(OsFinanceFormat.money(total))}</td>
        </tr>
      </tbody>
    </table>

    <div class="signatures no-split">
      <div class="sig-box">${escapeHtml(AppLocaleKeys.osExpensesPrintSignCashier.tr)}</div>
      <div class="sig-box">${escapeHtml(AppLocaleKeys.osExpensesPrintSignAccountant.tr)}</div>
      <div class="sig-box">${escapeHtml(AppLocaleKeys.osExpensesPrintSignManagement.tr)}</div>
    </div>
  </div>
</body>
</html>
''';
}

String _receiptCell(OsDailyExpenseModel e) {
  final no = e.receiptNumber?.trim();
  if (no != null && no.isNotEmpty) return no;
  if (e.hasReceipt) return AppLocaleKeys.osExpensesPrintReceiptAttached.tr;
  return AppLocaleKeys.osCommonDash.tr;
}
