import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/Utils/os_arabic_currency.dart';
import 'package:point/View/Os/os_finance_format.dart';

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

String buildOsVoucherPrintHtml({
  required OsVoucherModel voucher,
  required String accountName,
}) {
  final ref = OsFinanceFormat.voucherRef(voucher);
  final isReceipt = voucher.type == OsVoucherType.receipt;
  final desc = OsFinanceFormat.displayDescription(voucher.description);
  final title = isReceipt
      ? AppLocaleKeys.osVouchersTitleReceipt.tr
      : AppLocaleKeys.osVouchersTitlePayment.tr;
  final partyLabel = isReceipt
      ? AppLocaleKeys.osVouchersFrom.tr
      : AppLocaleKeys.osVouchersTo.tr;
  final accent = isReceipt ? '#16a34a' : '#e11d48';
  final about = desc.isEmpty
      ? AppLocaleKeys.osVouchersDefaultDesc.tr
      : desc;

  var stampBlock = '';
  if (Get.isRegistered<OsStampSettingsController>()) {
    final stamp = Get.find<OsStampSettingsController>();
    if (stamp.stampEnabled.value) {
      final hex =
          '#${stamp.stampColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      stampBlock = '''
<div class="stamp" style="border-color:$hex;color:$hex">
  <div class="stamp-cert">${_esc(AppLocaleKeys.osVouchersStampCertified.tr)}</div>
  <div class="stamp-text">${_esc(stamp.stampText.value)}</div>
  <div class="stamp-ref">REF: ${_esc(ref)}</div>
  <div class="stamp-dept">${_esc(AppLocaleKeys.osVouchersStampDept.tr)}</div>
</div>''';
    }
  }

  return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<title>${_esc(title)} — ${_esc(ref)}</title>
<style>
  body {
    font-family: Tahoma, 'Segoe UI', Arial, sans-serif;
    color: #0f172a;
    background: #fff;
    padding: 32px;
    margin: 0;
  }
  .sheet {
    border: 2px solid #cbd5e1;
    border-radius: 20px;
    padding: 28px;
    max-width: 720px;
    margin: 0 auto;
  }
  .header {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    align-items: flex-start;
    border-bottom: 2px solid #e2e8f0;
    padding-bottom: 16px;
    margin-bottom: 16px;
  }
  .agency { font-size: 16px; font-weight: 900; margin: 0 0 4px; }
  .muted { color: #64748b; font-size: 11px; font-weight: 600; }
  .meta {
    font-family: monospace;
    font-size: 11px;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    padding: 10px 12px;
    min-width: 140px;
  }
  .meta strong { color: #4f46e5; }
  .badge {
    display: inline-block;
    padding: 6px 14px;
    border-radius: 999px;
    border: 2px solid $accent;
    color: $accent;
    font-size: 12px;
    font-weight: 800;
    margin: 8px auto 18px;
  }
  .badge-wrap { text-align: center; }
  .grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
    margin-bottom: 16px;
  }
  .tile {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 14px;
    padding: 12px;
    text-align: center;
  }
  .tile .lbl { font-size: 10px; color: #94a3b8; font-weight: 700; }
  .tile .val { font-size: 15px; font-weight: 900; color: #4f46e5; margin-top: 4px; }
  .box {
    border: 1px solid #e2e8f0;
    border-radius: 14px;
    padding: 14px 16px;
    margin-bottom: 20px;
  }
  .row { margin: 8px 0; font-size: 13px; }
  .row .lbl { color: #64748b; font-weight: 700; display: block; margin-bottom: 2px; }
  .row .val { font-weight: 700; color: #0f172a; }
  .row .val.bold { font-weight: 900; font-size: 14px; }
  hr { border: none; border-top: 1px solid #e2e8f0; margin: 10px 0; }
  .sigs {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
    margin-top: 8px;
  }
  .sig {
    flex: 1;
    text-align: center;
    font-size: 11px;
  }
  .sig .line {
    margin-top: 36px;
    border-top: 1px dashed #94a3b8;
    padding-top: 8px;
    font-weight: 800;
  }
  .sig .sub { color: #94a3b8; font-size: 10px; margin-top: 2px; }
  .stamp {
    width: 112px;
    height: 112px;
    border-radius: 50%;
    border: 2.5px solid;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    transform: rotate(6deg);
    flex-shrink: 0;
    padding: 8px;
    box-sizing: border-box;
  }
  .stamp-cert { font-size: 8px; font-weight: 800; }
  .stamp-text { font-size: 10px; font-weight: 700; margin: 2px 0; }
  .stamp-ref, .stamp-dept { font-size: 8px; font-weight: 700; }
  .footer {
    text-align: center;
    font-size: 10px;
    color: #64748b;
    margin-top: 18px;
  }
  @media print {
    body { padding: 0; }
    .sheet { border-radius: 0; max-width: none; }
  }
</style>
</head>
<body>
  <div class="sheet">
    <div class="header">
      <div>
        <p class="agency">${_esc(AppLocaleKeys.osVouchersAgency.tr)}</p>
        <div class="muted">${_esc(AppLocaleKeys.osVouchersDept.tr)}</div>
        <div class="muted">${_esc(AppLocaleKeys.osVouchersLocation.tr)}</div>
      </div>
      <div class="meta">
        <div>${_esc(AppLocaleKeys.osVouchersRef.tr)}: <strong>${_esc(ref)}</strong></div>
        <div>${_esc(AppLocaleKeys.osVouchersDate.tr)}: ${_esc(voucher.date)}</div>
      </div>
    </div>
    <div class="badge-wrap"><span class="badge">${_esc(title)}</span></div>
    <div class="grid">
      <div class="tile">
        <div class="lbl">${_esc(AppLocaleKeys.osVouchersAmountDigits.tr)}</div>
        <div class="val">${_esc(OsFinanceFormat.money(voucher.amount))}</div>
      </div>
      <div class="tile">
        <div class="lbl">${_esc(AppLocaleKeys.osVouchersAccountLinked.tr)}</div>
        <div class="val" style="color:#0f172a;font-size:13px">${_esc(accountName)}</div>
      </div>
    </div>
    <div class="box">
      <div class="row">
        <span class="lbl">${_esc(partyLabel)}</span>
        <span class="val bold">${_esc(voucher.payeeOrPayer)}</span>
      </div>
      <hr/>
      <div class="row">
        <span class="lbl">${_esc(AppLocaleKeys.osVouchersAmountWordsLabel.tr)}</span>
        <span class="val">${_esc(OsArabicCurrency.formatIqd(voucher.amount))}</span>
      </div>
      <hr/>
      <div class="row">
        <span class="lbl">${_esc(AppLocaleKeys.osVouchersAboutLabel.tr)}</span>
        <span class="val">${_esc(about)}</span>
      </div>
    </div>
    <div class="sigs">
      <div class="sig">
        <div class="line">${_esc(AppLocaleKeys.osVouchersSignPayee.tr)}</div>
        <div class="sub">${_esc(AppLocaleKeys.osVouchersSignPayeeSub.tr)}</div>
      </div>
      $stampBlock
      <div class="sig">
        <div class="line">${_esc(AppLocaleKeys.osVouchersSignAccountant.tr)}</div>
        <div class="sub">${_esc(AppLocaleKeys.osVouchersSignAccountantSub.tr)}</div>
      </div>
    </div>
    <div class="footer">${_esc(AppLocaleKeys.osVouchersFooter.tr)}</div>
  </div>
</body>
</html>
''';
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
