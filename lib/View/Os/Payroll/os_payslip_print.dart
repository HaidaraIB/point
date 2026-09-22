import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/View/Os/Payroll/os_payslip_print_text.dart';
import 'package:point/View/Os/Print/os_print_assets.dart';
import 'package:point/View/Os/os_print_document.dart';
import 'package:point/View/Os/os_print_pdf.dart';
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

String osPayslipPdfFilename(OsPayslipModel slip) {
  final ref = (slip.displayNumber?.trim().isNotEmpty == true
          ? slip.displayNumber!.trim()
          : null) ??
      slip.period;
  final safe = ref.replaceAll(RegExp(r'[^\w\-]+'), '_');
  return 'payslip-$safe.pdf';
}

Future<Uint8List?> generateOsPayslipPdfBytes(OsPayslipModel slip) async {
  if (!kIsWeb) return null;
  await OsPrintAssets.ensureLoaded();
  return generateOsPrintPdfBytesFromPrintHtml(
    buildOsPayslipPrintHtml(slip, forPdf: true),
  );
}

Future<void> downloadOsPayslipPdf(OsPayslipModel slip) async {
  await OsPrintAssets.ensureLoaded();
  await downloadOsPrintPdf(
    printHtml: buildOsPayslipPrintHtml(slip, forPdf: true),
    fileName: osPayslipPdfFilename(slip),
    titleKey: AppLocaleKeys.osPayslipsTitle,
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
