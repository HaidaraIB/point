import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:point/Services/upload_cancel_token.dart';

/// Where an R2 upload failed: presign worker vs direct PUT to R2.
enum UploadFailureStage {
  sign,
  put,
}

/// Structured upload failure for diagnostics (never shown verbatim to users).
class UploadFailureException implements Exception {
  const UploadFailureException({
    required this.stage,
    required this.errorCode,
    this.httpStatus,
    this.message,
  });

  final UploadFailureStage stage;
  final String errorCode;
  final int? httpStatus;
  final String? message;

  @override
  String toString() {
    final status = httpStatus != null ? ' HTTP $httpStatus' : '';
    final detail = message != null && message!.isNotEmpty ? ': $message' : '';
    return 'UploadFailureException(${stage.name}/$errorCode$status$detail)';
  }
}

/// True for presign failures that may succeed on a single retry (Wi‑Fi handoff, etc.).
bool isTransientNetworkUploadFailure(UploadFailureException error) {
  return error.stage == UploadFailureStage.sign &&
      (error.errorCode == 'network_unreachable' ||
          error.errorCode == 'network_error' ||
          error.errorCode == 'network_timeout');
}

/// Maps [SocketException], [ClientException], [TimeoutException], etc. to sign-stage codes.
UploadFailureException? tryUploadFailureFromNetworkError(
  Object error, {
  UploadFailureStage stage = UploadFailureStage.sign,
}) {
  if (error is UploadFailureException) return error;
  if (error is TimeoutException) {
    return UploadFailureException(
      stage: stage,
      errorCode: 'network_timeout',
      message: _truncateSafe(error.toString()),
    );
  }
  if (error is http.ClientException) {
    return _networkFailureFromText(error.toString(), stage: stage);
  }
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Network is unreachable') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset')) {
    return _networkFailureFromText(text, stage: stage);
  }
  return null;
}

UploadFailureException uploadFailureFromNetworkError(
  Object error, {
  UploadFailureStage stage = UploadFailureStage.sign,
}) {
  return tryUploadFailureFromNetworkError(error, stage: stage) ??
      UploadFailureException(
        stage: stage,
        errorCode: 'network_error',
        message: _truncateSafe(error.toString()),
      );
}

UploadFailureException _networkFailureFromText(
  String text, {
  required UploadFailureStage stage,
}) {
  if (text.contains('errno = 101') ||
      text.contains('Network is unreachable') ||
      text.contains('ENETUNREACH')) {
    return UploadFailureException(
      stage: stage,
      errorCode: 'network_unreachable',
      message: _truncateSafe(text),
    );
  }
  if (text.contains('TimeoutException') ||
      text.contains('timed out') ||
      text.contains('Timeout')) {
    return UploadFailureException(
      stage: stage,
      errorCode: 'network_timeout',
      message: _truncateSafe(text),
    );
  }
  return UploadFailureException(
    stage: stage,
    errorCode: 'network_error',
    message: _truncateSafe(text),
  );
}

UploadFailureException uploadFailureFromPutError(Object error) {
  if (error is UploadFailureException) return error;

  final network = tryUploadFailureFromNetworkError(
    error,
    stage: UploadFailureStage.put,
  );
  if (network != null) return network;

  final text = error.toString();
  final httpMatch = RegExp(r'HTTP (\d{3})').firstMatch(text);
  final httpStatus = httpMatch != null ? int.tryParse(httpMatch.group(1)!) : null;

  if (text.contains('status=0') || text.contains('XHR error')) {
    return UploadFailureException(
      stage: UploadFailureStage.put,
      errorCode: 'xhr_error',
      httpStatus: httpStatus ?? 0,
      message: _truncateSafe(text),
    );
  }

  if (httpStatus != null) {
    return UploadFailureException(
      stage: UploadFailureStage.put,
      errorCode: 'http_$httpStatus',
      httpStatus: httpStatus,
      message: _truncateSafe(text),
    );
  }

  return UploadFailureException(
    stage: UploadFailureStage.put,
    errorCode: 'put_failed',
    message: _truncateSafe(text),
  );
}

UploadFailureException uploadFailureFromUnknown(Object error) {
  if (error is UploadFailureException) return error;
  if (error is UploadCancelledException) {
    return const UploadFailureException(
      stage: UploadFailureStage.put,
      errorCode: 'cancelled',
    );
  }

  final network = tryUploadFailureFromNetworkError(error);
  if (network != null) return network;

  final text = error.toString();
  if (text.contains('R2') || text.contains('HTTP')) {
    return uploadFailureFromPutError(error);
  }

  return UploadFailureException(
    stage: UploadFailureStage.put,
    errorCode: 'unknown',
    message: _truncateSafe(text),
  );
}

String _truncateSafe(String raw, {int maxLen = 500}) {
  var s = raw.replaceAll(
    RegExp(r'Bearer\s+\S+', caseSensitive: false),
    'Bearer ***',
  );
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen)}…';
}
