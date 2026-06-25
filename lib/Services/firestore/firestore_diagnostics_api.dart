import 'package:cloud_firestore/cloud_firestore.dart';

/// استعلامات تشخيص FCM (مجموعة [push_diagnostics]).
class FirestoreDiagnosticsApi {
  FirestoreDiagnosticsApi._();

  /// Diagnostics query by request id.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  watchPushDiagnosticsByRequestId(String requestId) {
    return FirebaseFirestore.instance
        .collection('push_diagnostics')
        .where('requestId', isEqualTo: requestId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Diagnostics query by recipient user id.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  watchPushDiagnosticsByRecipient(String recipientId) {
    return FirebaseFirestore.instance
        .collection('push_diagnostics')
        .where('recipientId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  /// Diagnostics query focused on recent push failures.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  watchRecentPushFailures({int limit = 200}) {
    return FirebaseFirestore.instance
        .collection('push_diagnostics')
        .where('status', isEqualTo: 'error')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Recent upload failures (manager/admin read via rules).
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  watchRecentUploadFailures({int limit = 200}) {
    return FirebaseFirestore.instance
        .collection('upload_diagnostics')
        .where('status', isEqualTo: 'error')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Upload failures for a specific user id.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  watchUploadFailuresByUid(String uid, {int limit = 100}) {
    return FirebaseFirestore.instance
        .collection('upload_diagnostics')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
