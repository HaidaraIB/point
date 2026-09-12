import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/View/Os/Payroll/os_payslip_print_text.dart';
import 'package:point/View/Os/os_print_document.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Opens a print-friendly payslip HTML (web) or copies plain text (non-web).
Future<void> printOsPayslip(OsPayslipModel slip) {
  return openOsPrintDocument(
    html: buildOsPayslipPrintHtml(slip),
    titleKey: AppLocaleKeys.osPayslipsTitle,
    fallbackKey: AppLocaleKeys.osPayslipsPrintHint,
    onUnsupported: () async {
      final text = buildOsPayslipPlainText(slip);
      await Clipboard.setData(ClipboardData(text: text));
      OsSnackbar.success(
        AppLocaleKeys.osPayslipsTitle.tr,
        AppLocaleKeys.osPayslipsCopied.tr,
      );
    },
  );
}

Future<void> copyOsPayslip(OsPayslipModel slip) async {
  final text = buildOsPayslipPlainText(slip);
  await Clipboard.setData(ClipboardData(text: text));
  OsSnackbar.success(
    AppLocaleKeys.osPayslipsTitle.tr,
    AppLocaleKeys.osPayslipsCopied.tr,
  );
}
