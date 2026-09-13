import 'package:get/get.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Models/Os/os_expense_constants.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/Utils/os_arabic_currency.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_print_a4.dart';

String _nationalIdLabel(OsPayslipModel slip) {
  if (!Get.isRegistered<OsPayrollController>()) return '';
  for (final e in Get.find<OsPayrollController>().employees) {
    if (e.id == slip.employeeId) {
      return e.nationalIdNumber?.trim() ?? '';
    }
  }
  return '';
}

String _branchLabel(String? branchId) {
  if (branchId == null || branchId.isEmpty) return AppLocaleKeys.osCommonDash.tr;
  for (final b in osExpenseBranches) {
    if (b.id == branchId) return b.nameKey.tr;
  }
  return branchId;
}

String _hireDateLabel(DateTime? d) {
  if (d == null) return AppLocaleKeys.osCommonDash.tr;
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String osPayslipRef(OsPayslipModel slip) {
  final d = slip.displayNumber?.trim() ?? '';
  final uuid = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );
  if (d.startsWith('SLIP-') && !uuid.hasMatch(d)) return d;
  return 'SLIP-${slip.period}-${OsFinanceFormat.shortRef(slip.employeeId)}';
}

String buildOsPayslipPlainText(OsPayslipModel slip) {
  final ref = osPayslipRef(slip);
  final nationalId = _nationalIdLabel(slip);
  final nationalIdLine = nationalId.isEmpty
      ? ''
      : '${AppLocaleKeys.employeesNationalIdNumber.tr}: $nationalId\n';
  return '''
${AppLocaleKeys.osPayslipsAgency.tr}
${AppLocaleKeys.osPayslipsDept.tr}
========================================
${AppLocaleKeys.osPayslipsRef.tr}: $ref
${AppLocaleKeys.osPayslipsDate.tr}: ${slip.period}
----------------------------------------
${AppLocaleKeys.osPayslipsEmployee.tr}: ${slip.employeeName}
${AppLocaleKeys.osPayslipsJobTitle.tr}: ${slip.jobTitle ?? AppLocaleKeys.osCommonDash.tr}
$nationalIdLine${AppLocaleKeys.osPayslipsBranch.tr}: ${_branchLabel(slip.branchId)}
${AppLocaleKeys.osPayslipsHireDate.tr}: ${_hireDateLabel(slip.hireDate)}
----------------------------------------
${AppLocaleKeys.osPayslipsEarnings.tr}
${AppLocaleKeys.osPayslipsBasic.tr}: ${OsFinanceFormat.money(slip.basicSalary)}
${AppLocaleKeys.osPayslipsAllowances.tr}: ${OsFinanceFormat.money(slip.allowances)}
${AppLocaleKeys.osPayslipsTotalEarnings.tr}: ${OsFinanceFormat.money(slip.totalEarnings)}
----------------------------------------
${AppLocaleKeys.osPayslipsDeductions.tr}
${AppLocaleKeys.osPayslipsPenalties.tr}: ${OsFinanceFormat.money(slip.deductions)}
${AppLocaleKeys.osPayslipsSocial.tr}: ${OsFinanceFormat.money(slip.socialSecurity)}
${AppLocaleKeys.osPayslipsAdvance.tr}: ${OsFinanceFormat.money(slip.advanceDeduction)}
${AppLocaleKeys.osPayslipsTotalDeductions.tr}: ${OsFinanceFormat.money(slip.totalDeductions)}
----------------------------------------
${AppLocaleKeys.osPayslipsNet.tr}: ${OsFinanceFormat.money(slip.netPay)}
${OsArabicCurrency.formatIqd(slip.netPay)} ${AppLocaleKeys.osPayslipsNetSuffix.tr}
${slip.isPaid ? AppLocaleKeys.osPayslipsStatusPaid.tr : AppLocaleKeys.osPayslipsStatusPending.tr}
========================================
'''.trim();
}

String buildOsPayslipPrintHtml(OsPayslipModel slip) {
  final ref = osPayslipRef(slip);
  final statusLabel = slip.isPaid
      ? AppLocaleKeys.osPayslipsStatusPaid.tr
      : AppLocaleKeys.osPayslipsStatusPending.tr;
  final job = slip.jobTitle?.trim().isNotEmpty == true
      ? slip.jobTitle!
      : AppLocaleKeys.osCommonDash.tr;
  final today = DateTime.now();
  final dateStr =
      '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';

  var stampBlock = '';
  if (Get.isRegistered<OsStampSettingsController>()) {
    final stamp = Get.find<OsStampSettingsController>();
    if (stamp.stampEnabled.value) {
      final hex =
          '#${stamp.stampColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      stampBlock = '''
<div class="stamp" style="border-color:$hex;color:$hex">
  <div class="stamp-cert">${escapeHtml(AppLocaleKeys.osVouchersStampCertified.tr)}</div>
  <div class="stamp-text">${escapeHtml(stamp.stampText.value)}</div>
  <div class="stamp-ref">REF: ${escapeHtml(ref)}</div>
</div>''';
    }
  }

  String line(String label, String amount) => '''
<div class="line">
  <span>${escapeHtml(label)}</span>
  <span class="amt">${escapeHtml(amount)}</span>
</div>''';

  return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>${escapeHtml(AppLocaleKeys.osPayslipsTitle.tr)} — ${escapeHtml(ref)}</title>
<style>
$osPrintA4Css
:root {
  --brand: #514091;
  --brand-dark: #1f1957;
  --success: #2E7D32;
  --danger: #C62828;
  --muted: #64748b;
  --line: #e2e8f0;
  --fill: #f8fafc;
}
body { padding: 0; background: #fff; }
.sheet {
  width: 186mm;
  min-height: 273mm;
  margin: 0 auto;
  padding: 12mm 10mm;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
  border-bottom: 1px solid var(--line);
  padding-bottom: 12px;
}
.agency { font-size: 16px; font-weight: 900; margin: 0 0 4px; color: var(--brand-dark); }
.dept { font-size: 11px; color: var(--muted); margin: 0; }
.meta { text-align: left; font-size: 11px; color: var(--muted); font-family: 'Almarai', sans-serif; line-height: 1.7; }
.info {
  background: var(--fill);
  border-radius: 12px;
  padding: 12px 14px;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px 20px;
}
.info .k { display: block; font-size: 10px; font-weight: 700; color: var(--muted); }
.info .v { display: block; font-size: 12px; font-weight: 800; }
.cols {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 22px;
  flex: 1;
}
.col h3 {
  margin: 0 0 10px;
  padding-bottom: 8px;
  font-size: 12px;
  font-weight: 800;
  border-bottom: 1px solid var(--line);
}
.col.earn h3 { color: var(--success); border-color: #c8e6c9; }
.col.ded h3 { color: var(--danger); border-color: #ffcdd2; }
.line {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  font-size: 12px;
  color: #475569;
  margin-bottom: 8px;
}
.line .amt { font-weight: 800; color: #1e293b; white-space: nowrap; }
.line.total {
  margin-top: 8px;
  padding-top: 8px;
  border-top: 1px dashed var(--line);
  font-weight: 800;
}
.col.earn .line.total { color: var(--success); }
.col.ded .line.total { color: var(--danger); }
.col.earn .line.total .amt,
.col.ded .line.total .amt { color: inherit; }
.footer {
  margin-top: auto;
  background: #f4f1fb;
  border: 1px solid #d9d2ef;
  border-radius: 14px;
  padding: 12px 14px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
}
.net-k { font-size: 10px; font-weight: 800; color: var(--brand); margin: 0 0 4px; }
.net-v { font-size: 15px; font-weight: 900; color: var(--brand); margin: 0; }
.badge {
  background: #fff;
  border: 1px solid #d9d2ef;
  color: var(--brand);
  border-radius: 10px;
  padding: 6px 12px;
  font-size: 11px;
  font-weight: 800;
  white-space: nowrap;
}
.stamp-wrap { margin-top: 18px; text-align: left; }
.stamp {
  display: inline-block;
  border: 3px double;
  border-radius: 8px;
  padding: 6px 10px;
  text-align: center;
  transform: rotate(-8deg);
}
.stamp-cert { font-size: 9px; font-weight: 700; }
.stamp-text { font-size: 12px; font-weight: 900; }
.stamp-ref { font-size: 9px; }
@media print {
  body { padding: 0 !important; }
  .sheet {
    width: 100%;
    min-height: auto;
    padding: 0;
  }
}
</style>
</head>
<body>
<div class="a4 sheet no-split">
  <div class="header">
    <div>
      <p class="agency">${escapeHtml(AppLocaleKeys.osPayslipsAgency.tr)}</p>
      <p class="dept">${escapeHtml(AppLocaleKeys.osPayslipsDept.tr)}</p>
    </div>
    <div class="meta">
      <div>${escapeHtml(AppLocaleKeys.osPayslipsDate.tr)}: ${escapeHtml(dateStr)}</div>
      <div>${escapeHtml(AppLocaleKeys.osPayslipsRef.tr)}: ${escapeHtml(ref)}</div>
    </div>
  </div>
  <div class="info">
    <div>
      <span class="k">${escapeHtml(AppLocaleKeys.osPayslipsEmployee.tr)}</span>
      <span class="v">${escapeHtml(slip.employeeName)}</span>
    </div>
    <div>
      <span class="k">${escapeHtml(AppLocaleKeys.osPayslipsJobTitle.tr)}</span>
      <span class="v">${escapeHtml(job)}</span>
    </div>
    ${_nationalIdLabel(slip).isEmpty ? '' : '''
    <div>
      <span class="k">${escapeHtml(AppLocaleKeys.employeesNationalIdNumber.tr)}</span>
      <span class="v">${escapeHtml(_nationalIdLabel(slip))}</span>
    </div>'''}
    <div>
      <span class="k">${escapeHtml(AppLocaleKeys.osPayslipsBranch.tr)}</span>
      <span class="v">${escapeHtml(_branchLabel(slip.branchId))}</span>
    </div>
    <div>
      <span class="k">${escapeHtml(AppLocaleKeys.osPayslipsHireDate.tr)}</span>
      <span class="v">${escapeHtml(_hireDateLabel(slip.hireDate))}</span>
    </div>
  </div>
  <div class="cols">
    <div class="col earn">
      <h3>${escapeHtml(AppLocaleKeys.osPayslipsEarnings.tr)}</h3>
      ${line(AppLocaleKeys.osPayslipsBasic.tr, OsFinanceFormat.money(slip.basicSalary))}
      ${line(AppLocaleKeys.osPayslipsAllowances.tr, OsFinanceFormat.money(slip.allowances))}
      <div class="line total">
        <span>${escapeHtml(AppLocaleKeys.osPayslipsTotalEarnings.tr)}</span>
        <span class="amt">${escapeHtml(OsFinanceFormat.money(slip.totalEarnings))}</span>
      </div>
    </div>
    <div class="col ded">
      <h3>${escapeHtml(AppLocaleKeys.osPayslipsDeductions.tr)}</h3>
      ${line(AppLocaleKeys.osPayslipsPenalties.tr, OsFinanceFormat.money(slip.deductions))}
      ${line(AppLocaleKeys.osPayslipsSocial.tr, OsFinanceFormat.money(slip.socialSecurity))}
      ${line(AppLocaleKeys.osPayslipsAdvance.tr, OsFinanceFormat.money(slip.advanceDeduction))}
      <div class="line total">
        <span>${escapeHtml(AppLocaleKeys.osPayslipsTotalDeductions.tr)}</span>
        <span class="amt">${escapeHtml(OsFinanceFormat.money(slip.totalDeductions))}</span>
      </div>
    </div>
  </div>
  <div class="footer">
    <div>
      <p class="net-k">${escapeHtml(AppLocaleKeys.osPayslipsNetTransferred.tr)}</p>
      <p class="net-v">${escapeHtml(OsFinanceFormat.money(slip.netPay))} ${escapeHtml(AppLocaleKeys.osPayslipsNetSuffix.tr)}</p>
    </div>
    <span class="badge">${escapeHtml(statusLabel)}</span>
  </div>
  <div class="stamp-wrap">$stampBlock</div>
</div>
</body>
</html>
''';
}
