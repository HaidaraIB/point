import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart';

import 'supabase_storage_binary_upload_shared.dart';

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

  Object? lastError;
  for (var attempt = 0; attempt < retryAttempts + 1; attempt++) {
    if (retryController?.cancelled == true) {
      throw StorageException('Upload cancelled', statusCode: 'cancelled');
    }
    try {
      final authHeaders = await resolveStorageUploadHeaders(supabase);
      return await _uploadOnceXhr(
        uri: uri,
        headers: authHeaders,
        data: data,
        fileOptions: fileOptions,
        contentType: contentType,
        onProgress: onProgress,
      );
    } catch (e, st) {
      lastError = e;
      if (e is StorageException) {
        final code = int.tryParse(e.statusCode ?? '');
        if (code != null && code >= 400 && code < 500) {
          rethrow;
        }
      }
      if (attempt >= retryAttempts) {
        Error.throwWithStackTrace(e, st);
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
  }
  throw lastError ?? StateError('uploadStorageObjectBinary: no result');
}

Future<String> _uploadOnceXhr({
  required Uri uri,
  required Map<String, String> headers,
  required Uint8List data,
  required FileOptions fileOptions,
  required MediaType contentType,
  void Function(int sent, int total)? onProgress,
}) async {
  final request = buildMultipartRequestFromBytes(
    uri: uri,
    headers: headers,
    data: data,
    fileOptions: fileOptions,
    contentType: contentType,
  );
  final bodyBytes = await request.finalize().toBytes();
  final totalBytes = bodyBytes.length;
  onProgress?.call(0, totalBytes > 0 ? totalBytes : 1);

  final xhr = XMLHttpRequest();
  xhr.open('POST', uri.toString(), true);
  xhr.responseType = 'arraybuffer';

  request.headers.forEach((name, value) {
    xhr.setRequestHeader(name, value);
  });

  final completer = Completer<String>();

  StreamSubscription<ProgressEvent>? progressSub;
  progressSub = EventStreamProviders.progressEvent.forTarget(xhr.upload).listen(
    (ProgressEvent e) {
      final t = e.lengthComputable && e.total > 0
          ? e.total
          : (totalBytes > 0 ? totalBytes : 1);
      final loaded = e.loaded.clamp(0, t);
      onProgress?.call(loaded, t);
    },
  );

  void cleanup() {
    unawaited(progressSub?.cancel());
  }

  unawaited(
    xhr.onLoad.first.then((_) {
      cleanup();
      if (completer.isCompleted) return;
      try {
        final status = xhr.status;
        final body = _xhrResponseBytes(xhr);
        final text = utf8.decode(body, allowMalformed: true);
        completer.complete(
          parseStorageUploadResponse(
            http.Response(text, status, reasonPhrase: xhr.statusText),
          ),
        );
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }),
  );

  unawaited(
    xhr.onError.first.then((_) {
      cleanup();
      if (!completer.isCompleted) {
        completer.completeError(
          StorageException('XMLHttpRequest error.', statusCode: '0'),
        );
      }
    }),
  );

  xhr.send(bodyBytes.toJS);

  try {
    return await completer.future;
  } finally {
    cleanup();
  }
}

Uint8List _xhrResponseBytes(XMLHttpRequest xhr) {
  final raw = xhr.response;
  if (raw == null) {
    return Uint8List.fromList(utf8.encode(xhr.responseText));
  }
  try {
    return (raw as JSArrayBuffer).toDart.asUint8List();
  } catch (_) {
    return Uint8List.fromList(utf8.encode(xhr.responseText));
  }
}
