import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Utils/app_log.dart';

/// Silent Firestore audit trail for push/FCM failures (manager read only).
class PushDiagnostics {
  PushDiagnostics._();

  /// Non-blocking; never throws to callers. Only writes [status] == `error`.
  static Future<void> logFailure({
    required String requestId,
    required String stage,
    required String targetType,
    String? recipientId,
    String? recipientType,
    String? tokenMasked,
    String? topic,
    String? title,
    int? bodyLen,
    String? notificationType,
    int? fcmHttpStatus,
    String? fcmErrorCode,
    String? fcmErrorStatus,
    String? fcmErrorMessage,
    Object? details,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('push_diagnostics').add({
        'createdAt': FieldValue.serverTimestamp(),
        'requestId': requestId,
        'stage': stage,
        'status': 'error',
        'targetType': targetType,
        if (currentUser?.uid != null) 'senderUid': currentUser!.uid,
        if (recipientId != null) 'recipientId': recipientId,
        if (recipientType != null) 'recipientType': recipientType,
        if (tokenMasked != null) 'tokenMasked': tokenMasked,
        if (topic != null) 'topic': topic,
        if (title != null) 'title': title,
        'bodyLen': bodyLen ?? 0,
        if (notificationType != null) 'notificationType': notificationType,
        if (fcmHttpStatus != null) 'fcmHttpStatus': fcmHttpStatus,
        if (fcmErrorCode != null) 'fcmErrorCode': fcmErrorCode,
        if (fcmErrorStatus != null) 'fcmErrorStatus': fcmErrorStatus,
        if (fcmErrorMessage != null) 'fcmErrorMessage': fcmErrorMessage,
        if (details != null) 'details': details.toString(),
        'source': 'flutter_app',
      });
    } catch (e, s) {
      appLog('PushDiagnostics.logFailure failed: $e', error: e, stackTrace: s);
    }
  }
}
