import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/config/app_config.dart';
import 'package:point/Services/upload_cancel_token.dart';
import 'package:point/Services/upload_errors.dart';

/// Silent Firestore audit trail for upload failures (admin/supervisor read only).
class UploadDiagnostics {
  UploadDiagnostics._();

  static const _rateLimitWindow = Duration(seconds: 30);
  static DateTime? _lastLogAt;
  static String? _lastLogUid;

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static String _fileNameExt(String? fileName) {
    if (fileName == null || fileName.trim().isEmpty) return '.bin';
    final n = fileName.trim();
    final dot = n.lastIndexOf('.');
    if (dot < 0 || dot >= n.length - 1) return '.bin';
    final ext = n.substring(dot);
    return ext.length > 16 ? ext.substring(0, 16) : ext;
  }

  static bool _shouldSkipRateLimit(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    final lastAt = _lastLogAt;
    final lastUid = _lastLogUid;
    if (lastAt == null || lastUid != uid) return false;
    return DateTime.now().difference(lastAt) < _rateLimitWindow;
  }

  /// Non-blocking; never throws to callers. Skips [UploadCancelledException].
  static Future<void> logFailure({
    required Object error,
    required int fileSizeBytes,
    String? fileName,
    required int durationMs,
    String? context,
    String? employeeId,
  }) async {
    if (error is UploadCancelledException) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = currentUser?.uid;
      if (_shouldSkipRateLimit(uid)) return;

      final failure = error is UploadFailureException
          ? error
          : uploadFailureFromUnknown(error);

      if (failure.errorCode == 'cancelled') return;

      await FirebaseFirestore.instance.collection('upload_diagnostics').add({
        'createdAt': FieldValue.serverTimestamp(),
        if (uid != null) 'uid': uid,
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        'stage': failure.stage.name,
        'status': 'error',
        'errorCode': failure.errorCode,
        if (failure.httpStatus != null) 'httpStatus': failure.httpStatus,
        if (failure.message != null && failure.message!.isNotEmpty)
          'message': failure.message,
        'platform': _platformLabel(),
        'firebaseProjectId': AppConfig.firebaseProjectId,
        'fileSizeBytes': fileSizeBytes,
        'fileNameExt': _fileNameExt(fileName),
        'durationMs': durationMs,
        'source': 'flutter_app',
        if (context != null && context.isNotEmpty) 'context': context,
      });

      _lastLogAt = DateTime.now();
      _lastLogUid = uid;
    } catch (e, s) {
      appLog('UploadDiagnostics.logFailure failed: $e', error: e, stackTrace: s);
    }
  }
}
