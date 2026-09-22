import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/os_print_pdf_bytes.dart';
import 'package:point/Utils/chat_attachment_save.dart';
import 'package:point/View/Os/Print/os_print_assets.dart';
import 'package:point/View/Os/Print/os_print_pdf_html.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Builds a PDF from print HTML (callers pass `forPdf: true` for a single clean page).
Future<Uint8List?> generateOsPrintPdfBytesFromPrintHtml(String printHtml) async {
  if (!kIsWeb) return null;
  if (printHtml.trim().isEmpty) return null;
  await OsPrintAssets.ensureLoaded();
  final captureHtml = osPrintHtmlForPdfCapture(printHtml);
  return captureOsPrintPdfBytesFromHtml(captureHtml);
}

Future<void> downloadOsPrintPdf({
  required String printHtml,
  required String fileName,
  required String titleKey,
}) async {
  final title = titleKey.tr;
  final bytes = await generateOsPrintPdfBytesFromPrintHtml(printHtml);
  if (bytes == null || bytes.isEmpty) {
    OsSnackbar.error(
      title,
      AppLocaleKeys.osMessagingHubDocumentPdfFailed.tr,
    );
    return;
  }
  final result = await saveChatAttachmentBytes(
    bytes: bytes,
    fileName: fileName,
  );
  if (result.ok) {
    OsSnackbar.success(
      title,
      AppLocaleKeys.osMessagingHubDocumentPdfDone.tr,
    );
  } else {
    OsSnackbar.error(
      title,
      AppLocaleKeys.osMessagingHubDocumentPdfFailed.tr,
    );
  }
}
