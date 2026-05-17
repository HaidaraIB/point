import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

const int _skipBelowBytes = 300 * 1024;
const int _maxEdge = 1920;
const int _jpegQuality = 85;

bool _compressible(String fileName) {
  final lower = fileName.trim().toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.heif');
}

Future<Uint8List> compressChatImage(Uint8List bytes, String fileName) async {
  if (!_compressible(fileName)) return bytes;
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.gif')) return bytes;
  if (bytes.length < _skipBelowBytes &&
      (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))) {
    return bytes;
  }

  try {
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: _maxEdge,
      minHeight: _maxEdge,
      quality: _jpegQuality,
      format: CompressFormat.jpeg,
    );
    if (out.isNotEmpty) return out;
  } catch (_) {}
  return bytes;
}
