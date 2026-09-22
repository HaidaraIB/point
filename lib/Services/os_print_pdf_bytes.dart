import 'package:flutter/foundation.dart';
import 'package:point/Services/os_invoice_pdf_web_capture.dart';

/// Renders print HTML to PDF bytes (web only; same as invoice client copy).
Future<Uint8List?> captureOsPrintPdfBytesFromHtml(String html) async {
  if (!kIsWeb) return null;
  if (html.trim().isEmpty) return null;
  return captureOsInvoicePdfFromHtmlWeb(html);
}
