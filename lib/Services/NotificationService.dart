import 'package:get/get.dart';
import 'package:point/Services/FireStoreServices.dart';

/// Centralized push/email notifications; copy follows current [Get.locale].
class NotificationService {
  NotificationService._();

  static Map<String, String> _emailLabels(Map<String, String> fields) => {
    for (final e in fields.entries) e.key.tr: e.value,
  };

  /// Task type index 0–6 → localized department name (cat1…cat7).
  static String departmentNameFromTaskType(String type) {
    final idx = int.tryParse(type);
    if (idx == null || idx < 0 || idx > 6) {
      return 'notify.department_unknown'.tr;
    }
    final key = 'cat${idx + 1}';
    return key.tr;
  }

  /// Content / task status storage key → localized label.
  static String statusLabelAr(String status) => status.tr;

  // ─── Employee notifications ─────────────────────────────────────────────

  static Future<void> notifyEmployeeAssignedToTask({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'notify.emp.assigned.title'.tr,
      body: taskTitle,
      notificationType: 'employee_task_assigned',
      actionText: 'notify.emp.assigned.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({'notify.email.task_title': taskTitle}),
    );
  }

  static Future<void> notifyTaskDueSoon({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'notify.emp.due_soon.title'.tr,
      body: 'notify.emp.due_soon.body'.trParams({'title': taskTitle}),
      notificationType: 'employee_task_due_soon',
      actionText: 'notify.emp.due_soon.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({'notify.email.task': taskTitle}),
    );
  }

  static Future<void> notifyEmployeeEditRequestedByManagement({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'notify.emp.edit_mgmt.title'.tr,
      body: taskTitle,
      notificationType: 'employee_task_edit_requested',
      actionText: 'notify.emp.edit_mgmt.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({'notify.email.task': taskTitle}),
    );
  }

  static Future<void> notifyEmployeeTaskRejected({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'notify.emp.rejected.title'.tr,
      body: 'notify.emp.rejected.body'.trParams({'title': taskTitle}),
      notificationType: 'employee_task_rejected',
      actionText: 'notify.emp.rejected.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({
        'notify.email.task': taskTitle,
        'notify.email.status': 'status_rejected'.tr,
      }),
    );
  }

  static Future<void> notifyEmployeeTaskReopened({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'notify.emp.reopened.title'.tr,
      body: taskTitle,
      notificationType: 'employee_task_reopened',
      actionText: 'notify.emp.reopened.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({
        'notify.email.task': taskTitle,
        'notify.email.status': 'notify.email.state_reopened'.tr,
      }),
    );
  }

  static Future<void> notifyEmployeeNewAttachments({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'notify.emp.attachments.title'.tr,
      body: taskTitle,
      notificationType: 'employee_task_new_attachments',
      actionText: 'notify.emp.attachments.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({'notify.email.task': taskTitle}),
    );
  }

  static Future<void> notifyEmployeeTaskStatusChanged({
    required String employeeId,
    required String taskTitle,
    required String newStatus,
  }) async {
    final label = statusLabelAr(newStatus);
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'notify.emp.status_changed.title'.tr,
      body: 'notify.emp.status_changed.body'
          .trParams({'title': taskTitle, 'label': label}),
      notificationType: 'employee_task_status_changed',
      actionText: 'notify.emp.status_changed.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({
        'notify.email.task': taskTitle,
        'notify.email.new_status': label,
      }),
    );
  }

  // ─── Manager / admin ─────────────────────────────────────────────────────

  static Future<void> notifyManagersTaskReceivedByEmployee({
    required String employeeName,
    required String taskTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.mgr.received.title'.tr,
      body: 'notify.mgr.received.body'
          .trParams({'name': employeeName, 'title': taskTitle}),
      notificationType: 'manager_task_received',
      actionText: 'notify.mgr.received.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({
        'notify.email.employee': employeeName,
        'notify.email.task': taskTitle,
      }),
    );
  }

  static Future<void> notifyManagersTaskCompletedByEmployee({
    required String employeeName,
    required String taskTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.mgr.completed.title'.tr,
      body: 'notify.mgr.completed.body'
          .trParams({'name': employeeName, 'title': taskTitle}),
      notificationType: 'manager_task_completed',
      actionText: 'notify.mgr.completed.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({
        'notify.email.employee': employeeName,
        'notify.email.task': taskTitle,
      }),
    );
  }

  static Future<void> notifyManagersEmployeeEditedTask({
    required String employeeName,
    required String taskTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.mgr.edited.title'.tr,
      body: 'notify.mgr.edited.body'
          .trParams({'name': employeeName, 'title': taskTitle}),
      notificationType: 'manager_task_edited',
      actionText: 'notify.mgr.edited.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({
        'notify.email.employee': employeeName,
        'notify.email.task': taskTitle,
      }),
    );
  }

  static Future<void> notifyManagersContentSubmittedByClient({
    required String clientName,
    required String contentTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.mgr.content_submitted.title'.tr,
      body: 'notify.mgr.content_submitted.body'
          .trParams({'name': clientName, 'title': contentTitle}),
      notificationType: 'manager_content_submitted_by_client',
      actionText: 'notify.mgr.content_submitted.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({
        'notify.email.client': clientName,
        'notify.email.content': contentTitle,
      }),
    );
  }

  static Future<void> notifyManagersTaskOverdue({
    required String taskTitle,
    required String employeeName,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.mgr.overdue.title'.tr,
      body: 'notify.mgr.overdue.body'
          .trParams({'title': taskTitle, 'name': employeeName}),
      notificationType: 'manager_task_overdue',
      actionText: 'notify.mgr.overdue.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({
        'notify.email.employee': employeeName,
        'notify.email.task': taskTitle,
      }),
    );
  }

  static Future<void> notifyManagersNewTaskInDepartment({
    required String taskTitle,
    required String departmentNameAr,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.mgr.new_task_dept.title'
          .trParams({'dept': departmentNameAr}),
      body: taskTitle,
      notificationType: 'manager_new_task_department',
      actionText: 'notify.mgr.new_task_dept.action'.tr,
      referenceId: taskTitle,
      emailDetails: _emailLabels({
        'notify.email.department': departmentNameAr,
        'notify.email.task': taskTitle,
      }),
    );
  }

  static Future<void> notifyManagersClientNotesOnContent({
    required String clientName,
    required String contentTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.mgr.client_notes.title'.tr,
      body: 'notify.mgr.client_notes.body'
          .trParams({'name': clientName, 'title': contentTitle}),
      notificationType: 'manager_client_notes',
      actionText: 'notify.mgr.client_notes.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({
        'notify.email.client': clientName,
        'notify.email.content': contentTitle,
      }),
    );
  }

  static Future<void> notifyManagersClientApprovedContent({
    required String clientName,
    required String contentTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.mgr.client_approved.title'.tr,
      body: 'notify.mgr.client_approved.body'
          .trParams({'name': clientName, 'title': contentTitle}),
      notificationType: 'manager_client_approved_content',
      actionText: 'notify.mgr.client_approved.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({
        'notify.email.client': clientName,
        'notify.email.content': contentTitle,
      }),
    );
  }

  // ─── Client ─────────────────────────────────────────────────────────────

  static Future<void> notifyClientContentPendingApproval({
    required String clientId,
    required String contentTypeLabel,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'notify.client.pending.title'.trParams({'type': contentTypeLabel}),
      body: 'notify.client.pending.body'.tr,
      notificationType: 'client_content_pending_approval',
      actionText: 'notify.client.pending.action'.tr,
      referenceId: contentTypeLabel,
      emailDetails: _emailLabels({
        'notify.email.content_type': contentTypeLabel,
      }),
    );
  }

  static Future<void> notifyClientContentPendingOver24h({
    required String clientId,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'notify.client.pending_24h.title'.tr,
      body: contentTitle,
      notificationType: 'client_pending_over_24h',
      actionText: 'notify.client.pending_24h.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({'notify.email.content': contentTitle}),
    );
  }

  static Future<void> notifyClientApprovalConfirmed({
    required String clientId,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'notify.client.approval_confirmed.title'.tr,
      body: 'notify.client.approval_confirmed.body'.tr,
      notificationType: 'client_approval_confirmed',
      actionText: 'notify.client.approval_confirmed.action'.tr,
      referenceId: clientId,
      emailDetails: _emailLabels({
        'notify.email.status':
            'notify.client.approval_confirmed.email_status'.tr,
      }),
    );
  }

  static Future<void> notifyClientEditsDone({
    required String clientId,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'notify.client.edits_done.title'.tr,
      body: contentTitle,
      notificationType: 'client_edits_done',
      actionText: 'notify.client.edits_done.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({'notify.email.content': contentTitle}),
    );
  }

  static Future<void> notifyClientContentUpdatedForApproval({
    required String clientId,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'notify.client.updated.title'.tr,
      body: contentTitle,
      notificationType: 'client_content_updated',
      actionText: 'notify.client.updated.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({'notify.email.content': contentTitle}),
    );
  }

  static Future<void> notifyClientContentScheduled({
    required String clientId,
    required String contentTitle,
    required String dateFormatted,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'notify.client.scheduled.title'
          .trParams({'date': dateFormatted}),
      body: contentTitle,
      notificationType: 'client_content_scheduled',
      actionText: 'notify.client.scheduled.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({
        'notify.email.content': contentTitle,
        'notify.email.publish_date': dateFormatted,
      }),
    );
  }

  // ─── Publishing department ──────────────────────────────────────────────

  static Future<void> notifyPublishDeptContentAdded({
    required String clientName,
    required String platformLabel,
    required String dateFormatted,
    required String timeFormatted,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment('cat6');
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      title: 'notify.publish.added.title'.tr,
      body: 'notify.publish.added.body'.trParams({
        'client': clientName,
        'platform': platformLabel,
        'date': dateFormatted,
        'time': timeFormatted,
      }),
      notificationType: 'publish_content_added',
      actionText: 'notify.publish.added.action'.tr,
      referenceId: clientName,
      emailDetails: _emailLabels({
        'notify.email.client': clientName,
        'notify.email.platform': platformLabel,
        'notify.email.date': dateFormatted,
        'notify.email.time': timeFormatted,
      }),
    );
  }

  static Future<void> notifyPublishDeptClientEditRequest({
    required String contentTitle,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment('cat6');
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      title: 'notify.publish.edit_req.title'.tr,
      body: contentTitle,
      notificationType: 'publish_client_edit_request',
      actionText: 'notify.publish.edit_req.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({'notify.email.content': contentTitle}),
    );
  }

  static Future<void> notifyPublishDeptClientApproved({
    required String clientName,
    required String contentTitle,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment('cat6');
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      title: 'notify.publish.approved.title'.tr,
      body: 'notify.publish.approved.body'
          .trParams({'name': clientName, 'title': contentTitle}),
      notificationType: 'publish_client_approved',
      actionText: 'notify.publish.approved.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({
        'notify.email.client': clientName,
        'notify.email.content': contentTitle,
      }),
    );
  }

  static Future<void> notifyPublishDeptClientRejected({
    required String contentTitle,
    required String clientName,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment('cat6');
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      title: 'notify.publish.rejected.title'.tr,
      body: 'notify.publish.rejected.body'
          .trParams({'title': contentTitle, 'name': clientName}),
      notificationType: 'publish_client_rejected',
      actionText: 'notify.publish.rejected.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({
        'notify.email.client': clientName,
        'notify.email.content': contentTitle,
      }),
    );
  }

  static Future<void> notifyPublishDeptPostInOneHour({
    required String employeeId,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'notify.publish.one_hour.title'.tr,
      body: contentTitle,
      notificationType: 'publish_post_one_hour',
      actionText: 'notify.publish.one_hour.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({'notify.email.post': contentTitle}),
    );
  }

  static Future<void> notifyPublishDeptPostScheduledTodayNotConfirmed({
    required String employeeId,
    required String contentRef,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'notify.publish.today_not_confirmed.title'.tr,
      body: 'notify.publish.today_not_confirmed.body'
          .trParams({'ref': contentRef}),
      notificationType: 'publish_post_not_confirmed_today',
      actionText: 'notify.publish.today_not_confirmed.action'.tr,
      referenceId: contentRef,
      emailDetails: _emailLabels({'notify.email.reference': contentRef}),
    );
  }

  static Future<void> notifyPublishDeptNoPostsTomorrow({
    required String employeeId,
    required String clientName,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'notify.publish.no_posts_tomorrow.title'.tr,
      body: 'notify.publish.no_posts_tomorrow.body'
          .trParams({'name': clientName}),
      notificationType: 'publish_no_posts_tomorrow',
      actionText: 'notify.publish.no_posts_tomorrow.action'.tr,
      referenceId: clientName,
      emailDetails: _emailLabels({'notify.email.client': clientName}),
    );
  }

  static Future<void> notifyPublishDeptPostPublished({
    required List<String> recipientIds,
    required String platformLabel,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      title: 'notify.publish.published.title'
          .trParams({'platform': platformLabel}),
      body: contentTitle,
      notificationType: 'publish_post_published',
      actionText: 'notify.publish.published.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({
        'notify.email.platform': platformLabel,
        'notify.email.content': contentTitle,
      }),
    );
  }

  static Future<void> notifyPublishDeptLinkAdded({
    required List<String> recipientIds,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      title: 'notify.publish.link_added.title'.tr,
      body: contentTitle,
      notificationType: 'publish_link_added',
      actionText: 'notify.publish.link_added.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({'notify.email.content': contentTitle}),
    );
  }

  static Future<void> notifyPublishDeptNotesAfterPublish({
    required List<String> recipientIds,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      title: 'notify.publish.notes_after.title'.tr,
      body: contentTitle,
      notificationType: 'publish_notes_after_publish',
      actionText: 'notify.publish.notes_after.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({'notify.email.content': contentTitle}),
    );
  }

  static Future<void> notifyPublishDeptScheduledCancelled({
    required List<String> recipientIds,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      title: 'notify.publish.cancelled.title'.tr,
      body: contentTitle,
      notificationType: 'publish_scheduled_cancelled',
      actionText: 'notify.publish.cancelled.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({'notify.email.content': contentTitle}),
    );
  }

  // ─── Promotion / admin ───────────────────────────────────────────────────

  static Future<void> notifyAdminContentPromotionStatusChanged({
    required String contentTitle,
    required String promotionLabelAr,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(['admin']);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.admin.promo_changed.title'.tr,
      body: 'notify.admin.promo_changed.body'
          .trParams({'title': contentTitle, 'label': promotionLabelAr}),
      notificationType: 'admin_promotion_status_changed',
      actionText: 'notify.admin.promo_changed.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({
        'notify.email.content': contentTitle,
        'notify.email.status': promotionLabelAr,
      }),
    );
  }

  static Future<void> notifyAdminContentStatusChanged({
    required String contentTitle,
    required String statusLabelAr,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(['admin']);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.admin.status_changed.title'.tr,
      body: 'notify.admin.status_changed.body'
          .trParams({'title': contentTitle, 'label': statusLabelAr}),
      notificationType: 'admin_content_status_changed',
      actionText: 'notify.admin.status_changed.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({
        'notify.email.content': contentTitle,
        'notify.email.status': statusLabelAr,
      }),
    );
  }

  static Future<void> notifyPromotionDeptNewPublishedContent({
    required String clientName,
    required String contentTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByDepartment('cat1');
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'notify.promo.new_published.title'.tr,
      body: 'notify.promo.new_published.body'
          .trParams({'name': clientName, 'title': contentTitle}),
      notificationType: 'promotion_new_published_content',
      actionText: 'notify.promo.new_published.action'.tr,
      referenceId: contentTitle,
      emailDetails: _emailLabels({
        'notify.email.client': clientName,
        'notify.email.content': contentTitle,
      }),
    );
  }
}
