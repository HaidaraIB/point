// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

class ClipboardImageData {
  ClipboardImageData({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

Future<ClipboardImageData?> readClipboardImageData() async {
  final clipboard = html.window.navigator.clipboard;
  if (clipboard == null) return null;
  if (!js_util.hasProperty(clipboard, 'read')) return null;
  try {
    final dynamic rawItems = await js_util.promiseToFuture<dynamic>(
      js_util.callMethod(clipboard, 'read', const []),
    );
    final items = _asList(rawItems);
    for (final dynamic item in items) {
      final types = _asList(js_util.getProperty(item, 'types'));
      for (final dynamic t in types) {
        final mime = t.toString().toLowerCase();
        if (!mime.startsWith('image/')) continue;
        final dynamic blobFuture = js_util.callMethod(item, 'getType', [t]);
        final dynamic blob = await js_util.promiseToFuture<dynamic>(blobFuture);
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

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  try {
    return List<dynamic>.from(value as Iterable);
  } catch (_) {
    return const [];
  }
}

Future<Uint8List?> _blobToBytes(dynamic blob) async {
  try {
    final dynamic bufferFuture = js_util.callMethod(blob, 'arrayBuffer', const []);
    final dynamic result = await js_util.promiseToFuture<dynamic>(bufferFuture);
    if (result is ByteBuffer) return Uint8List.view(result);
    if (result is Uint8List) return result;
  } catch (_) {}
  return null;
}
