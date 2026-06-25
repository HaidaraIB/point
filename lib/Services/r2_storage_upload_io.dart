import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:mime/mime.dart' show lookupMimeType;
import 'package:point/Services/r2_sign_request.dart';
import 'package:point/Services/upload_cancel_token.dart';
import 'package:point/Services/upload_errors.dart';

String _extFromFileName(String fileName) {
  final n = fileName.trim();
  if (n.isEmpty) return '.bin';
  final dot = n.lastIndexOf('.');
  if (dot < 0 || dot >= n.length - 1) return '.bin';
  return n.substring(dot);
}

/// Yields [data] in chunks; progress updates when the socket consumes each chunk.
Stream<List<int>> _chunkedUploadStream({
  required Uint8List data,
  UploadCancelToken? cancelToken,
  void Function(int sent, int total)? onProgress,
}) async* {
  const chunkSize = 64 * 1024;
  final total = data.length;
  final progressTotal = total > 0 ? total : 1;
  onProgress?.call(0, progressTotal);

  if (total == 0) {
    onProgress?.call(1, progressTotal);
    return;
  }

  var offset = 0;
  while (offset < total) {
    cancelToken?.throwIfCancelled();
    final end = min(offset + chunkSize, total);
    yield data.sublist(offset, end);
    offset = end;
    onProgress?.call(offset, total);
  }
}

Future<String> uploadObjectToR2({
  required Uint8List data,
  required String fileName,
  String? contentType,
  String? friendlyDownloadName,
  void Function(int sent, int total)? onProgress,
  UploadCancelToken? cancelToken,
}) async {
  final ext = _extFromFileName(fileName);
  final ct =
      (contentType != null && contentType.trim().isNotEmpty)
          ? contentType.trim()
          : (lookupMimeType(fileName) ?? 'application/octet-stream');

  cancelToken?.throwIfCancelled();

  final sign = await requestR2SignUpload(
    contentType: ct,
    ext: ext,
    friendlyDownloadName: friendlyDownloadName,
    cancelToken: cancelToken,
  );

  cancelToken?.throwIfCancelled();

  final uri = Uri.parse(sign.uploadUrl);
  final client = HttpClient();
  if (cancelToken != null) {
    cancelToken.onCancel = () {
      try {
        client.close(force: true);
      } catch (_) {}
    };
  }

  try {
    final request = await client.putUrl(uri);
    sign.headers.forEach((String k, String v) {
      final lower = k.toLowerCase();
      if (lower == 'content-length' || lower == 'host') return;
      request.headers.set(k, v);
    });
    request.contentLength = data.length;

    await request.addStream(
      _chunkedUploadStream(
        data: data,
        cancelToken: cancelToken,
        onProgress: onProgress,
      ),
    );

    final response = await request.close();
    cancelToken?.throwIfCancelled();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response
          .transform(utf8.decoder)
          .take(2000)
          .join();
      throw UploadFailureException(
        stage: UploadFailureStage.put,
        errorCode: 'http_${response.statusCode}',
        httpStatus: response.statusCode,
        message: body.length > 500 ? '${body.substring(0, 500)}…' : body,
      );
    }

    await response.drain();
    return sign.publicUrl;
  } on UploadCancelledException {
    rethrow;
  } catch (e) {
    if (cancelToken?.isCancelled == true) {
      throw const UploadCancelledException();
    }
    rethrow;
  } finally {
    client.close(force: cancelToken?.isCancelled == true);
  }
}
