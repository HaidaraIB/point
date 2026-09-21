import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('pointOsInvoiceHtmlToPdf')
external JSPromise<JSArrayBuffer> _pointOsInvoiceHtmlToPdf(JSString html);

/// Same HTML as print preview → JPEG in A4 PDF via hidden iframe (browser layout).
Future<Uint8List?> captureOsInvoicePdfFromHtmlWeb(String html) async {
  if (html.trim().isEmpty) return null;
  try {
    // Let the loading spinner paint before heavy canvas work.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final raw = await _pointOsInvoiceHtmlToPdf(html.toJS).toDart;
    return raw.toDart.asUint8List();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('invoice PDF web capture failed: $e\n$st');
    }
    return null;
  }
}
