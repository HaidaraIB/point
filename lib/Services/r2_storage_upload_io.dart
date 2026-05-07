import 'dart:async';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:point/Services/r2_sign_request.dart';

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
}) async {
  final ext = _extFromFileName(fileName);
  final ct =
      (contentType != null && contentType.trim().isNotEmpty)
          ? contentType.trim()
          : (lookupMimeType(fileName) ?? 'application/octet-stream');

  final sign = await requestR2SignUpload(
    contentType: ct,
    ext: ext,
    friendlyDownloadName: friendlyDownloadName,
  );

  final uri = Uri.parse(sign.uploadUrl);
  final client = http.Client();
  try {
    final request = http.StreamedRequest('PUT', uri);
    sign.headers.forEach((String k, String v) {
      request.headers[k] = v;
    });
    request.contentLength = data.length;

    Future<void> writeBody() async {
      const chunkSize = 64 * 1024;
      var offset = 0;
      while (offset < data.length) {
        final end = min(offset + chunkSize, data.length);
        request.sink.add(data.sublist(offset, end));
        offset = end;
        onProgress?.call(offset, data.length);
      }
      await request.sink.close();
    }

    final bodyFuture = writeBody();
    final streamed = await client.send(request);
    await bodyFuture;
    final respBytes = await streamed.stream.toBytes();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body =
          respBytes.isEmpty ? '' : String.fromCharCodes(respBytes.take(2000));
      throw StateError('R2 upload failed: HTTP ${streamed.statusCode} $body');
    }
    return sign.publicUrl;
  } finally {
    client.close();
  }
}
