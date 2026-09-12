import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/View/Os/Invoices/os_invoice_print_text.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Non-web: copy invoice text and show a print hint (point_os mobile fallback).
Future<void> printOsInvoice(OsInvoiceModel invoice) async {
  final text = buildOsInvoicePlainText(invoice);
  await Clipboard.setData(ClipboardData(text: text));
  OsSnackbar.success(
    AppLocaleKeys.osInvoicesTitle.tr,
    AppLocaleKeys.osInvoicesPrintHint.tr,
  );
}
