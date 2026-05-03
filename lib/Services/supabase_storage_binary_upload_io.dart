import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:retry/retry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_storage_binary_upload_shared.dart';

/// Chunk size for streaming the body so [onProgress] fires during upload.
const int _kUploadChunkBytes = 64 * 1024;

Stream<List<int>> _chunkedUint8Stream(
  Uint8List data,
  void Function(int sent, int total)? onProgress,
) async* {
  final total = data.length;
  if (total == 0) {
    onProgress?.call(0, 0);
    return;
  }
  var offset = 0;
  while (offset < total) {
    final end = offset + _kUploadChunkBytes < total
        ? offset + _kUploadChunkBytes
        : total;
    yield data.sublist(offset, end);
    offset = end;
    onProgress?.call(offset, total);
  }
}

http.MultipartRequest _buildMultipartRequest({
  required Uri uri,
  required Map<String, String> headers,
  required Uint8List data,
  required FileOptions fileOptions,
  required MediaType contentType,
  void Function(int sent, int total)? onProgress,
}) {
  final request = http.MultipartRequest('POST', uri)
    ..headers.addAll(headers)
    ..headers['x-upsert'] = fileOptions.upsert.toString()
    ..fields['cacheControl'] = fileOptions.cacheControl
    ..files.add(
      http.MultipartFile(
        '',
        _chunkedUint8Stream(data, onProgress),
        data.length,
        filename: '',
        contentType: contentType,
      ),
    );
  if (fileOptions.metadata != null) {
    request.fields['metadata'] = json.encode(fileOptions.metadata);
  }
  if (fileOptions.headers != null) {
    request.headers.addAll(fileOptions.headers!);
  }
  return request;
}

Future<String> uploadStorageObjectBinary({
  required SupabaseClient supabase,
  required String bucketId,
  required String objectPath,
  required Uint8List data,
  FileOptions fileOptions = const FileOptions(),
  void Function(int sent, int total)? onProgress,
  int retryAttempts = 0,
  StorageRetryController? retryController,
  String? mimeLookupPath,
}) async {
  final uri = storageObjectUri(supabase: supabase, bucketId: bucketId, objectPath: objectPath);
  final lookupKey = mimeLookupKey(objectPath: objectPath, mimeLookupPath: mimeLookupPath);
  final contentType = multipartContentType(fileOptions, lookupKey);

  final client = http.Client();
  try {
    final streamed = await RetryOptions(maxAttempts: retryAttempts + 1)
        .retry<http.StreamedResponse>(
      () async {
        final headers = await resolveStorageUploadHeaders(supabase);
        final request = _buildMultipartRequest(
          uri: uri,
          headers: headers,
          data: data,
          fileOptions: fileOptions,
          contentType: contentType,
          onProgress: onProgress,
        );
        return client.send(request);
      },
      retryIf: (e) =>
          retryController?.cancelled != true &&
          (e is http.ClientException || e is TimeoutException),
    );

    final response = await http.Response.fromStream(streamed);
    return parseStorageUploadResponse(response);
  } finally {
    client.close();
  }
}
