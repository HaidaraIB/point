import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/OsServiceModel.dart';
import 'package:point/View/Os/Print/os_print_assets.dart';
import 'package:point/View/Os/Quotations/os_quotation_print_text.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_print_document.dart';
import 'package:point/View/Os/os_print_pdf.dart';
import 'package:point/View/Os/os_snackbar.dart';

OsQuotationModel _quotationForPrint(OsQuotationModel quote) {
  final List<OsServiceModel> catalog = Get.isRegistered<OsFinanceController>()
      ? Get.find<OsFinanceController>().services
      : const <OsServiceModel>[];
  final items = OsLineItem.withResolvedMarketing(quote.items, catalog);
  return quote.copyWith(items: items);
}

/// Opens a print-friendly quote HTML slip (web) or copies plain text (non-web).
Future<void> printOsQuotation(OsQuotationModel quote) async {
  await OsPrintAssets.ensureLoaded();
  final printable = _quotationForPrint(quote);
  return openOsPrintDocument(
    html: buildOsQuotationPrintHtml(printable),
    titleKey: AppLocaleKeys.osQuotationsTitle,
    fallbackKey: AppLocaleKeys.osQuotationsPrintHint,
    onUnsupported: () async {
      final text = buildOsQuotationPlainText(printable);
      await Clipboard.setData(ClipboardData(text: text));
      OsSnackbar.success(
        AppLocaleKeys.osQuotationsTitle.tr,
        AppLocaleKeys.osQuotationsPrintHint.tr,
      );
    },
  );
}

Future<void> downloadOsQuotationClientCopyPdf(OsQuotationModel quote) async {
  await OsPrintAssets.ensureLoaded();
  final printable = _quotationForPrint(quote);
  await downloadOsPrintPdf(
    printHtml: buildOsQuotationPrintHtml(printable, forPdf: true),
    fileName: osQuotationPdfFilename(quote),
    titleKey: AppLocaleKeys.osQuotationsTitle,
  );
}

String osQuotationPdfFilename(OsQuotationModel quote) {
  final ref = OsFinanceFormat.quotationRef(quote);
  final safe = ref.replaceAll(RegExp(r'[^\w\-]+'), '_');
  return 'quotation-$safe.pdf';
}

Future<Uint8List?> generateOsQuotationClientCopyPdfBytes(
  OsQuotationModel quote,
) async {
  await OsPrintAssets.ensureLoaded();
  final printable = _quotationForPrint(quote);
  return generateOsPrintPdfBytesFromPrintHtml(
    buildOsQuotationPrintHtml(printable, forPdf: true),
  );
}
