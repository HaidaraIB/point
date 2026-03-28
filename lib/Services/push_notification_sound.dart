/// أسماء موارد الصوت في [android/app/src/main/res/raw] وملفات iOS في حزمة Runner (بدون مسار).
const List<String> kPushCustomSoundBases = <String>[
  'notification_chat',
  'notification_task_preview',
  'notification_task_comment',
  'notification_content_status',
  'notification_promotion_status',
  'notification_task_deadline_soon',
  'notification_task_deadline',
  'notification_task_approved',
];

const String kPushDefaultChannelId = 'point_default';

/// يطابق منطق [supabase/functions/send-fcm/index.ts].
String? pushSoundBaseForNotificationType(String? notificationType) {
  if (notificationType == null) return null;
  final t = notificationType.trim();
  if (t.isEmpty) return null;
  const map = <String, String>{
    'chat_message': 'notification_chat',
    'manager_task_completed': 'notification_task_preview',
    'manager_task_comment': 'notification_task_comment',
    'admin_content_status_changed': 'notification_content_status',
    'admin_promotion_status_changed': 'notification_promotion_status',
    'promotion_new_published_content': 'notification_promotion_status',
    'employee_task_due_soon': 'notification_task_deadline_soon',
    'manager_task_overdue': 'notification_task_deadline',
    'client_approval_confirmed': 'notification_task_approved',
    'publish_client_approved': 'notification_task_approved',
    'manager_client_approved_content': 'notification_task_approved',
  };
  return map[t];
}

String pushChannelIdForSoundBase(String? soundBase) {
  if (soundBase == null || soundBase.isEmpty) return kPushDefaultChannelId;
  return 'point_sound_$soundBase';
}

/// صوت iOS: اسم الملف كما في Copy Bundle Resources.
String? iosPushSoundFile(String? soundBase) {
  if (soundBase == null || soundBase.isEmpty) return null;
  return '$soundBase.wav';
}
