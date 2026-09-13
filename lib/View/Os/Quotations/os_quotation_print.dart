import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/View/Os/Quotations/os_quotation_print_text.dart';
import 'package:point/View/Os/os_print_document.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Opens a print-friendly quote HTML slip (web) or copies plain text (non-web).
Future<void> printOsQuotation(OsQuotationModel quote) {
  return openOsPrintDocument(
    html: buildOsQuotationPrintHtml(quote),
    titleKey: AppLocaleKeys.osQuotationsTitle,
    fallbackKey: AppLocaleKeys.osQuotationsPrintHint,
    onUnsupported: () async {
      final text = buildOsQuotationPlainText(quote);
      await Clipboard.setData(ClipboardData(text: text));
      OsSnackbar.success(
        AppLocaleKeys.osQuotationsTitle.tr,
        AppLocaleKeys.osQuotationsPrintHint.tr,
      );
    },
  );
}
