/// سياسة إرسال **البريد** مقابل الاعتماد على **الدفع + صندوق الإشعارات** فقط.
///
/// - الأنواع غير المذكورة في [_pushOnlyNotificationTypes] تُرسل بريداً (سلوك آمن للأنواع الجديدة).
/// - الإشعارات المتكررة/التشغيلية → دفع فقط لتقليل الضجيج في البريد.
/// - الأحداث المهمّة (تعيين، رفض، موافقة عميل، تأخر خطير، …) → بريد + دفع.
class NotificationEmailPolicy {
  NotificationEmailPolicy._();

  /// أنواع لا يُرسل لها بريد (يُفترض أن يبقى الدفع + `notifications` داخل التطبيق).
  static const Set<String> _pushOnlyNotificationTypes = {
    // دردشة — حجم الرسائل كبير
    'chat_message',
    'chat_read',

    // موظف — تذكيرات زمنية متكررة لنفس المهمة
    'employee_task_due_soon',
    'employee_task_followup',
    'employee_task_due_soon_1h',
    'employee_task_start_reminder',
    'employee_task_stale_update',
    'employee_task_no_progress_yet',

    // موظف — عتبات تقدم (قد تتعدد في دفعة واحدة)
    'employee_progress_quarter',
    'employee_progress_half',
    'employee_progress_three_quarter',
    'employee_progress_finished',
    'employee_progress_reminder_0',
    'employee_progress_reminder_25',
    'employee_progress_reminder_50',
    'employee_progress_reminder_75_a',
    'employee_progress_reminder_75_b',
    'employee_progress_reminder_100',

    // موظف — تغيير حالة قد يتكرر
    'employee_task_status_changed',

    // إدارة — تحديثات صغيرة متكررة
    'manager_task_progress_updated',
    'manager_task_edited',

    // عميل — تذكير متكرر
    'client_pending_over_24h',
    'client_content_updated',

    // محتوى — إضافة / تقديم جديد (دفع + صندوق التطبيق فقط، بدون بريد)
    'manager_content_submitted_by_client',
    'client_content_pending_approval',
    'publish_content_added',

    // نشر — تنبيهات تشغيلية / تذكيرات
    'publish_post_one_hour',
    'publish_post_late',
    'publish_post_late_again',
    'publish_post_not_confirmed_today',
    'publish_no_posts_tomorrow',
    'publish_link_added',
    'publish_notes_after_publish',
  };

  /// `true` = إرسال بريد (إن وُجد عنوان)، `false` = دفع فقط.
  static bool shouldSendEmail(String? notificationType) {
    final t = notificationType?.trim() ?? '';
    if (t.isEmpty) return true;
    if (_pushOnlyNotificationTypes.contains(t)) return false;
    return true;
  }
}
