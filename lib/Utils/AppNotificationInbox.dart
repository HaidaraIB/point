import 'package:point/Models/NotificationModel.dart';

/// إشعار يظهر في صندوق التطبيق (ليس صف محادثة).
bool isAppInboxNotification(NotificationModel n) {
  return n.data?['type'] != 'message' && n.data?['type'] != 'chat';
}

/// غير مقروء للشارة والفلتر: أي قيمة غير [true] (بما فيها null من مستندات قديمة).
bool isInAppNotificationUnread(NotificationModel n) {
  return n.isRead != true;
}

int unreadInAppInboxCount(Iterable<NotificationModel> notifications) {
  return notifications
      .where(
        (n) => isAppInboxNotification(n) && isInAppNotificationUnread(n),
      )
      .length;
}
