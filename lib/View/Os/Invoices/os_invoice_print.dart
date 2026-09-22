import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Models/Os/OsServiceModel.dart';
import 'package:point/Services/os_paytabs_service.dart';
import 'package:point/View/Os/os_print_pdf.dart';
import 'package:point/View/Os/Invoices/os_invoice_print_text.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/Print/os_print_assets.dart';
import 'package:point/View/Os/os_finance_format.dart';
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
  final paymentLink = printable.isPaid
      ? null
      : await OsPaytabsService.instance.resolveInvoicePaymentLink(printable);
  return openOsPrintDocument(
    html: buildOsInvoicePrintHtml(printable, paymentLink: paymentLink),
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

/// Downloads the same client-copy PDF attached to WhatsApp invoice sends (web only).
Future<void> downloadOsInvoiceClientCopyPdf(OsInvoiceModel invoice) async {
  await OsPrintAssets.ensureLoaded();
  final printable = _invoiceForPrint(invoice);
  final paymentLink = printable.isPaid
      ? null
      : await OsPaytabsService.instance.resolveInvoicePaymentLink(printable);
  await downloadOsPrintPdf(
    printHtml: buildOsInvoicePrintHtml(
      printable,
      paymentLink: paymentLink,
      forPdf: true,
    ),
    fileName: osInvoicePdfFilename(invoice),
    titleKey: AppLocaleKeys.osInvoicesTitle,
  );
}

String osInvoicePdfFilename(OsInvoiceModel invoice) {
  final ref = OsFinanceFormat.invoiceRef(invoice);
  final safe = ref.replaceAll(RegExp(r'[^\w\-]+'), '_');
  return 'invoice-$safe.pdf';
}

/// Invoice PDF from the same HTML as print (web: `web/os_invoice_html_pdf.js`).
Future<Uint8List?> generateOsInvoiceClientCopyPdfBytes(
  OsInvoiceModel invoice,
) async {
  if (!kIsWeb) return null;

  await OsPrintAssets.ensureLoaded();
  final printable = _invoiceForPrint(invoice);
  final paymentLink = printable.isPaid
      ? null
      : await resolveOsInvoicePaymentLink(printable);
  return generateOsPrintPdfBytesFromPrintHtml(
    buildOsInvoicePrintHtml(
      printable,
      paymentLink: paymentLink,
      forPdf: true,
    ),
  );
}
