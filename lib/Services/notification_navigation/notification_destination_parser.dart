import 'package:point/Services/notification_navigation/notification_destination.dart';

/// Pure mapper: FCM / inbox `data` → [NotificationDestination].
///
/// Returns `null` for silent-sync pushes and unknown types (open app only).
class NotificationDestinationParser {
  NotificationDestinationParser._();

  static NotificationDestination? parse(Map<dynamic, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return null;
    final data = <String, String>{};
    for (final e in raw.entries) {
      final k = e.key?.toString().trim() ?? '';
      if (k.isEmpty) continue;
      data[k] = e.value?.toString() ?? '';
    }
    return parseStringMap(data);
  }

  static NotificationDestination? parseStringMap(Map<String, String> data) {
    if (_isSilentPush(data)) return null;

    final notificationType =
        (_ciGet(data, 'notificationType') ??
                _ciGet(data, 'notification_type') ??
                '')
            .trim();
    final legacyType = (_ciGet(data, 'type') ?? '').trim();
    final isChatMessage =
        notificationType == 'chat_message' || legacyType == 'chat_message';

    final chatId = (_ciGet(data, 'chatId') ?? _ciGet(data, 'chat_id'))?.trim();
    final taskId =
        (_ciGet(data, NotificationNavKeys.taskId) ?? _ciGet(data, 'task_id'))
            ?.trim();
    final taskType =
        (_ciGet(data, NotificationNavKeys.taskType) ??
                _ciGet(data, 'task_type'))
            ?.trim();
    final contentId =
        (_ciGet(data, NotificationNavKeys.contentId) ??
                _ciGet(data, 'content_id'))
            ?.trim();
    final chatTitle =
        (_ciGet(data, NotificationNavKeys.chatTitle) ??
                _ciGet(data, 'chatDisplayName') ??
                _ciGet(data, 'chat_title'))
            ?.trim();
    final isGroup = _parseIsGroup(data);

    if (isChatMessage) {
      final id = (chatId == null || chatId.isEmpty) ? null : chatId;
      return NotificationDestination(
        kind: id == null
            ? NotificationDestinationKind.chatList
            : NotificationDestinationKind.chat,
        notificationType: notificationType.isEmpty
            ? 'chat_message'
            : notificationType,
        chatId: id,
        chatTitle: _emptyToNull(chatTitle),
        isGroup: isGroup,
      );
    }

    if (notificationType.isEmpty) return null;

    final kind = kindForNotificationType(notificationType);
    if (kind == null) return null;

    return NotificationDestination(
      kind: kind,
      notificationType: notificationType,
      taskId: _emptyToNull(taskId),
      taskType: _emptyToNull(taskType),
      contentId: _emptyToNull(contentId),
      chatId: _emptyToNull(chatId),
      chatTitle: _emptyToNull(chatTitle),
      isGroup: isGroup,
    );
  }

  /// Public for tests: type string → destination kind (list fallback when no id).
  static NotificationDestinationKind? kindForNotificationType(String type) {
    final t = type.trim();
    if (t.isEmpty) return null;
    if (t == 'chat_message') return NotificationDestinationKind.chat;
    if (t == 'chat_unread_digest') return NotificationDestinationKind.chatList;
    if (t.startsWith('employee_attendance_') ||
        t.startsWith('manager_attendance_')) {
      return NotificationDestinationKind.attendance;
    }
    if (t.startsWith('publish_')) return NotificationDestinationKind.publish;
    if (t.startsWith('client_') ||
        t.startsWith('manager_content_') ||
        t.startsWith('manager_client_') ||
        t == 'admin_promotion_status_changed' ||
        t == 'admin_content_status_changed' ||
        t == 'promotion_new_published_content') {
      return NotificationDestinationKind.content;
    }
    if (t.startsWith('employee_task_') ||
        t.startsWith('manager_task_') ||
        t.startsWith('employee_progress_') ||
        t.startsWith('employee_deadline_') ||
        t.startsWith('manager_deadline_') ||
        t == 'manager_new_task_department' ||
        t == 'admin_supervisor_escalated_task') {
      return NotificationDestinationKind.task;
    }
    if (t == 'broadcast_topic') return NotificationDestinationKind.home;
    return null;
  }

  static bool _isSilentPush(Map<String, String> data) {
    final v = _ciGet(data, 'silentSync') ?? _ciGet(data, 'fcmSilentSync');
    if (v == null) return false;
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  static String? _ciGet(Map<String, String> data, String key) {
    final want = key.toLowerCase();
    for (final e in data.entries) {
      if (e.key.toLowerCase() == want) {
        final v = e.value.trim();
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }

  static bool? _parseIsGroup(Map<String, String> data) {
    final v =
        _ciGet(data, NotificationNavKeys.isGroup) ?? _ciGet(data, 'is_group');
    if (v == null) return null;
    final s = v.trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return null;
  }

  static String? _emptyToNull(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}
