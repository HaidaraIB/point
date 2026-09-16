import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Models/Os/OsServiceModel.dart';
import 'package:point/View/Os/Invoices/os_invoice_print_text.dart';
import 'package:point/View/Os/Print/os_print_assets.dart';
import 'package:point/View/Os/os_print_document.dart';
import 'package:point/View/Os/os_snackbar.dart';

OsInvoiceModel _invoiceForPrint(OsInvoiceModel invoice) {
  final List<OsServiceModel> catalog = Get.isRegistered<OsFinanceController>()
      ? Get.find<OsFinanceController>().services
      : const <OsServiceModel>[];
  final items = OsLineItem.withResolvedMarketing(invoice.items, catalog);
  return invoice.copyWith(items: items);
}

/// Opens a print-friendly invoice HTML slip (web) or copies plain text (non-web).
Future<void> printOsInvoice(OsInvoiceModel invoice) async {
  await OsPrintAssets.ensureLoaded();
  final printable = _invoiceForPrint(invoice);
  return openOsPrintDocument(
    html: buildOsInvoicePrintHtml(printable),
    titleKey: AppLocaleKeys.osInvoicesTitle,
    fallbackKey: AppLocaleKeys.osInvoicesPrintHint,
    onUnsupported: () async {
      final text = buildOsInvoicePlainText(printable);
      await Clipboard.setData(ClipboardData(text: text));
      OsSnackbar.success(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesPrintHint.tr,
      );
    },
  );
}
