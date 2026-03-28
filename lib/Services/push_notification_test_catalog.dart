/// أنواع الإشعارات المستخدمة في الاختبار (تطابق [NotificationService] والدردشة).
enum PushTestAudience {
  /// [FirestoreServices.sendFcm]
  employee,

  /// [FirestoreServices.sendFcmForClient]
  client,
}

class PushNotificationTestDefinition {
  const PushNotificationTestDefinition({
    required this.notificationType,
    required this.audience,
    required this.sortOrder,
    required this.categoryKey,
  });

  final String notificationType;
  final PushTestAudience audience;

  /// ترتيب المجموعات في القائمة (ثم حسب [notificationType] أبجدياً).
  final int sortOrder;

  /// مفتاح ترجمة للمجموعة — [AppLocaleKeys].
  final String categoryKey;
}

bool canOpenPushNotificationTester(String? role) {
  final r = (role ?? '').trim().toLowerCase();
  return r == 'admin' || r == 'supervisor';
}

/// كل قيم [notificationType] المعروفة في التطبيق (للاختبار اليدوي).
const List<PushNotificationTestDefinition> kPushNotificationTestCatalog =
    <PushNotificationTestDefinition>[
      PushNotificationTestDefinition(
        notificationType: 'chat_message',
        audience: PushTestAudience.employee,
        sortOrder: 10,
        categoryKey: 'push_test.category.chat',
      ),
      PushNotificationTestDefinition(
        notificationType: 'employee_task_assigned',
        audience: PushTestAudience.employee,
        sortOrder: 20,
        categoryKey: 'push_test.category.employee',
      ),
      PushNotificationTestDefinition(
        notificationType: 'employee_task_due_soon',
        audience: PushTestAudience.employee,
        sortOrder: 20,
        categoryKey: 'push_test.category.employee',
      ),
      PushNotificationTestDefinition(
        notificationType: 'employee_task_edit_requested',
        audience: PushTestAudience.employee,
        sortOrder: 20,
        categoryKey: 'push_test.category.employee',
      ),
      PushNotificationTestDefinition(
        notificationType: 'employee_task_rejected',
        audience: PushTestAudience.employee,
        sortOrder: 20,
        categoryKey: 'push_test.category.employee',
      ),
      PushNotificationTestDefinition(
        notificationType: 'employee_task_reopened',
        audience: PushTestAudience.employee,
        sortOrder: 20,
        categoryKey: 'push_test.category.employee',
      ),
      PushNotificationTestDefinition(
        notificationType: 'employee_task_new_attachments',
        audience: PushTestAudience.employee,
        sortOrder: 20,
        categoryKey: 'push_test.category.employee',
      ),
      PushNotificationTestDefinition(
        notificationType: 'employee_task_status_changed',
        audience: PushTestAudience.employee,
        sortOrder: 20,
        categoryKey: 'push_test.category.employee',
      ),
      PushNotificationTestDefinition(
        notificationType: 'manager_task_received',
        audience: PushTestAudience.employee,
        sortOrder: 30,
        categoryKey: 'push_test.category.manager',
      ),
      PushNotificationTestDefinition(
        notificationType: 'manager_task_completed',
        audience: PushTestAudience.employee,
        sortOrder: 30,
        categoryKey: 'push_test.category.manager',
      ),
      PushNotificationTestDefinition(
        notificationType: 'manager_task_edited',
        audience: PushTestAudience.employee,
        sortOrder: 30,
        categoryKey: 'push_test.category.manager',
      ),
      PushNotificationTestDefinition(
        notificationType: 'manager_task_comment',
        audience: PushTestAudience.employee,
        sortOrder: 30,
        categoryKey: 'push_test.category.manager',
      ),
      PushNotificationTestDefinition(
        notificationType: 'manager_content_submitted_by_client',
        audience: PushTestAudience.employee,
        sortOrder: 30,
        categoryKey: 'push_test.category.manager',
      ),
      PushNotificationTestDefinition(
        notificationType: 'manager_task_overdue',
        audience: PushTestAudience.employee,
        sortOrder: 30,
        categoryKey: 'push_test.category.manager',
      ),
      PushNotificationTestDefinition(
        notificationType: 'manager_new_task_department',
        audience: PushTestAudience.employee,
        sortOrder: 30,
        categoryKey: 'push_test.category.manager',
      ),
      PushNotificationTestDefinition(
        notificationType: 'manager_client_notes',
        audience: PushTestAudience.employee,
        sortOrder: 30,
        categoryKey: 'push_test.category.manager',
      ),
      PushNotificationTestDefinition(
        notificationType: 'manager_client_approved_content',
        audience: PushTestAudience.employee,
        sortOrder: 30,
        categoryKey: 'push_test.category.manager',
      ),
      PushNotificationTestDefinition(
        notificationType: 'client_content_pending_approval',
        audience: PushTestAudience.client,
        sortOrder: 40,
        categoryKey: 'push_test.category.client',
      ),
      PushNotificationTestDefinition(
        notificationType: 'client_pending_over_24h',
        audience: PushTestAudience.client,
        sortOrder: 40,
        categoryKey: 'push_test.category.client',
      ),
      PushNotificationTestDefinition(
        notificationType: 'client_approval_confirmed',
        audience: PushTestAudience.client,
        sortOrder: 40,
        categoryKey: 'push_test.category.client',
      ),
      PushNotificationTestDefinition(
        notificationType: 'client_edits_done',
        audience: PushTestAudience.client,
        sortOrder: 40,
        categoryKey: 'push_test.category.client',
      ),
      PushNotificationTestDefinition(
        notificationType: 'client_content_updated',
        audience: PushTestAudience.client,
        sortOrder: 40,
        categoryKey: 'push_test.category.client',
      ),
      PushNotificationTestDefinition(
        notificationType: 'client_content_scheduled',
        audience: PushTestAudience.client,
        sortOrder: 40,
        categoryKey: 'push_test.category.client',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_content_added',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_client_edit_request',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_client_approved',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_client_rejected',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_post_one_hour',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_post_not_confirmed_today',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_no_posts_tomorrow',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_post_published',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_link_added',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_notes_after_publish',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'publish_scheduled_cancelled',
        audience: PushTestAudience.employee,
        sortOrder: 50,
        categoryKey: 'push_test.category.publish',
      ),
      PushNotificationTestDefinition(
        notificationType: 'admin_promotion_status_changed',
        audience: PushTestAudience.employee,
        sortOrder: 60,
        categoryKey: 'push_test.category.admin_meta',
      ),
      PushNotificationTestDefinition(
        notificationType: 'admin_content_status_changed',
        audience: PushTestAudience.employee,
        sortOrder: 60,
        categoryKey: 'push_test.category.admin_meta',
      ),
      PushNotificationTestDefinition(
        notificationType: 'promotion_new_published_content',
        audience: PushTestAudience.employee,
        sortOrder: 60,
        categoryKey: 'push_test.category.admin_meta',
      ),
    ];

List<PushNotificationTestDefinition> sortedPushTestCatalog() {
  final copy = List<PushNotificationTestDefinition>.from(kPushNotificationTestCatalog);
  copy.sort((a, b) {
    final c = a.sortOrder.compareTo(b.sortOrder);
    if (c != 0) return c;
    return a.notificationType.compareTo(b.notificationType);
  });
  return copy;
}
