import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/NotificationModel.dart';

/// عمليات إشعارات داخل التطبيق (مجموعة [notifications]).
class FirestoreNotificationApi {
  FirestoreNotificationApi._();

  static Future<void> addNotification(NotificationModel model) async {
    final data = Map<String, dynamic>.from(model.toJson())..remove('id');
    data['isRead'] = model.isRead ?? false;
    await FirebaseFirestore.instance.collection('notifications').add(data);
  }

  /// يضع [isRead] = true لمجموعة مستندات الإشعارات (دُفعات 450 لتفادي حد الـ batch).
  static Future<void> markInAppNotificationsAsRead(
    Iterable<String> docIds,
  ) async {
    final ids = docIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return;
    final coll = FirebaseFirestore.instance.collection('notifications');
    const chunkSize = 450;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in ids.skip(i).take(chunkSize)) {
        batch.update(coll.doc(id), {'isRead': true});
      }
      await batch.commit();
    }
  }

  /// Delete in-app notifications by Firestore document ids.
  ///
  /// Uses chunking to stay under Firestore batch limits.
  static Future<void> deleteInAppNotifications(Iterable<String> docIds) async {
    final ids = docIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return;
    final coll = FirebaseFirestore.instance.collection('notifications');
    const chunkSize = 450;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in ids.skip(i).take(chunkSize)) {
        batch.delete(coll.doc(id));
      }
      await batch.commit();
    }
  }
}
