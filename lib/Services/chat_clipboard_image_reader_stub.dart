import 'dart:async';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart';

class ClipboardImageData {
  ClipboardImageData({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

Future<Uint8List?> _readClipboardFile(DataReader reader, FileFormat format) {
  final completer = Completer<Uint8List?>();
  final progress = reader.getFile(
    format,
    (file) async {
      try {
        final all = await file.readAll();
        if (!completer.isCompleted) completer.complete(all);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    },
    onError: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    },
  );
  if (progress == null && !completer.isCompleted) {
    completer.complete(null);
  }
  return completer.future;
}

Future<ClipboardImageData?> readClipboardImageData() async {
  try {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return null;
    final reader = await clipboard.read();

    final png = await _readClipboardFile(reader, Formats.png);
    if (png != null && png.isNotEmpty) {
      return ClipboardImageData(bytes: png, mimeType: 'image/png');
    }

    final jpeg = await _readClipboardFile(reader, Formats.jpeg);
    if (jpeg != null && jpeg.isNotEmpty) {
      return ClipboardImageData(bytes: jpeg, mimeType: 'image/jpeg');
    }

    final webp = await _readClipboardFile(reader, Formats.webp);
    if (webp != null && webp.isNotEmpty) {
      return ClipboardImageData(bytes: webp, mimeType: 'image/webp');
    }

    final gif = await _readClipboardFile(reader, Formats.gif);
    if (gif != null && gif.isNotEmpty) {
      return ClipboardImageData(bytes: gif, mimeType: 'image/gif');
    }
  } catch (_) {
    return null;
  }
  return null;
}
