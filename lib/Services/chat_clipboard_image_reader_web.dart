import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

class ClipboardImageData {
  ClipboardImageData({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

Future<ClipboardImageData?> readClipboardImageData() async {
  try {
    final clipboard = window.navigator.clipboard;
    final items = await clipboard.read().toDart;
    for (final item in items.toDart) {
      for (final t in item.types.toDart) {
        final mime = t.toDart.toLowerCase();
        if (!mime.startsWith('image/')) continue;
        final blob = await item.getType(mime).toDart;
        final bytes = await _blobToBytes(blob);
        if (bytes != null) {
          return ClipboardImageData(bytes: bytes, mimeType: mime);
        }
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

Future<Uint8List?> _blobToBytes(Blob blob) async {
  try {
    final buffer = await blob.arrayBuffer().toDart;
    return Uint8List.view(buffer.toDart);
  } catch (_) {
    return null;
  }
}
