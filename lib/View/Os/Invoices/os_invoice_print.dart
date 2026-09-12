import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/View/Os/Invoices/os_invoice_print_text.dart';
import 'package:point/View/Os/os_print_document.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Opens a print-friendly invoice HTML slip (web) or copies plain text (non-web).
Future<void> printOsInvoice(OsInvoiceModel invoice) {
  return openOsPrintDocument(
    html: buildOsInvoicePrintHtml(invoice),
    titleKey: AppLocaleKeys.osInvoicesTitle,
    fallbackKey: AppLocaleKeys.osInvoicesPrintHint,
    onUnsupported: () async {
      final text = buildOsInvoicePlainText(invoice);
      await Clipboard.setData(ClipboardData(text: text));
      OsSnackbar.success(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesPrintHint.tr,
      );
    },
  );
}
