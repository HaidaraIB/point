import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:mime/mime.dart' show lookupMimeType;
import 'package:point/Services/r2_sign_request.dart';
import 'package:point/Services/upload_cancel_token.dart';
import 'package:point/Services/upload_errors.dart';
import 'package:web/web.dart';

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

  final xhr = XMLHttpRequest();
  xhr.open('PUT', sign.uploadUrl, true);
  xhr.responseType = 'arraybuffer';

  sign.headers.forEach((String name, String value) {
    xhr.setRequestHeader(name, value);
  });

  final uploadHost = Uri.tryParse(sign.uploadUrl)?.host ?? '(unknown)';

  final totalForProgress = data.length > 0 ? data.length : 1;
  onProgress?.call(0, totalForProgress);

  StreamSubscription<ProgressEvent>? progressSub;
  progressSub = EventStreamProviders.progressEvent.forTarget(xhr.upload).listen(
    (ProgressEvent e) {
      final t =
          e.lengthComputable && e.total > 0
              ? e.total
              : totalForProgress;
      final loaded = e.loaded.clamp(0, t);
      onProgress?.call(loaded, t);
    },
  );

  void cleanup() {
    unawaited(progressSub?.cancel());
  }

  final completer = Completer<String>();
  var abortedByUser = false;
  if (cancelToken != null) {
    cancelToken.onCancel = () {
      if (abortedByUser) return;
      abortedByUser = true;
      cleanup();
      xhr.abort();
      if (!completer.isCompleted) {
        completer.completeError(const UploadCancelledException());
      }
    };
  }

  unawaited(
    xhr.onLoad.first.then((_) {
      cleanup();
      if (completer.isCompleted) return;
      if (abortedByUser || cancelToken?.isCancelled == true) {
        completer.completeError(const UploadCancelledException());
        return;
      }
      final status = xhr.status;
      if (status >= 200 && status < 300) {
        completer.complete(sign.publicUrl);
      } else {
        final body = _xhrResponseText(xhr);
        completer.completeError(
          UploadFailureException(
            stage: UploadFailureStage.put,
            errorCode: 'http_$status',
            httpStatus: status,
            message: body.length > 500 ? '${body.substring(0, 500)}…' : body,
          ),
        );
      }
    }),
  );

  unawaited(
    xhr.onError.first.then((_) {
      cleanup();
      if (completer.isCompleted) return;
      if (abortedByUser || cancelToken?.isCancelled == true) {
        completer.completeError(const UploadCancelledException());
        return;
      }
      // status 0 = browser blocked cross-origin response (often R2 CORS) or real network failure.
      final st = xhr.status;
      final reason = xhr.statusText;
      completer.completeError(
        UploadFailureException(
          stage: UploadFailureStage.put,
          errorCode: st == 0 ? 'xhr_cors_or_network' : 'xhr_error',
          httpStatus: st,
          message:
              'R2 web upload failed (XHR error). status=$st reason=$reason. '
              'Target host: $uploadHost.',
        ),
      );
    }),
  );

  xhr.send(data.toJS);

  try {
    return await completer.future;
  } finally {
    cleanup();
  }
}

String _xhrResponseText(XMLHttpRequest xhr) {
  final raw = xhr.response;
  if (raw == null) {
    return xhr.responseText;
  }
  try {
    final bytes = (raw as JSArrayBuffer).toDart.asUint8List();
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return xhr.responseText;
  }
}
