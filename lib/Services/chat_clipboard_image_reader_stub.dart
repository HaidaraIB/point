import 'dart:typed_data';
import 'package:super_clipboard/super_clipboard.dart';

class ClipboardImageData {
  ClipboardImageData({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

Future<ClipboardImageData?> readClipboardImageData() async {
  try {
    final reader = await ClipboardReader.readClipboard();

    final png = await reader.readValue(Formats.png);
    if (png != null && png.isNotEmpty) {
      return ClipboardImageData(bytes: png, mimeType: 'image/png');
    }

    final jpeg = await reader.readValue(Formats.jpeg);
    if (jpeg != null && jpeg.isNotEmpty) {
      return ClipboardImageData(bytes: jpeg, mimeType: 'image/jpeg');
    }

    final webp = await reader.readValue(Formats.webp);
    if (webp != null && webp.isNotEmpty) {
      return ClipboardImageData(bytes: webp, mimeType: 'image/webp');
    }

    final gif = await reader.readValue(Formats.gif);
    if (gif != null && gif.isNotEmpty) {
      return ClipboardImageData(bytes: gif, mimeType: 'image/gif');
    }
  } catch (_) {
    return null;
  }
  return null;
}
