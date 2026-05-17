import 'dart:typed_data';

import 'chat_image_compress_impl.dart'
    if (dart.library.html) 'chat_image_compress_stub.dart' as impl;

bool isChatCompressibleImageFileName(String fileName) {
  final lower = fileName.trim().toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.heif');
}

/// Resize/compress chat images on mobile; unchanged on web/desktop.
Future<Uint8List> compressChatImage(Uint8List bytes, String fileName) =>
    impl.compressChatImage(bytes, fileName);
