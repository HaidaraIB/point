import 'package:point/Models/NotificationModel.dart';

/// إشعار يظهر في صندوق التطبيق (ليس صف محادثة).
bool isAppInboxNotification(NotificationModel n) {
  if (n.data?['type'] == 'message' || n.data?['type'] == 'chat') {
    return false;
  }
  if (n.data?['notificationType']?.toString().trim() == 'chat_message') {
    return false;
  }
  return true;
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
