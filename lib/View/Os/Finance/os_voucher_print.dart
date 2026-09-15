import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/View/Os/Finance/os_voucher_print_text.dart';
import 'package:point/View/Os/Print/os_print_assets.dart';
import 'package:point/View/Os/os_print_document.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Opens a print-friendly voucher HTML slip (web) or copies plain text (non-web).
Future<void> printOsVoucher({
  required OsVoucherModel voucher,
  required String accountName,
}) async {
  await OsPrintAssets.ensureLoaded();
  return openOsPrintDocument(
    html: buildOsVoucherPrintHtml(
      voucher: voucher,
      accountName: accountName,
    ),
    titleKey: AppLocaleKeys.osFinanceVouchers,
    fallbackKey: AppLocaleKeys.osVouchersPrintFallback,
    onUnsupported: () async {
      final text = buildOsVoucherPlainText(
        voucher: voucher,
        accountName: accountName,
      );
      await Clipboard.setData(ClipboardData(text: text));
      OsSnackbar.success(
        AppLocaleKeys.osFinanceVouchers.tr,
        AppLocaleKeys.osVouchersPrintFallback.tr,
      );
    },
  );
}
