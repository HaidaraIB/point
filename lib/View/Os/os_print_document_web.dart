import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

/// Web: open a print-friendly HTML document and call [Window.print].
Future<void> openOsPrintDocument({
  required String html,
  required String titleKey,
  required String fallbackKey,
  Future<void> Function()? onUnsupported,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(html));
  final blob = Blob(
    <BlobPart>[bytes.toJS].toJS,
    BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = URL.createObjectURL(blob);
  final win = window.open(url, '_blank');
  if (win == null) {
    URL.revokeObjectURL(url);
    return;
  }

  var printed = false;
  void triggerPrint() {
    if (printed) return;
    printed = true;
    try {
      win.focus();
      win.print();
    } finally {
      URL.revokeObjectURL(url);
    }
  }

  try {
    final doc = win.document;
    if (doc.readyState == 'complete' || doc.readyState == 'interactive') {
      Future<void>.delayed(const Duration(milliseconds: 100), triggerPrint);
      return;
    }
    doc.addEventListener(
      'DOMContentLoaded',
      ((Event _) {
        Future<void>.delayed(const Duration(milliseconds: 50), triggerPrint);
      }).toJS,
    );
  } catch (_) {
    // Fall through to delayed print.
  }

  Future<void>.delayed(const Duration(milliseconds: 600), triggerPrint);
}
