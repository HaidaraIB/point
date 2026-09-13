import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Mock Nogta digital-accept URL (point_os copyAcceptLink).
/// Uses human quote ref (`Q-2024-001`), never the Firestore UUID.
String osQuotationAcceptLink(OsQuotationModel quote) {
  final id = OsFinanceFormat.quotationRef(quote);
  return 'https://pay.nogta.agency/accept-quote/$id';
}

Future<void> copyOsQuotationAcceptLink(OsQuotationModel quote) async {
  final link = osQuotationAcceptLink(quote);
  await Clipboard.setData(ClipboardData(text: link));
  OsSnackbar.success(
    AppLocaleKeys.osQuotationsTitle.tr,
    AppLocaleKeys.osQuotationsLinkCopied.tr,
  );
}
