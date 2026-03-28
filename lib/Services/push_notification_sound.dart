/// أسماء موارد الصوت في [android/app/src/main/res/raw] وملفات iOS في حزمة Runner (بدون مسار).
const List<String> kPushCustomSoundBases = <String>[
  'notification_chat',
  'notification_task_preview',
  'notification_task_comment',
  'notification_content_status',
  'notification_content_scheduled',
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
    // Employee — task
    'employee_task_assigned': 'notification_task_preview',
    'employee_task_due_soon': 'notification_task_deadline_soon',
    'employee_task_edit_requested': 'notification_task_comment',
    'employee_task_rejected': 'notification_content_status',
    'employee_task_reopened': 'notification_task_comment',
    'employee_task_new_attachments': 'notification_task_comment',
    'employee_task_status_changed': 'notification_content_status',
    // Manager
    'manager_task_received': 'notification_task_preview',
    'manager_task_completed': 'notification_task_preview',
    'admin_supervisor_escalated_task': 'notification_task_preview',
    'manager_task_edited': 'notification_task_comment',
    'manager_task_comment': 'notification_task_comment',
    'manager_content_submitted_by_client': 'notification_content_status',
    'manager_task_overdue': 'notification_task_deadline',
    'manager_new_task_department': 'notification_task_preview',
    'manager_client_notes': 'notification_task_comment',
    'manager_client_approved_content': 'notification_task_approved',
    // Client app
    'client_content_pending_approval': 'notification_content_status',
    'client_pending_over_24h': 'notification_task_deadline_soon',
    'client_approval_confirmed': 'notification_task_approved',
    'client_edits_done': 'notification_task_comment',
    'client_content_updated': 'notification_content_status',
    'client_content_scheduled': 'notification_content_scheduled',
    // Publishing
    'publish_content_added': 'notification_content_status',
    'publish_client_edit_request': 'notification_task_comment',
    'publish_client_approved': 'notification_task_approved',
    'publish_client_rejected': 'notification_content_status',
    'publish_post_one_hour': 'notification_content_scheduled',
    'publish_post_not_confirmed_today': 'notification_content_scheduled',
    'publish_no_posts_tomorrow': 'notification_task_deadline_soon',
    'publish_post_published': 'notification_promotion_status',
    'publish_link_added': 'notification_task_comment',
    'publish_notes_after_publish': 'notification_task_comment',
    'publish_scheduled_cancelled': 'notification_content_scheduled',
    // Admin / promotion
    'admin_promotion_status_changed': 'notification_promotion_status',
    'admin_content_status_changed': 'notification_content_status',
    'promotion_new_published_content': 'notification_promotion_status',
    'broadcast_topic': 'notification_task_preview',
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
