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

  /// Diagnostics query focused on recent iOS-like failures.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  watchRecentIosPushFailures() {
    return FirebaseFirestore.instance
        .collection('push_diagnostics')
        .where('status', isEqualTo: 'error')
        .where('fcmErrorMessage', isGreaterThanOrEqualTo: 'A')
        .orderBy('fcmErrorMessage')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }
}
