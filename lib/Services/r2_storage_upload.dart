import 'dart:typed_data';

import 'r2_storage_upload_io.dart'
    if (dart.library.html) 'r2_storage_upload_web.dart' as impl;

/// Uploads [data] to R2 via presigned PUT, returns the public [publicUrl] from the worker.
Future<String> uploadObjectToR2({
  required Uint8List data,
  required String fileName,
  String? contentType,
  String? friendlyDownloadName,
  void Function(int sent, int total)? onProgress,
}) {
  return impl.uploadObjectToR2(
    data: data,
    fileName: fileName,
    contentType: contentType,
    friendlyDownloadName: friendlyDownloadName,
    onProgress: onProgress,
  );
}
