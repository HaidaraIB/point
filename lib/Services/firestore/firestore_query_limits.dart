/// Firestore query caps to stay within Spark plan quotas.
class FirestoreQueryLimits {
  FirestoreQueryLimits._();

  static const int chatMessagesPage = 50;
  /// Max pinned rows fetched per open chat (typically 1–5; cheap vs full history).
  static const int pinnedMessages = 20;
  static const int employees = 200;
  static const int clients = 500;
  static const int contents = 500;
  static const int metaPosts = 500;
  static const int tasks = 500;
  static const int notifications = 50;
}
