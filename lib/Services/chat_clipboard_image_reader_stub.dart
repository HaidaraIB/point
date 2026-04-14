import 'dart:typed_data';

import 'package:pasteboard/pasteboard.dart';

class ClipboardImageData {
  ClipboardImageData({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

Future<ClipboardImageData?> readClipboardImageData() async {
  try {
    final imageBytes = await Pasteboard.image;
    if (imageBytes == null || imageBytes.isEmpty) return null;
    return ClipboardImageData(bytes: imageBytes, mimeType: 'image/png');
  } catch (_) {
    return null;
  }
}
