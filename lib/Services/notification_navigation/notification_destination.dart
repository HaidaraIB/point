/// Closed set of screens a push / inbox tap may open. No arbitrary routes.
enum NotificationDestinationKind {
  chat,
  chatList,
  task,
  content,
  publish,
  attendance,
  home,
}

/// Parsed navigation target from FCM / local-notification / inbox `data`.
class NotificationDestination {
  const NotificationDestination({
    required this.kind,
    required this.notificationType,
    this.taskId,
    this.taskType,
    this.contentId,
    this.chatId,
    this.chatTitle,
    this.isGroup,
  });

  final NotificationDestinationKind kind;
  final String notificationType;
  final String? taskId;
  final String? taskType;
  final String? contentId;
  final String? chatId;
  final String? chatTitle;
  final bool? isGroup;

  String get entityKey {
    switch (kind) {
      case NotificationDestinationKind.chat:
        return 'chat:${chatId ?? ''}';
      case NotificationDestinationKind.task:
        return 'task:${taskId ?? ''}';
      case NotificationDestinationKind.content:
      case NotificationDestinationKind.publish:
        return 'content:${contentId ?? ''}';
      case NotificationDestinationKind.chatList:
        return 'chatList';
      case NotificationDestinationKind.attendance:
        return 'attendance';
      case NotificationDestinationKind.home:
        return 'home';
    }
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationDestination &&
        other.kind == kind &&
        other.notificationType == notificationType &&
        other.taskId == taskId &&
        other.taskType == taskType &&
        other.contentId == contentId &&
        other.chatId == chatId &&
        other.chatTitle == chatTitle &&
        other.isGroup == isGroup;
  }

  @override
  int get hashCode => Object.hash(
    kind,
    notificationType,
    taskId,
    taskType,
    contentId,
    chatId,
    chatTitle,
    isGroup,
  );
}

/// FCM `data` keys for deep-link extras (all string values).
class NotificationNavKeys {
  NotificationNavKeys._();

  static const taskId = 'taskId';
  static const taskType = 'taskType';
  static const contentId = 'contentId';
  static const chatId = 'chatId';
  static const chatTitle = 'chatTitle';
  static const isGroup = 'isGroup';
  static const notificationType = 'notificationType';
}

Map<String, String> notificationTaskExtras({
  required String? taskId,
  String? taskType,
}) {
  final m = <String, String>{};
  final id = taskId?.trim() ?? '';
  if (id.isNotEmpty) m[NotificationNavKeys.taskId] = id;
  final type = taskType?.trim() ?? '';
  if (type.isNotEmpty) m[NotificationNavKeys.taskType] = type;
  return m;
}

Map<String, String> notificationContentExtras(String? contentId) {
  final id = contentId?.trim() ?? '';
  if (id.isEmpty) return const <String, String>{};
  return <String, String>{NotificationNavKeys.contentId: id};
}
