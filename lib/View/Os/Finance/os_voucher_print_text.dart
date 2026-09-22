import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Utils/os_arabic_currency.dart';
import 'package:point/View/Os/Print/os_brand_print.dart';
import 'package:point/View/Os/Print/os_print_codes.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_print_a4.dart';

String buildOsVoucherPlainText({
  required OsVoucherModel voucher,
  required String accountName,
}) {
  final ref = OsFinanceFormat.voucherRef(voucher);
  final isReceipt = voucher.type == OsVoucherType.receipt;
  final desc = OsFinanceFormat.displayDescription(voucher.description);
  return '''
${AppLocaleKeys.osVouchersAgency.tr}
${AppLocaleKeys.osVouchersDept.tr}
${isReceipt ? AppLocaleKeys.osVouchersTitleReceipt.tr : AppLocaleKeys.osVouchersTitlePayment.tr}
========================================
${AppLocaleKeys.osVouchersRef.tr}: $ref
${AppLocaleKeys.osVouchersDate.tr}: ${voucher.date}
${AppLocaleKeys.osVouchersAccount.tr}: $accountName
----------------------------------------
${isReceipt ? AppLocaleKeys.osVouchersFrom.tr : AppLocaleKeys.osVouchersTo.tr}: ${voucher.payeeOrPayer}
${AppLocaleKeys.osVouchersAmount.tr}: ${OsFinanceFormat.money(voucher.amount)}
${AppLocaleKeys.osVouchersAmountWords.tr}: ${OsArabicCurrency.formatIqd(voucher.amount)}
----------------------------------------
${AppLocaleKeys.osVouchersAbout.tr}:
${desc.isEmpty ? AppLocaleKeys.osVouchersDefaultDesc.tr : desc}
----------------------------------------
${AppLocaleKeys.osVouchersSignAccountant.tr}
========================================
'''.trim();
}

String _metaCell(String label, String value) {
  return '''
<div class="vm-cell">
  <span class="vm-lbl">${escapeHtml(label)}</span>
  <span class="vm-val">${escapeHtml(value)}</span>
</div>''';
}

String _statementRow(String label, String value, {bool bold = false}) {
  final weight = bold ? ' bold' : '';
  return '''
<div class="st-row">
  <div class="lbl">${escapeHtml(label)}</div>
  <div class="val$weight">${escapeHtml(value)}</div>
</div>''';
}

String _osVoucherPrintExtraCss() {
  return '''
.voucher-print.sheet { min-height: 0; }
.voucher-print .watermark-logo {
  left: 4%;
  top: 46%;
  transform: translate(0, -50%);
  width: 46%;
  opacity: 0.95;
}
.voucher-print .brand-header {
  margin-bottom: 14px;
}
.voucher-title-row {
  direction: ltr;
  display: grid;
  grid-template-columns: 1.35fr 0.65fr;
  gap: 16px;
  align-items: center;
  margin: 4px 0 16px;
}
.voucher-meta {
  direction: rtl;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px 28px;
  border: 1px solid #d8d4ea;
  border-radius: 16px;
  padding: 14px 18px;
  background: rgba(255,255,255,0.72);
}
.vm-cell {
  display: flex;
  flex-direction: row;
  align-items: baseline;
  gap: 8px;
}
.vm-lbl {
  white-space: nowrap;
  color: var(--navy);
  font-weight: 700;
  font-size: 12px;
}
.vm-val {
  flex: 1;
  min-width: 0;
  border-bottom: 1px solid #c5c0dc;
  text-align: center;
  font-weight: 700;
  font-size: 12px;
  color: var(--text);
  padding: 0 4px 2px;
}
.voucher-heading {
  text-align: right;
}
.voucher-heading h1 {
  font-size: 34px;
  font-weight: 900;
  color: var(--navy);
  margin: 0;
  line-height: 1.05;
}
.voucher-heading .en {
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 6px;
  color: var(--navy);
  margin-top: 4px;
}
.voucher-statement {
  border: 1px solid #d7e3ec;
  border-radius: 16px;
  background: rgba(255,255,255,0.86);
  padding: 16px 20px;
}
.st-row + .st-row {
  border-top: 1px solid #e4edf3;
  margin-top: 12px;
  padding-top: 12px;
}
.st-row .lbl {
  color: #7b8b99;
  font-size: 12px;
  font-weight: 700;
  text-align: right;
  margin-bottom: 4px;
}
.st-row .val {
  color: var(--text);
  font-size: 13px;
  font-weight: 700;
  text-align: right;
}
.st-row .val.bold {
  font-weight: 900;
  font-size: 14px;
}
.voucher-print .brand-footer {
  margin-top: 16px;
  padding-top: 8px;
}
.voucher-footer-top {
  direction: ltr;
  display: grid;
  grid-template-columns: 1.15fr 0.7fr 1.15fr 0.55fr;
  gap: 8px;
  align-items: end;
  margin-bottom: 14px;
}
.voucher-sign {
  text-align: center;
  padding: 0 10px 6px;
  border-right: 1px solid var(--border);
}
.voucher-sign-line {
  border-bottom: 1.5px solid var(--navy);
  margin: 0 8px 8px;
  height: 28px;
}
.voucher-sign-lbl {
  font-size: 11px;
  font-weight: 700;
  color: var(--navy);
}
.voucher-barcode {
  text-align: center;
  min-width: 0;
}
.voucher-barcode .bc-svg svg {
  width: 100%;
  max-width: 170px;
  height: 36px;
  display: block;
  margin: 0 auto;
}
.voucher-print .qr-block .qr-svg,
.voucher-print .qr-block .qr-svg svg {
  width: 64px;
  height: 64px;
}
.voucher-bar {
  padding: 8px 22px;
}
.voucher-bar .en-wrap {
  display: flex;
  align-items: center;
  gap: 14px;
  flex: 1;
  min-width: 0;
}
.voucher-bar .en {
  font-size: 8px;
  font-weight: 400;
  letter-spacing: 3.6px;
  white-space: nowrap;
}
.voucher-bar .rule {
  display: block;
  width: 72px;
  height: 1px;
  background: rgba(255,255,255,0.85);
  flex-shrink: 0;
}
.voucher-bar .ar {
  font-size: 12px;
  letter-spacing: 1.2px;
}
''';
}

String _osVoucherPrintInnerHtml({
  required OsVoucherModel voucher,
  required String accountName,
  required String ref,
  required String titleAr,
  required String titleEn,
  required String typeLabel,
  required String partyLabel,
  required String about,
  required String qr,
  required String barcode,
  bool includeBrandWatermark = true,
}) {
  return '''
      ${includeBrandWatermark ? OsBrandPrint.watermarkHtml() : ''}
      <div class="content-layer">
        ${OsBrandPrint.headerHtml()}
        <div class="voucher-title-row no-split">
          <div class="voucher-meta">
            ${_metaCell(AppLocaleKeys.osPrintVoucherNo.tr, ref)}
            ${_metaCell(AppLocaleKeys.osPrintPaymentType.tr, typeLabel)}
            ${_metaCell(AppLocaleKeys.osPrintDate.tr, voucher.date)}
            ${_metaCell(AppLocaleKeys.osPrintPaymentMethod.tr, accountName)}
          </div>
          <div class="voucher-heading">
            <h1>${escapeHtml(titleAr)}</h1>
            <div class="en">${escapeHtml(titleEn)}</div>
          </div>
        </div>
        <div class="voucher-statement no-split">
          ${_statementRow(partyLabel, voucher.payeeOrPayer, bold: true)}
          ${_statementRow(
            AppLocaleKeys.osVouchersAmountDigits.tr,
            OsFinanceFormat.money(voucher.amount),
            bold: true,
          )}
          ${_statementRow(
            AppLocaleKeys.osVouchersAmountWordsLabel.tr,
            OsArabicCurrency.formatIqd(voucher.amount),
          )}
          ${_statementRow(AppLocaleKeys.osVouchersAboutLabel.tr, about)}
        </div>
        ${OsBrandPrint.voucherFooterHtml(
          qrSvg: qr,
          barcodeSvg: barcode,
          documentRef: ref,
        )}
      </div>
''';
}

String buildOsVoucherPrintHtml({
  required OsVoucherModel voucher,
  required String accountName,
  bool forPdf = false,
}) {
  final ref = OsFinanceFormat.voucherRef(voucher);
  final isReceipt = voucher.type == OsVoucherType.receipt;
  final desc = OsFinanceFormat.displayDescription(voucher.description);
  final titleAr = isReceipt
      ? AppLocaleKeys.osPrintVoucherReceiptAr.tr
      : AppLocaleKeys.osPrintVoucherPaymentAr.tr;
  final titleEn = isReceipt
      ? AppLocaleKeys.osPrintVoucherReceiptEn.tr
      : AppLocaleKeys.osPrintVoucherPaymentEn.tr;
  final typeLabel = isReceipt
      ? AppLocaleKeys.osVouchersTypeReceipt.tr
      : AppLocaleKeys.osVouchersTypePayment.tr;
  final partyLabel = isReceipt
      ? AppLocaleKeys.osVouchersFrom.tr
      : AppLocaleKeys.osVouchersTo.tr;
  final about = desc.isEmpty
      ? AppLocaleKeys.osVouchersDefaultDesc.tr
      : desc;

  final qr = OsPrintCodes.qrSvg('${OsBrandPrint.agencySiteUrl}?v=$ref');
  final barcode = OsPrintCodes.code128Svg(ref);
  final inner = _osVoucherPrintInnerHtml(
    voucher: voucher,
    accountName: accountName,
    ref: ref,
    titleAr: titleAr,
    titleEn: titleEn,
    typeLabel: typeLabel,
    partyLabel: partyLabel,
    about: about,
    qr: qr,
    barcode: barcode,
    includeBrandWatermark: !forPdf,
  );
  final bodySheets = forPdf
      ? osPrintSingleSheet(sheetClass: 'voucher-print', innerHtml: inner)
      : osPrintTwoCopies(sheetClass: 'voucher-print', innerHtml: inner);

  return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>${escapeHtml(titleAr)} — ${escapeHtml(ref)}</title>
<style>
$osPrintA4Css
${OsBrandPrint.brandCss()}
${_osVoucherPrintExtraCss()}
</style>
</head>
<body>
$bodySheets
</body>
</html>
''';
}

