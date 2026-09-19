import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/notify_locale.dart';
import 'package:point/Services/notification_email_fields.dart';
import 'package:point/Services/notification_email_policy.dart';
import 'package:point/Services/push_notification_test_catalog.dart';

/// Sample notification email copy for previews (Email Hub, push tester).
class AppNotificationEmailSample {
  const AppNotificationEmailSample({
    required this.notificationType,
    required this.title,
    required this.body,
    this.actionText,
    this.emailDetails,
  });

  final String notificationType;
  final String title;
  final String body;
  final String? actionText;
  final Map<String, String>? emailDetails;
}

class AppNotificationEmailSamples {
  AppNotificationEmailSamples._();

  static const _sampleParams = <String, String>{
    'title': 'مهمة تجريبية',
    'name': 'الموظف',
    'label': 'مكتملة',
    'by': 'الموظف',
    'pct': '50',
    'client': 'العميل',
    'platform': 'Instagram',
    'date': '2026-04-27',
    'time': '10:00',
    'ref': 'REF-1001',
    'dept': 'التصميم',
    'type': 'محتوى',
    'supervisor': 'المشرف',
    'period': '2026-04',
    'amount': '1,000,000 د.ع',
    'advance': '100,000 د.ع',
    'action': 'حضور',
  };

  static const _prefixByType = <String, String>{
    'chat_unread_digest': 'notify.emp.new_comment',
    'employee_task_assigned': 'notify.emp.assigned',
    'employee_task_due_soon': 'notify.emp.due_soon',
    'employee_task_edit_requested': 'notify.emp.edit_mgmt',
    'employee_task_rejected': 'notify.emp.rejected',
    'employee_task_reopened': 'notify.emp.reopened',
    'employee_task_new_attachments': 'notify.emp.attachments',
    'employee_task_new_comment': 'notify.emp.new_comment',
    'employee_task_status_changed': 'notify.emp.status_changed',
    'employee_task_start_reminder': 'notify.emp.start_reminder',
    'employee_task_stale_update': 'notify.emp.stale_update',
    'employee_task_followup': 'notify.emp.followup',
    'employee_task_overdue': 'notify.emp.overdue',
    'employee_task_due_soon_1h': 'notify.emp.due_soon_1h',
    'employee_task_no_progress_yet': 'notify.emp.no_progress_yet',
    'employee_progress_quarter': 'notify.emp.milestone.on_track',
    'employee_progress_half': 'notify.emp.milestone.halfway',
    'employee_progress_three_quarter': 'notify.emp.milestone.near_end',
    'employee_progress_finished': 'notify.emp.milestone.finished',
    'employee_progress_reminder_0': 'notify.emp.no_progress_yet',
    'employee_progress_reminder_25': 'notify.emp.milestone.on_track',
    'employee_progress_reminder_50': 'notify.emp.milestone.halfway',
    'employee_progress_reminder_75_a': 'notify.emp.milestone.near_end',
    'employee_progress_reminder_75_b': 'notify.emp.milestone.near_end',
    'employee_progress_reminder_100': 'notify.emp.milestone.finished',
    'employee_attendance_check_in': '_attendance_check_in',
    'employee_attendance_check_out': '_attendance_check_out',
    'employee_deadline_extension_approved': 'notify.emp.deadline_extension',
    'employee_deadline_extension_denied': 'notify.emp.deadline_extension',
    'employee_attendance_reviewed': '_attendance_reviewed',
    'employee_payslip_ready': '_payslip_ready',
    'employee_payslip_paid': '_payslip_paid',
    'employee_advance_recorded': '_advance_recorded',
    'manager_task_received': 'notify.mgr.received',
    'manager_task_completed': 'notify.mgr.completed',
    'manager_task_edited': 'notify.mgr.edited',
    'manager_task_comment': 'notify.mgr.edited',
    'manager_content_submitted_by_client': 'notify.mgr.content_submitted',
    'manager_task_overdue': 'notify.mgr.overdue',
    'manager_task_progress_updated': 'notify.mgr.progress_updated',
    'manager_task_no_action': 'notify.mgr.no_action',
    'manager_task_progress_stalled': 'notify.mgr.stalled',
    'manager_new_task_department': 'notify.mgr.new_task_dept',
    'manager_client_notes': 'notify.mgr.client_notes',
    'manager_client_approved_content': 'notify.mgr.client_approved',
    'manager_attendance_submitted': 'notify.mgr.attendance_submitted',
    'client_content_pending_approval': 'notify.client.pending',
    'client_pending_over_24h': 'notify.client.pending_24h',
    'client_approval_confirmed': 'notify.client.approval_confirmed',
    'client_edits_done': 'notify.client.edits_done',
    'client_content_updated': 'notify.client.updated',
    'client_content_scheduled': 'notify.client.scheduled',
    'client_invoice_paid': 'notify.client.invoice_paid',
    'publish_content_added': 'notify.publish.added',
    'publish_client_edit_request': 'notify.publish.edit_req',
    'publish_client_approved': 'notify.publish.approved',
    'publish_client_rejected': 'notify.publish.rejected',
    'publish_post_one_hour': 'notify.publish.one_hour',
    'publish_post_late': 'notify.publish.late',
    'publish_post_late_again': 'notify.publish.late_again',
    'publish_post_not_confirmed_today': 'notify.publish.today_not_confirmed',
    'publish_no_posts_tomorrow': 'notify.publish.no_posts_tomorrow',
    'publish_post_published': 'notify.publish.published',
    'publish_link_added': 'notify.publish.link_added',
    'publish_notes_after_publish': 'notify.publish.notes_after',
    'publish_scheduled_cancelled': 'notify.publish.cancelled',
    'admin_promotion_status_changed': 'notify.admin.promo_changed',
    'admin_content_status_changed': 'notify.admin.status_changed',
    'promotion_new_published_content': 'notify.promo.new_published',
    'broadcast_topic': 'notify.publish.added',
  };

  /// Extra app-only types (not in push catalog) grouped by category key.
  static const _extraTypesByCategory = <String, List<String>>{
    AppLocaleKeys.pushTestCategoryEmployee: [
      'employee_attendance_check_in',
      'employee_attendance_check_out',
      'employee_deadline_extension_approved',
      'employee_deadline_extension_denied',
    ],
  };

  static List<String> typesForCategory(String categoryKey) {
    final fromCatalog = <String>{};
    for (final def in kPushNotificationTestCatalog) {
      if (def.categoryKey != categoryKey) continue;
      fromCatalog.add(def.notificationType);
    }
    final extras = _extraTypesByCategory[categoryKey] ?? const <String>[];
    fromCatalog.addAll(extras);
    final list = fromCatalog.toList(growable: false);
    list.sort();
    return list;
  }

  static List<String> emailTypesForCategory(String categoryKey) {
    return typesForCategory(categoryKey)
        .where(NotificationEmailPolicy.shouldSendEmail)
        .toList(growable: false);
  }

  static AppNotificationEmailSample sampleForType(
    String notificationType, {
    String locale = 'ar',
  }) {
    final normalizedLocale = NotifyLocale.normalize(locale);
    final params = _localizedParams(normalizedLocale);
    final prefix = _prefixForType(notificationType);
    if (prefix != null) {
      final title = _resolveTitle(
        notificationType: notificationType,
        locale: normalizedLocale,
        prefix: prefix,
        params: params,
      );
      final body = _resolveBody(
        notificationType: notificationType,
        locale: normalizedLocale,
        prefix: prefix,
        params: params,
      );
      final action = _resolveAction(normalizedLocale, prefix, params);
      return AppNotificationEmailSample(
        notificationType: notificationType,
        title: title,
        body: body,
        actionText: action,
        emailDetails: _sampleEmailDetails(notificationType, normalizedLocale),
      );
    }

    return AppNotificationEmailSample(
      notificationType: notificationType,
      title: normalizedLocale == 'en' ? 'New notification' : 'إشعار جديد',
      body: normalizedLocale == 'en'
          ? 'You have a new update in the system.'
          : 'لديك تحديث جديد في النظام.',
      actionText: _genericAction(normalizedLocale),
    );
  }

  static String? _prefixForType(String notificationType) =>
      _prefixByType[notificationType];

  static String _resolveTitle({
    required String notificationType,
    required String locale,
    required String prefix,
    required Map<String, String> params,
  }) {
    switch (prefix) {
      case '_attendance_check_in':
        return NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAttendanceCheckInTitle,
        );
      case '_attendance_check_out':
        return NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAttendanceCheckOutTitle,
        );
      case '_attendance_reviewed':
        return NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAttendanceReviewedTitle,
        );
      case '_payslip_ready':
        return NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpPayslipReadyTitle,
        );
      case '_payslip_paid':
        return NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpPayslipPaidTitle,
        );
      case '_advance_recorded':
        return NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAdvanceRecordedTitle,
        );
      default:
        return NotifyLocale.tr(locale, '$prefix.title', params);
    }
  }

  static String _resolveBody({
    required String notificationType,
    required String locale,
    required String prefix,
    required Map<String, String> params,
  }) {
    if (prefix == '_attendance_check_in') {
      return NotifyLocale.tr(
        locale,
        AppLocaleKeys.notifyEmpAttendanceCheckInBody,
      );
    }
    if (prefix == '_attendance_check_out') {
      return NotifyLocale.tr(
        locale,
        AppLocaleKeys.notifyEmpAttendanceCheckOutBody,
      );
    }
    if (prefix == '_attendance_reviewed') {
      return NotifyLocale.tr(
        locale,
        AppLocaleKeys.notifyEmpAttendanceReviewedBodyApproved,
      );
    }
    if (prefix == '_payslip_ready') {
      return NotifyLocale.tr(
        locale,
        AppLocaleKeys.notifyEmpPayslipReadyBody,
        params,
      );
    }
    if (prefix == '_payslip_paid') {
      return NotifyLocale.tr(
        locale,
        AppLocaleKeys.notifyEmpPayslipPaidBody,
        params,
      );
    }
    if (prefix == '_advance_recorded') {
      return NotifyLocale.tr(
        locale,
        AppLocaleKeys.notifyEmpAdvanceRecordedBody,
        params,
      );
    }
    if (notificationType == 'employee_deadline_extension_approved') {
      return NotifyLocale.tr(
        locale,
        'notify.emp.deadline_extension.approved.body',
        params,
      );
    }
    if (notificationType == 'employee_deadline_extension_denied') {
      return NotifyLocale.tr(
        locale,
        'notify.emp.deadline_extension.denied.body',
        params,
      );
    }

    final rawBody = NotifyLocale.tr(locale, '$prefix.body', params);
    if (rawBody != '$prefix.body') return rawBody;
    return _genericBody(locale);
  }

  static String? _resolveAction(
    String locale,
    String prefix,
    Map<String, String> params,
  ) {
    if (prefix == '_attendance_check_in') {
      return NotifyLocale.tr(locale, AppLocaleKeys.attendancePresent);
    }
    if (prefix == '_attendance_check_out') {
      return NotifyLocale.tr(locale, AppLocaleKeys.attendanceLeft);
    }
    if (prefix == '_payslip_ready') {
      return NotifyLocale.tr(
        locale,
        AppLocaleKeys.notifyEmpPayslipReadyAction,
      );
    }
    if (prefix == '_payslip_paid') {
      return NotifyLocale.tr(locale, AppLocaleKeys.notifyEmpPayslipPaidAction);
    }
    if (prefix == '_advance_recorded') {
      return NotifyLocale.tr(
        locale,
        AppLocaleKeys.notifyEmpAdvanceRecordedAction,
      );
    }
    if (prefix == '_attendance_reviewed') {
      return NotifyLocale.tr(
        locale,
        AppLocaleKeys.notifyEmpAttendanceReviewedAction,
      );
    }
    if (prefix == 'notify.emp.deadline_extension') {
      return NotifyLocale.tr(locale, 'notify.emp.deadline_extension.action');
    }

    final action = NotifyLocale.tr(locale, '$prefix.action', params);
    if (action == '$prefix.action') return _genericAction(locale);
    return action;
  }

  static Map<String, String> _localizedParams(String locale) {
    final action = NotifyLocale.tr(locale, AppLocaleKeys.attendancePresent);
    if (locale == 'ar') {
      return {
        ..._sampleParams,
        'label': NotifyLocale.tr(locale, 'status_task_completed'),
        'action': action,
      };
    }
    return {
      'title': 'Sample task',
      'name': 'Employee',
      'label': NotifyLocale.tr(locale, 'status_task_completed'),
      'by': 'Employee',
      'pct': '50',
      'client': 'Client',
      'platform': 'Instagram',
      'date': '2026-04-27',
      'time': '10:00',
      'ref': 'REF-1001',
      'dept': 'Design',
      'type': 'Content',
      'supervisor': 'Supervisor',
      'period': '2026-04',
      'amount': '1,000,000 IQD',
      'advance': '100,000 IQD',
      'action': action,
    };
  }

  static String _genericBody(String locale) {
    return locale == 'en'
        ? 'Open the app to view details.'
        : 'يرجى فتح التطبيق للاطلاع على التفاصيل.';
  }

  static String _genericAction(String locale) {
    return locale == 'en'
        ? 'Open the app for full details.'
        : 'افتح التطبيق للاطلاع على التفاصيل الكاملة.';
  }

  static Map<String, String>? _sampleEmailDetails(
    String notificationType,
    String locale,
  ) {
    final params = _localizedParams(locale);
    final ctx = TaskEmailContext(
      taskTitle: params['title']!,
      department: params['dept'],
      dueDate: params['date'],
      startDate: params['date'],
      priority: NotifyLocale.tr(locale, 'notify.sample.priority_medium'),
      clientName: params['client'],
      editMessage: NotifyLocale.tr(locale, 'notify.sample.edit_message'),
      requestedBy: params['supervisor'],
      rejectionReason: NotifyLocale.tr(locale, 'notify.sample.rejection_reason'),
      rejectedBy: params['supervisor'],
      commentPreview: NotifyLocale.tr(locale, 'notify.sample.comment_preview'),
      commenterName: params['name'],
      newStatus: params['label'],
      changedBy: params['by'],
      attachmentCount: 2,
      addedBy: params['by'],
      extensionReason: NotifyLocale.tr(locale, 'notify.sample.extension_reason'),
      newDueDate: '2026-05-01',
      denialNote: NotifyLocale.tr(locale, 'notify.sample.denial_note'),
    );

    switch (notificationType) {
      case 'employee_task_assigned':
        return NotificationEmailFields.employeeTaskAssigned(locale, ctx);
      case 'employee_task_edit_requested':
        return NotificationEmailFields.employeeTaskEditRequested(locale, ctx);
      case 'employee_task_rejected':
        return NotificationEmailFields.employeeTaskRejected(locale, ctx);
      case 'employee_task_reopened':
        return NotificationEmailFields.employeeTaskReopened(locale, ctx);
      case 'employee_task_new_attachments':
        return NotificationEmailFields.employeeTaskNewAttachments(locale, ctx);
      case 'employee_task_new_comment':
        return NotificationEmailFields.employeeTaskNewComment(locale, ctx);
      case 'employee_task_status_changed':
        return NotificationEmailFields.employeeTaskStatusChanged(locale, ctx);
      case 'employee_deadline_extension_approved':
        return NotificationEmailFields.employeeDeadlineExtensionApproved(
          locale,
          ctx,
        );
      case 'employee_deadline_extension_denied':
        return NotificationEmailFields.employeeDeadlineExtensionDenied(
          locale,
          ctx,
        );
      case 'manager_task_received':
      case 'manager_task_completed':
      case 'manager_task_overdue':
      case 'manager_task_no_action':
      case 'manager_task_progress_stalled':
        return NotificationEmailFields.managerTaskWithEmployee(locale, ctx);
      case 'manager_task_comment':
        return NotificationEmailFields.managerTaskComment(locale, ctx);
      case 'manager_new_task_department':
        return NotificationEmailFields.managerNewTaskDepartment(
          locale,
          department: params['dept']!,
          dueDate: params['date']!,
          clientName: params['client'],
        );
      case 'manager_attendance_submitted':
        return NotificationEmailFields.labels(locale, {
          'notify.email.employee': params['name']!,
          'notify.email.action': NotifyLocale.tr(
            locale,
            AppLocaleKeys.attendancePresent,
          ),
        });
      default:
        return null;
    }
  }
}
