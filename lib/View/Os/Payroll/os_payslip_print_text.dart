import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Utils/os_arabic_currency.dart';
import 'package:point/View/Os/Print/os_brand_print.dart';
import 'package:point/View/Os/Print/os_print_codes.dart';
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
  if (Get.isRegistered<OsFinanceController>()) {
    final name = Get.find<OsFinanceController>().branchName(branchId);
    if (name.isNotEmpty) return name;
  }
  return branchId;
}

String _hireDateLabel(DateTime? d) {
  if (d == null) return AppLocaleKeys.osCommonDash.tr;
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String _issueDateLabel() {
  final today = DateTime.now();
  return '${today.day.toString().padLeft(2, '0')}/'
      '${today.month.toString().padLeft(2, '0')}/'
      '${today.year}';
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

String _metaCell(String label, String value) {
  return '''
<div class="meta-row">
  <span class="lbl">${escapeHtml(label)}</span>
  <span class="val">${escapeHtml(value)}</span>
</div>''';
}

String _amountLine(String label, String amountHtml) => '''
<div class="ps-line">
  <span>${escapeHtml(label)}</span>
  <span class="amt">$amountHtml</span>
</div>''';

String _osPayslipPrintExtraCss() {
  return '''
.payslip-print.sheet { min-height: 277mm; }
.payslip-print .watermark-logo {
  left: 4%;
  top: 46%;
  transform: translate(0, -50%);
  width: 46%;
  opacity: 0.95;
}
.payslip-print .brand-header { margin-bottom: 8px; }
.payslip-title-row {
  direction: ltr;
  display: grid;
  grid-template-columns: 1.15fr 0.85fr;
  gap: 14px;
  align-items: start;
  margin: 4px 0 12px;
}
.payslip-heading {
  text-align: right;
}
.payslip-heading .doc-title { font-size: 28px; }
.payslip-heading .doc-title-en {
  font-size: 16px;
  font-weight: 700;
  letter-spacing: 5px;
  margin-top: 4px;
}
.payslip-dept {
  margin: 6px 0 0;
  font-size: 10px;
  color: var(--muted);
  font-weight: 600;
  text-align: right;
}
.payslip-meta-col {
  direction: rtl;
}
.payslip-meta-col .panel { padding: 8px 10px; }
.payslip-meta-col .meta-row { font-size: 10px; margin-bottom: 4px; }
.payslip-meta-col .meta-row:last-child { margin-bottom: 0; }
.payslip-employee {
  margin-bottom: 12px;
}
.payslip-employee .panel-body {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px 16px;
}
.payslip-employee .client-row { font-size: 10px; margin-bottom: 0; }
.payslip-cols {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 18px;
  flex: 1;
  margin-bottom: 12px;
}
.ps-col h3 {
  margin: 0 0 8px;
  padding-bottom: 6px;
  font-size: 11px;
  font-weight: 800;
  border-bottom: 1px solid var(--border);
  text-align: right;
}
.ps-col.earn h3 { color: #2E7D32; border-color: #c8e6c9; }
.ps-col.ded h3 { color: #C62828; border-color: #ffcdd2; }
.ps-line {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  font-size: 10px;
  color: var(--muted);
  margin-bottom: 6px;
}
.ps-line .amt { font-weight: 800; color: var(--text); white-space: nowrap; }
.ps-line.total {
  margin-top: 6px;
  padding-top: 6px;
  border-top: 1px dashed var(--border);
  font-weight: 800;
  font-size: 10px;
}
.ps-col.earn .ps-line.total { color: #2E7D32; }
.ps-col.ded .ps-line.total { color: #C62828; }
.ps-col.earn .ps-line.total .amt,
.ps-col.ded .ps-line.total .amt { color: inherit; }
.payslip-net {
  background: var(--navy);
  color: #fff;
  border-radius: 10px;
  padding: 10px 14px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  margin-bottom: 10px;
}
.payslip-net .net-k {
  font-size: 9px;
  font-weight: 700;
  opacity: 0.9;
  margin: 0 0 3px;
}
.payslip-net .net-v {
  font-size: 14px;
  font-weight: 900;
  margin: 0;
}
.payslip-net .net-words {
  font-size: 9px;
  opacity: 0.85;
  margin: 4px 0 0;
  line-height: 1.4;
}
.payslip-net .badge {
  background: rgba(255,255,255,0.12);
  border: 1px solid rgba(255,255,255,0.35);
  border-radius: 8px;
  padding: 5px 10px;
  font-size: 10px;
  font-weight: 800;
  white-space: nowrap;
  flex-shrink: 0;
}
.payslip-print .brand-footer {
  margin-top: auto;
  padding-top: 8px;
}
.payslip-print .voucher-footer-top {
  direction: ltr;
  display: grid;
  grid-template-columns: 1.15fr 0.7fr 1.15fr 0.55fr;
  gap: 8px;
  align-items: end;
  margin-bottom: 14px;
}
.payslip-print .voucher-sign {
  text-align: center;
  padding: 0 10px 6px;
  border-right: 1px solid var(--border);
}
.payslip-print .voucher-sign-line {
  border-bottom: 1.5px solid var(--navy);
  margin: 0 8px 8px;
  height: 28px;
}
.payslip-print .voucher-sign-lbl {
  font-size: 11px;
  font-weight: 700;
  color: var(--navy);
}
.payslip-print .voucher-barcode {
  text-align: center;
  min-width: 0;
}
.payslip-print .voucher-barcode .bc-svg svg {
  width: 100%;
  max-width: 170px;
  height: 36px;
  display: block;
  margin: 0 auto;
}
.payslip-print .qr-block .qr-svg,
.payslip-print .qr-block .qr-svg svg {
  width: 64px;
  height: 64px;
}
.payslip-print .voucher-bar { padding: 8px 22px; }
.payslip-print .voucher-bar .en-wrap {
  display: flex;
  align-items: center;
  gap: 14px;
  flex: 1;
  min-width: 0;
}
.payslip-print .voucher-bar .en {
  font-size: 8px;
  font-weight: 400;
  letter-spacing: 3.6px;
  white-space: nowrap;
}
.payslip-print .voucher-bar .rule {
  display: block;
  width: 72px;
  height: 1px;
  background: rgba(255,255,255,0.85);
  flex-shrink: 0;
}
.payslip-print .voucher-bar .ar {
  font-size: 12px;
  letter-spacing: 1.2px;
}
''';
}

String _osPayslipPrintInnerHtml(
  OsPayslipModel slip, {
  required String ref,
  required String statusLabel,
  required String job,
  required String dateStr,
  required String qr,
  required String barcode,
  bool includeBrandWatermark = true,
}) {
  final nationalId = _nationalIdLabel(slip);
  final netWords = OsArabicCurrency.formatIqd(slip.netPay);

  return '''
      ${includeBrandWatermark ? OsBrandPrint.watermarkHtml() : ''}
      <div class="content-layer">
        ${OsBrandPrint.headerHtml()}
        <div class="payslip-title-row no-split">
          <div class="payslip-heading">
            <h1 class="doc-title">${escapeHtml(AppLocaleKeys.osPrintPayslipAr.tr)}</h1>
            <div class="doc-title-en">${escapeHtml(AppLocaleKeys.osPrintPayslipEn.tr)}</div>
            <p class="payslip-dept">${escapeHtml(AppLocaleKeys.osPayslipsDept.tr)}</p>
          </div>
          <div class="payslip-meta-col">
            <div class="panel">
              ${_metaCell(AppLocaleKeys.osPayslipsRef.tr, ref)}
              ${_metaCell(AppLocaleKeys.osPrintDate.tr, dateStr)}
              ${_metaCell(AppLocaleKeys.osPayslipsDate.tr, slip.period)}
              ${_metaCell(AppLocaleKeys.status.tr, statusLabel)}
            </div>
          </div>
        </div>
        <div class="panel-bordered payslip-employee no-split">
          <div class="panel-head">${escapeHtml(AppLocaleKeys.osPayslipsEmployee.tr)}</div>
          <div class="panel-body">
            <div class="client-row">
              <span class="lbl">${escapeHtml(AppLocaleKeys.osPayslipsEmployee.tr)} :</span>
              <span class="val">${escapeHtml(slip.employeeName)}</span>
            </div>
            <div class="client-row">
              <span class="lbl">${escapeHtml(AppLocaleKeys.osPayslipsJobTitle.tr)} :</span>
              <span class="val">${escapeHtml(job)}</span>
            </div>
            ${nationalId.isEmpty ? '' : '''
            <div class="client-row">
              <span class="lbl">${escapeHtml(AppLocaleKeys.employeesNationalIdNumber.tr)} :</span>
              <span class="val">${escapeHtml(nationalId)}</span>
            </div>'''}
            <div class="client-row">
              <span class="lbl">${escapeHtml(AppLocaleKeys.osPayslipsBranch.tr)} :</span>
              <span class="val">${escapeHtml(_branchLabel(slip.branchId))}</span>
            </div>
            <div class="client-row">
              <span class="lbl">${escapeHtml(AppLocaleKeys.osPayslipsHireDate.tr)} :</span>
              <span class="val">${escapeHtml(_hireDateLabel(slip.hireDate))}</span>
            </div>
          </div>
        </div>
        <div class="payslip-cols no-split">
          <div class="ps-col earn">
            <h3>${escapeHtml(AppLocaleKeys.osPayslipsEarnings.tr)}</h3>
            ${_amountLine(AppLocaleKeys.osPayslipsBasic.tr, OsBrandPrint.moneyHtml(slip.basicSalary))}
            ${_amountLine(AppLocaleKeys.osPayslipsAllowances.tr, OsBrandPrint.moneyHtml(slip.allowances))}
            <div class="ps-line total">
              <span>${escapeHtml(AppLocaleKeys.osPayslipsTotalEarnings.tr)}</span>
              <span class="amt">${OsBrandPrint.moneyHtml(slip.totalEarnings)}</span>
            </div>
          </div>
          <div class="ps-col ded">
            <h3>${escapeHtml(AppLocaleKeys.osPayslipsDeductions.tr)}</h3>
            ${_amountLine(AppLocaleKeys.osPayslipsPenalties.tr, OsBrandPrint.moneyHtml(slip.deductions))}
            ${_amountLine(AppLocaleKeys.osPayslipsSocial.tr, OsBrandPrint.moneyHtml(slip.socialSecurity))}
            ${_amountLine(AppLocaleKeys.osPayslipsAdvance.tr, OsBrandPrint.moneyHtml(slip.advanceDeduction))}
            <div class="ps-line total">
              <span>${escapeHtml(AppLocaleKeys.osPayslipsTotalDeductions.tr)}</span>
              <span class="amt">${OsBrandPrint.moneyHtml(slip.totalDeductions)}</span>
            </div>
          </div>
        </div>
        <div class="payslip-net no-split">
          <div>
            <p class="net-k">${escapeHtml(AppLocaleKeys.osPayslipsNetTransferred.tr)}</p>
            <p class="net-v">${OsBrandPrint.moneyHtml(slip.netPay)}</p>
            <p class="net-words">${escapeHtml(netWords)}</p>
          </div>
          <span class="badge">${escapeHtml(statusLabel)}</span>
        </div>
        ${OsBrandPrint.voucherFooterHtml(
          qrSvg: qr,
          barcodeSvg: barcode,
          documentRef: ref,
        )}
      </div>
''';
}

String buildOsPayslipPrintHtml(OsPayslipModel slip, {bool forPdf = false}) {
  final ref = osPayslipRef(slip);
  final statusLabel = slip.isPaid
      ? AppLocaleKeys.osPayslipsStatusPaid.tr
      : AppLocaleKeys.osPayslipsStatusPending.tr;
  final job = slip.jobTitle?.trim().isNotEmpty == true
      ? slip.jobTitle!
      : AppLocaleKeys.osCommonDash.tr;
  final dateStr = _issueDateLabel();
  final qr = OsPrintCodes.qrSvg('${OsBrandPrint.agencySiteUrl}?slip=$ref');
  final barcode = OsPrintCodes.code128Svg(ref);
  final inner = _osPayslipPrintInnerHtml(
    slip,
    ref: ref,
    statusLabel: statusLabel,
    job: job,
    dateStr: dateStr,
    qr: qr,
    barcode: barcode,
    includeBrandWatermark: !forPdf,
  );
  final bodySheets = forPdf
      ? osPrintSingleSheet(sheetClass: 'payslip-print', innerHtml: inner)
      : osPrintTwoCopies(sheetClass: 'payslip-print', innerHtml: inner);

  return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>${escapeHtml(AppLocaleKeys.osPrintPayslipTitle.tr)} — ${escapeHtml(ref)}</title>
<style>
$osPrintA4Css
${OsBrandPrint.brandCss()}
${_osPayslipPrintExtraCss()}
</style>
</head>
<body>
$bodySheets
</body>
</html>
''';
}
