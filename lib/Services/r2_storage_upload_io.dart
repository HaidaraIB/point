import 'dart:async';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:point/Services/r2_sign_request.dart';
import 'package:point/Services/upload_cancel_token.dart';

String _extFromFileName(String fileName) {
  final n = fileName.trim();
  if (n.isEmpty) return '.bin';
  final dot = n.lastIndexOf('.');
  if (dot < 0 || dot >= n.length - 1) return '.bin';
  return n.substring(dot);
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
  );

  cancelToken?.throwIfCancelled();

  final uri = Uri.parse(sign.uploadUrl);
  final client = http.Client();
  http.StreamedRequest? request;
  if (cancelToken != null) {
    cancelToken.onCancel = () {
      client.close();
      try {
        request?.sink.close();
      } catch (_) {}
    };
  }
  try {
    final activeRequest = http.StreamedRequest('PUT', uri);
    request = activeRequest;
    sign.headers.forEach((String k, String v) {
      activeRequest.headers[k] = v;
    });
    activeRequest.contentLength = data.length;

    Future<void> writeBody() async {
      const chunkSize = 64 * 1024;
      var offset = 0;
      final sink = activeRequest.sink;
      while (offset < data.length) {
        cancelToken?.throwIfCancelled();
        final end = min(offset + chunkSize, data.length);
        sink.add(data.sublist(offset, end));
        offset = end;
        onProgress?.call(offset, data.length);
      }
      await sink.close();
    }

    final bodyFuture = writeBody();
    final streamed = await client.send(activeRequest);
    await bodyFuture;
    cancelToken?.throwIfCancelled();
    final respBytes = await streamed.stream.toBytes();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body =
          respBytes.isEmpty ? '' : String.fromCharCodes(respBytes.take(2000));
      throw StateError('R2 upload failed: HTTP ${streamed.statusCode} $body');
    }
    return sign.publicUrl;
  } on UploadCancelledException {
    rethrow;
  } catch (e) {
    if (cancelToken?.isCancelled == true) {
      throw const UploadCancelledException();
    }
    rethrow;
  } finally {
    client.close();
  }
}
