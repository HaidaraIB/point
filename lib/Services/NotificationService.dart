import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/notify_locale.dart';
import 'package:point/Models/AttendanceRecordModel.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/notification_email_fields.dart';

/// ما أضافه المكلَّف عند بقاء حالة المهمة كما هي (إشعار المشرف).
enum ManagerTaskEditKind {
  /// تعليق (ملاحظات) فقط.
  comment,

  /// مرفقات فقط.
  attachment,

  /// تعليق ومرفق.
  both,
}

/// Push/email for **app-triggered** flows. Types sent only by Supabase Cron
/// (`scheduled-notifications`) live in that function — no Dart wrappers here.
///
/// Copy is resolved per recipient via [NotificationCopyForLocale] using the
/// receiver's Firestore `language`, not the sender's GetX locale.
class NotificationService {
  NotificationService._();

  /// Task type index aligned with [StorageKeys.departmentSlugs] → localized name.
  static String departmentNameFromTaskType(
    String type, {
    String locale = 'ar',
  }) {
    final idx = int.tryParse(type);
    final max = StorageKeys.departmentSlugs.length - 1;
    if (idx == null || idx < 0 || idx > max) {
      return NotifyLocale.tr(locale, 'notify.department_unknown');
    }
    final semantic = StorageKeys.departmentSlugs[idx];
    return NotifyLocale.tr(
      locale,
      StorageKeys.semanticDepartmentLabelKey(semantic),
    );
  }

  /// Content / task status storage key → localized label.
  static String statusLabelAr(String status, {String locale = 'ar'}) =>
      NotifyLocale.tr(locale, status);

  /// Localizes [TaskEmailContext.department] when it holds a raw task type index.
  static TaskEmailContext localizeTaskEmailContext(
    String locale,
    TaskEmailContext ctx,
  ) {
    final raw = ctx.department?.trim() ?? '';
    if (raw.isEmpty || int.tryParse(raw) == null) return ctx;
    return ctx.copyWith(
      department: departmentNameFromTaskType(raw, locale: locale),
    );
  }

  // ─── Employee notifications ─────────────────────────────────────────────

  static Future<void> notifyEmployeeAssignedToTask({
    required String employeeId,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_task_assigned',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.emp.assigned.title'),
        body: taskTitle,
        actionText: NotifyLocale.tr(locale, 'notify.emp.assigned.action'),
        emailDetails: taskContext != null
            ? NotificationEmailFields.employeeTaskAssigned(
                locale,
                localizeTaskEmailContext(locale, taskContext),
              )
            : null,
      ),
    );
  }

  static Future<void> notifyEmployeeEditRequestedByManagement({
    required String employeeId,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_task_edit_requested',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.emp.edit_mgmt.title'),
        body: taskTitle,
        actionText: NotifyLocale.tr(locale, 'notify.emp.edit_mgmt.action'),
        emailDetails: taskContext != null
            ? NotificationEmailFields.employeeTaskEditRequested(
                locale,
                localizeTaskEmailContext(locale, taskContext),
              )
            : null,
      ),
    );
  }

  static Future<void> notifyEmployeeTaskRejected({
    required String employeeId,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_task_rejected',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.emp.rejected.title'),
        body: NotifyLocale.tr(locale, 'notify.emp.rejected.body', {
          'title': taskTitle,
        }),
        actionText: NotifyLocale.tr(locale, 'notify.emp.rejected.action'),
        emailDetails: taskContext != null
            ? NotificationEmailFields.employeeTaskRejected(
                locale,
                localizeTaskEmailContext(locale, taskContext),
              )
            : NotificationEmailFields.labels(locale, {
                'notify.email.status': NotifyLocale.tr(
                  locale,
                  'status_rejected',
                ),
              }),
      ),
    );
  }

  static Future<void> notifyEmployeeTaskReopened({
    required String employeeId,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_task_reopened',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.emp.reopened.title'),
        body: taskTitle,
        actionText: NotifyLocale.tr(locale, 'notify.emp.reopened.action'),
        emailDetails: taskContext != null
            ? NotificationEmailFields.employeeTaskReopened(
                locale,
                localizeTaskEmailContext(locale, taskContext),
              )
            : NotificationEmailFields.labels(locale, {
                'notify.email.status': NotifyLocale.tr(
                  locale,
                  'notify.email.state_reopened',
                ),
              }),
      ),
    );
  }

  static Future<void> notifyEmployeeNewAttachments({
    required String employeeId,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_task_new_attachments',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.emp.attachments.title'),
        body: taskTitle,
        actionText: NotifyLocale.tr(locale, 'notify.emp.attachments.action'),
        emailDetails: taskContext != null
            ? NotificationEmailFields.employeeTaskNewAttachments(
                locale,
                localizeTaskEmailContext(locale, taskContext),
              )
            : null,
      ),
    );
  }

  /// تعليق من غير المكلَّف (إدارة أو زميل) على مهمة مكلَّفة إليه.
  static Future<void> notifyEmployeeTaskNewComment({
    required String employeeId,
    required String commenterName,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ctx =
        taskContext ??
        TaskEmailContext(taskTitle: taskTitle, commenterName: commenterName);
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_task_new_comment',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.emp.new_comment.title'),
        body: NotifyLocale.tr(locale, 'notify.emp.new_comment.body', {
          'name': commenterName,
          'title': taskTitle,
        }),
        actionText: NotifyLocale.tr(locale, 'notify.emp.new_comment.action'),
        emailDetails: NotificationEmailFields.employeeTaskNewComment(
          locale,
          localizeTaskEmailContext(locale, ctx),
        ),
      ),
    );
  }

  static Future<void> notifyEmployeeTaskStatusChanged({
    required String employeeId,
    required String taskTitle,
    required String newStatus,
    required String changedBy,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_task_status_changed',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) {
        final label = statusLabelAr(newStatus, locale: locale);
        final actor = changedBy.trim().isEmpty
            ? NotifyLocale.tr(locale, 'notify.unknown_actor')
            : changedBy.trim();
        final ctx =
            taskContext?.copyWith(newStatus: label, changedBy: actor) ??
            TaskEmailContext(
              taskTitle: taskTitle,
              newStatus: label,
              changedBy: actor,
            );
        return ResolvedNotificationCopy(
          title: NotifyLocale.tr(locale, 'notify.emp.status_changed.title'),
          body: NotifyLocale.tr(locale, 'notify.emp.status_changed.body', {
            'title': taskTitle,
            'label': label,
            'by': actor,
          }),
          actionText: NotifyLocale.tr(
            locale,
            'notify.emp.status_changed.action',
          ),
          emailDetails: NotificationEmailFields.employeeTaskStatusChanged(
            locale,
            localizeTaskEmailContext(locale, ctx),
          ),
        );
      },
    );
  }

  static Future<void> notifyEmployeeDeadlineExtensionApproved({
    required String employeeId,
    required String taskTitle,
    required String newDueLabel,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ctx =
        taskContext ??
        TaskEmailContext(taskTitle: taskTitle, newDueDate: newDueLabel);
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_deadline_extension_approved',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.emp.deadline_extension.title'),
        body: NotifyLocale.tr(
          locale,
          'notify.emp.deadline_extension.approved.body',
          {'title': taskTitle, 'date': newDueLabel},
        ),
        actionText: NotifyLocale.tr(
          locale,
          'notify.emp.deadline_extension.action',
        ),
        emailDetails:
            NotificationEmailFields.employeeDeadlineExtensionApproved(
          locale,
          localizeTaskEmailContext(locale, ctx),
        ),
      ),
    );
  }

  static Future<void> notifyEmployeeDeadlineExtensionDenied({
    required String employeeId,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_deadline_extension_denied',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.emp.deadline_extension.title'),
        body: NotifyLocale.tr(
          locale,
          'notify.emp.deadline_extension.denied.body',
          {'title': taskTitle},
        ),
        actionText: NotifyLocale.tr(
          locale,
          'notify.emp.deadline_extension.action',
        ),
        emailDetails: taskContext != null
            ? NotificationEmailFields.employeeDeadlineExtensionDenied(
                locale,
                localizeTaskEmailContext(locale, taskContext),
              )
            : null,
      ),
    );
  }

  static Future<void> notifyEmployeeCheckInReminder({
    required String employeeId,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_attendance_check_in',
      referenceId: 'attendance',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAttendanceCheckInTitle,
        ),
        body: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAttendanceCheckInBody,
        ),
        actionText: NotifyLocale.tr(locale, AppLocaleKeys.attendancePresent),
      ),
    );
  }

  static Future<void> notifyEmployeeCheckOutReminder({
    required String employeeId,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_attendance_check_out',
      referenceId: 'attendance',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAttendanceCheckOutTitle,
        ),
        body: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAttendanceCheckOutBody,
        ),
        actionText: NotifyLocale.tr(locale, AppLocaleKeys.attendanceLeft),
      ),
    );
  }

  static Future<void> notifyManagersAttendanceSubmitted({
    required String employeeName,
    required String action,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(['admin']);
    if (ids.isEmpty) return;
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'manager_attendance_submitted',
      referenceId: 'attendance',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) {
        final actionLabel = action == AttendanceRecordModel.actionPresent
            ? NotifyLocale.tr(locale, AppLocaleKeys.attendancePresent)
            : NotifyLocale.tr(locale, AppLocaleKeys.attendanceLeft);
        return ResolvedNotificationCopy(
          title: NotifyLocale.tr(
            locale,
            'notify.mgr.attendance_submitted.title',
          ),
          body: NotifyLocale.tr(
            locale,
            'notify.mgr.attendance_submitted.body',
            {'name': employeeName, 'action': actionLabel},
          ),
          actionText: NotifyLocale.tr(
            locale,
            'notify.mgr.attendance_submitted.action',
          ),
          emailDetails: NotificationEmailFields.labels(locale, {
            'notify.email.employee': employeeName,
          }),
        );
      },
    );
  }

  static Future<void> notifyEmployeeAttendanceReviewed({
    required String employeeId,
    required String action,
    required bool approved,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_attendance_reviewed',
      referenceId: 'attendance',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) {
        final actionLabel = action == AttendanceRecordModel.actionPresent
            ? NotifyLocale.tr(locale, AppLocaleKeys.attendancePresent)
            : NotifyLocale.tr(locale, AppLocaleKeys.attendanceLeft);
        final outcomeLabel = approved
            ? NotifyLocale.tr(locale, AppLocaleKeys.attendanceApproved)
            : NotifyLocale.tr(locale, AppLocaleKeys.attendanceAbsent);
        final body = approved
            ? NotifyLocale.tr(
                locale,
                AppLocaleKeys.notifyEmpAttendanceReviewedBodyApproved,
                {'action': actionLabel},
              )
            : NotifyLocale.tr(
                locale,
                AppLocaleKeys.notifyEmpAttendanceReviewedBodyAbsent,
                {'action': actionLabel},
              );
        return ResolvedNotificationCopy(
          title: NotifyLocale.tr(
            locale,
            AppLocaleKeys.notifyEmpAttendanceReviewedTitle,
          ),
          body: body,
          actionText: NotifyLocale.tr(
            locale,
            AppLocaleKeys.notifyEmpAttendanceReviewedAction,
          ),
          emailDetails: NotificationEmailFields.labels(locale, {
            'notify.email.outcome': outcomeLabel,
          }),
        );
      },
    );
  }

  static Future<void> notifyEmployeePayslipReady({
    required String employeeId,
    required String period,
    required String netPayLabel,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_payslip_ready',
      referenceId: period,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpPayslipReadyTitle,
        ),
        body: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpPayslipReadyBody,
          {'period': period, 'amount': netPayLabel},
        ),
        actionText: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpPayslipReadyAction,
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.period': period,
          'notify.email.amount': netPayLabel,
        }),
      ),
    );
  }

  static Future<void> notifyEmployeePayslipPaid({
    required String employeeId,
    required String period,
    required String netPayLabel,
    String? advanceDeductionLabel,
    Map<String, String>? fcmDataExtras,
  }) async {
    final advance = advanceDeductionLabel?.trim() ?? '';
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_payslip_paid',
      referenceId: period,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) {
        final body = advance.isEmpty
            ? NotifyLocale.tr(
                locale,
                AppLocaleKeys.notifyEmpPayslipPaidBody,
                {'period': period, 'amount': netPayLabel},
              )
            : NotifyLocale.tr(
                locale,
                AppLocaleKeys.notifyEmpPayslipPaidBodyWithAdvance,
                {
                  'period': period,
                  'amount': netPayLabel,
                  'advance': advance,
                },
              );
        final emailDetails = <String, String>{
          'notify.email.period': period,
          'notify.email.amount': netPayLabel,
        };
        if (advance.isNotEmpty) {
          emailDetails['notify.email.advance'] = advance;
        }
        return ResolvedNotificationCopy(
          title: NotifyLocale.tr(
            locale,
            AppLocaleKeys.notifyEmpPayslipPaidTitle,
          ),
          body: body,
          actionText: NotifyLocale.tr(
            locale,
            AppLocaleKeys.notifyEmpPayslipPaidAction,
          ),
          emailDetails: NotificationEmailFields.labels(locale, emailDetails),
        );
      },
    );
  }

  static Future<void> notifyEmployeeAdvanceRecorded({
    required String employeeId,
    required String amountLabel,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'employee_advance_recorded',
      referenceId: amountLabel,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAdvanceRecordedTitle,
        ),
        body: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAdvanceRecordedBody,
          {'amount': amountLabel},
        ),
        actionText: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyEmpAdvanceRecordedAction,
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.amount': amountLabel,
        }),
      ),
    );
  }

  static Future<void> notifyClientInvoicePaid({
    required String clientId,
    required String invoiceRef,
    required String amountLabel,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      notificationType: 'client_invoice_paid',
      referenceId: invoiceRef,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyClientInvoicePaidTitle,
        ),
        body: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyClientInvoicePaidBody,
          {'ref': invoiceRef, 'amount': amountLabel},
        ),
        actionText: NotifyLocale.tr(
          locale,
          AppLocaleKeys.notifyClientInvoicePaidAction,
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.invoice': invoiceRef,
          'notify.email.amount': amountLabel,
        }),
      ),
    );
  }

  // ─── Manager / admin ─────────────────────────────────────────────────────

  static Future<void> notifyManagersTaskProgressUpdated({
    required String employeeName,
    required String taskTitle,
    required int progressPercent,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    final pct = progressPercent.clamp(0, 100).toString();
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'manager_task_progress_updated',
      referenceId: taskTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.mgr.progress_updated.title'),
        body: NotifyLocale.tr(locale, 'notify.mgr.progress_updated.body', {
          'name': employeeName,
          'title': taskTitle,
          'pct': pct,
        }),
        actionText: NotifyLocale.tr(
          locale,
          'notify.mgr.progress_updated.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.employee': employeeName,
          'notify.email.task': taskTitle,
        }),
      ),
    );
  }

  static Future<void> notifyManagersTaskReceivedByEmployee({
    required String employeeName,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    final ctx =
        taskContext ??
        TaskEmailContext(taskTitle: taskTitle, changedBy: employeeName);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'manager_task_received',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.mgr.received.title'),
        body: NotifyLocale.tr(locale, 'notify.mgr.received.body', {
          'name': employeeName,
          'title': taskTitle,
        }),
        actionText: NotifyLocale.tr(locale, 'notify.mgr.received.action'),
        emailDetails: NotificationEmailFields.managerTaskWithEmployee(
          locale,
          localizeTaskEmailContext(locale, ctx),
        ),
      ),
    );
  }

  static Future<void> notifyManagersTaskCompletedByEmployee({
    required String employeeName,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    final ctx =
        taskContext ??
        TaskEmailContext(taskTitle: taskTitle, changedBy: employeeName);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'manager_task_completed',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.mgr.completed.title'),
        body: NotifyLocale.tr(locale, 'notify.mgr.completed.body', {
          'name': employeeName,
          'title': taskTitle,
        }),
        actionText: NotifyLocale.tr(locale, 'notify.mgr.completed.action'),
        emailDetails: NotificationEmailFields.managerTaskWithEmployee(
          locale,
          localizeTaskEmailContext(locale, ctx),
        ),
      ),
    );
  }

  /// المشرف أحال المهمة للمدير (admin) فقط.
  static Future<void> notifyAdminsSupervisorEscalatedTask({
    required String supervisorName,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(['admin']);
    if (ids.isEmpty) return;
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'admin_supervisor_escalated_task',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(
          locale,
          'notify.admin.supervisor_escalated.title',
        ),
        body: NotifyLocale.tr(
          locale,
          'notify.admin.supervisor_escalated.body',
          {'supervisor': supervisorName, 'title': taskTitle},
        ),
        actionText: NotifyLocale.tr(
          locale,
          'notify.admin.supervisor_escalated.action',
        ),
        emailDetails: taskContext != null
            ? NotificationEmailFields.adminSupervisorEscalated(
                locale,
                supervisorName: supervisorName,
                dueDate: taskContext.dueDate ?? '',
                department: localizeTaskEmailContext(
                  locale,
                  taskContext,
                ).department,
              )
            : NotificationEmailFields.labels(locale, {
                'notify.email.employee': supervisorName,
              }),
      ),
    );
  }

  static Future<void> notifyManagersEmployeeEditedTask({
    required String employeeName,
    required String taskTitle,
    required ManagerTaskEditKind kind,
    TaskEmailContext? taskContext,
    String? commentPreview,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    final prefix = switch (kind) {
      ManagerTaskEditKind.comment => 'notify.mgr.edited',
      ManagerTaskEditKind.attachment => 'notify.mgr.edited_files',
      ManagerTaskEditKind.both => 'notify.mgr.edited_both',
    };
    final String pushType = switch (kind) {
      ManagerTaskEditKind.comment ||
      ManagerTaskEditKind.both => 'manager_task_comment',
      ManagerTaskEditKind.attachment => 'manager_task_edited',
    };
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: pushType,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) {
        final detailValue = NotifyLocale.tr(locale, '$prefix.detail_value');
        final ctx =
            taskContext?.copyWith(
              changedBy: employeeName,
              newStatus: detailValue,
              commentPreview: commentPreview,
            ) ??
            TaskEmailContext(
              taskTitle: taskTitle,
              changedBy: employeeName,
              newStatus: detailValue,
              commentPreview: commentPreview,
            );
        return ResolvedNotificationCopy(
          title: NotifyLocale.tr(locale, '$prefix.title'),
          body: NotifyLocale.tr(locale, '$prefix.body', {
            'name': employeeName,
            'title': taskTitle,
          }),
          actionText: NotifyLocale.tr(locale, '$prefix.action'),
          emailDetails: NotificationEmailFields.managerTaskComment(
            locale,
            localizeTaskEmailContext(locale, ctx),
          ),
        );
      },
    );
  }

  static Future<void> notifyManagersContentSubmittedByClient({
    required String clientName,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'manager_content_submitted_by_client',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.mgr.content_submitted.title'),
        body: NotifyLocale.tr(locale, 'notify.mgr.content_submitted.body', {
          'name': clientName,
          'title': contentTitle,
        }),
        actionText: NotifyLocale.tr(
          locale,
          'notify.mgr.content_submitted.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.client': clientName,
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  static Future<void> notifyManagersNewTaskInDepartment({
    required String taskTitle,
    required String taskType,
    String? dueDate,
    String? clientName,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'manager_new_task_department',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) {
        final dept = departmentNameFromTaskType(taskType, locale: locale);
        return ResolvedNotificationCopy(
          title: NotifyLocale.tr(locale, 'notify.mgr.new_task_dept.title', {
            'dept': dept,
          }),
          body: taskTitle,
          actionText: NotifyLocale.tr(
            locale,
            'notify.mgr.new_task_dept.action',
          ),
          emailDetails: NotificationEmailFields.managerNewTaskDepartment(
            locale,
            department: dept,
            dueDate: dueDate ?? '',
            clientName: clientName,
          ),
        );
      },
    );
  }

  static Future<void> notifyManagersDeadlineExtensionRequested({
    required String employeeName,
    required String taskTitle,
    TaskEmailContext? taskContext,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    final ctx =
        taskContext ??
        TaskEmailContext(taskTitle: taskTitle, changedBy: employeeName);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'manager_deadline_extension_requested',
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.mgr.deadline_extension.title'),
        body: NotifyLocale.tr(locale, 'notify.mgr.deadline_extension.body', {
          'name': employeeName,
          'title': taskTitle,
        }),
        actionText: NotifyLocale.tr(
          locale,
          'notify.mgr.deadline_extension.action',
        ),
        emailDetails:
            NotificationEmailFields.managerDeadlineExtensionRequested(
          locale,
          localizeTaskEmailContext(locale, ctx),
        ),
      ),
    );
  }

  static Future<void> notifyManagersClientNotesOnContent({
    required String clientName,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'manager_client_notes',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.mgr.client_notes.title'),
        body: NotifyLocale.tr(locale, 'notify.mgr.client_notes.body', {
          'name': clientName,
          'title': contentTitle,
        }),
        actionText: NotifyLocale.tr(locale, 'notify.mgr.client_notes.action'),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.client': clientName,
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  static Future<void> notifyManagersClientApprovedContent({
    required String clientName,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'manager_client_approved_content',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.mgr.client_approved.title'),
        body: NotifyLocale.tr(locale, 'notify.mgr.client_approved.body', {
          'name': clientName,
          'title': contentTitle,
        }),
        actionText: NotifyLocale.tr(
          locale,
          'notify.mgr.client_approved.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.client': clientName,
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  // ─── Client ─────────────────────────────────────────────────────────────

  static Future<void> notifyClientContentPendingApproval({
    required String clientId,
    required String contentTypeKey,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      notificationType: 'client_content_pending_approval',
      referenceId: contentTypeKey,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) {
        final typeLabel = NotifyLocale.tr(locale, contentTypeKey);
        return ResolvedNotificationCopy(
          title: NotifyLocale.tr(locale, 'notify.client.pending.title', {
            'type': typeLabel,
          }),
          body: NotifyLocale.tr(locale, 'notify.client.pending.body'),
          actionText: NotifyLocale.tr(locale, 'notify.client.pending.action'),
          emailDetails: NotificationEmailFields.labels(locale, {
            'notify.email.content_type': typeLabel,
          }),
        );
      },
    );
  }

  static Future<void> notifyClientApprovalConfirmed({
    required String clientId,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      notificationType: 'client_approval_confirmed',
      referenceId: clientId,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(
          locale,
          'notify.client.approval_confirmed.title',
        ),
        body: NotifyLocale.tr(
          locale,
          'notify.client.approval_confirmed.body',
        ),
        actionText: NotifyLocale.tr(
          locale,
          'notify.client.approval_confirmed.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.status': NotifyLocale.tr(
            locale,
            'notify.client.approval_confirmed.email_status',
          ),
        }),
      ),
    );
  }

  static Future<void> notifyClientEditsDone({
    required String clientId,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      notificationType: 'client_edits_done',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.client.edits_done.title'),
        body: contentTitle,
        actionText: NotifyLocale.tr(
          locale,
          'notify.client.edits_done.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  static Future<void> notifyClientContentUpdatedForApproval({
    required String clientId,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      notificationType: 'client_content_updated',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.client.updated.title'),
        body: contentTitle,
        actionText: NotifyLocale.tr(locale, 'notify.client.updated.action'),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  static Future<void> notifyClientContentScheduled({
    required String clientId,
    required String contentTitle,
    required String dateFormatted,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      notificationType: 'client_content_scheduled',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.client.scheduled.title', {
          'date': dateFormatted,
        }),
        body: contentTitle,
        actionText: NotifyLocale.tr(locale, 'notify.client.scheduled.action'),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.content': contentTitle,
          'notify.email.publish_date': dateFormatted,
        }),
      ),
    );
  }

  // ─── Publishing department ──────────────────────────────────────────────

  static Future<void> notifyPublishDeptContentAdded({
    required String clientName,
    required String platformLabel,
    required String dateFormatted,
    required String timeFormatted,
    Map<String, String>? fcmDataExtras,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment(
      StorageKeys.departmentPublishing,
    );
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      notificationType: 'publish_content_added',
      referenceId: clientName,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.publish.added.title'),
        body: NotifyLocale.tr(locale, 'notify.publish.added.body', {
          'client': clientName,
          'platform': platformLabel,
          'date': dateFormatted,
          'time': timeFormatted,
        }),
        actionText: NotifyLocale.tr(locale, 'notify.publish.added.action'),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.client': clientName,
          'notify.email.platform': platformLabel,
          'notify.email.date': dateFormatted,
          'notify.email.time': timeFormatted,
        }),
      ),
    );
  }

  static Future<void> notifyPublishDeptClientEditRequest({
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment(
      StorageKeys.departmentPublishing,
    );
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      notificationType: 'publish_client_edit_request',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.publish.edit_req.title'),
        body: contentTitle,
        actionText: NotifyLocale.tr(locale, 'notify.publish.edit_req.action'),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  static Future<void> notifyPublishDeptClientApproved({
    required String clientName,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment(
      StorageKeys.departmentPublishing,
    );
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      notificationType: 'publish_client_approved',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.publish.approved.title'),
        body: NotifyLocale.tr(locale, 'notify.publish.approved.body', {
          'name': clientName,
          'title': contentTitle,
        }),
        actionText: NotifyLocale.tr(locale, 'notify.publish.approved.action'),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.client': clientName,
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  static Future<void> notifyPublishDeptClientRejected({
    required String contentTitle,
    required String clientName,
    Map<String, String>? fcmDataExtras,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole([
      'admin',
      'supervisor',
    ]);
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment(
      StorageKeys.departmentPublishing,
    );
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      notificationType: 'publish_client_rejected',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.publish.rejected.title'),
        body: NotifyLocale.tr(locale, 'notify.publish.rejected.body', {
          'title': contentTitle,
          'name': clientName,
        }),
        actionText: NotifyLocale.tr(locale, 'notify.publish.rejected.action'),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.client': clientName,
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  static Future<void> notifyPublishDeptPostScheduledTodayNotConfirmed({
    required String employeeId,
    required String contentRef,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      notificationType: 'publish_post_not_confirmed_today',
      referenceId: contentRef,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(
          locale,
          'notify.publish.today_not_confirmed.title',
        ),
        body: NotifyLocale.tr(
          locale,
          'notify.publish.today_not_confirmed.body',
          {'ref': contentRef},
        ),
        actionText: NotifyLocale.tr(
          locale,
          'notify.publish.today_not_confirmed.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.reference': contentRef,
        }),
      ),
    );
  }

  static Future<void> notifyPublishDeptPostPublished({
    required List<String> recipientIds,
    required String platformLabel,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      notificationType: 'publish_post_published',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.publish.published.title', {
          'platform': platformLabel,
        }),
        body: contentTitle,
        actionText: NotifyLocale.tr(
          locale,
          'notify.publish.published.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.platform': platformLabel,
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  static Future<void> notifyPublishDeptLinkAdded({
    required List<String> recipientIds,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      notificationType: 'publish_link_added',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.publish.link_added.title'),
        body: contentTitle,
        actionText: NotifyLocale.tr(
          locale,
          'notify.publish.link_added.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  static Future<void> notifyPublishDeptNotesAfterPublish({
    required List<String> recipientIds,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      notificationType: 'publish_notes_after_publish',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.publish.notes_after.title'),
        body: contentTitle,
        actionText: NotifyLocale.tr(
          locale,
          'notify.publish.notes_after.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  static Future<void> notifyPublishDeptScheduledCancelled({
    required List<String> recipientIds,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      notificationType: 'publish_scheduled_cancelled',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.publish.cancelled.title'),
        body: contentTitle,
        actionText: NotifyLocale.tr(
          locale,
          'notify.publish.cancelled.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }

  // ─── Promotion / admin ───────────────────────────────────────────────────

  static Future<void> notifyAdminContentPromotionStatusChanged({
    required String contentTitle,
    required String promotionLabelKey,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(['admin']);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'admin_promotion_status_changed',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) {
        final label = NotifyLocale.tr(locale, promotionLabelKey);
        return ResolvedNotificationCopy(
          title: NotifyLocale.tr(locale, 'notify.admin.promo_changed.title'),
          body: NotifyLocale.tr(locale, 'notify.admin.promo_changed.body', {
            'title': contentTitle,
            'label': label,
          }),
          actionText: NotifyLocale.tr(
            locale,
            'notify.admin.promo_changed.action',
          ),
          emailDetails: NotificationEmailFields.labels(locale, {
            'notify.email.content': contentTitle,
            'notify.email.status': label,
          }),
        );
      },
    );
  }

  static Future<void> notifyAdminContentStatusChanged({
    required String contentTitle,
    required String statusKey,
    required String changedByName,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(['admin']);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'admin_content_status_changed',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) {
        final label = statusLabelAr(statusKey, locale: locale);
        final by = changedByName.trim().isEmpty
            ? NotifyLocale.tr(locale, 'notify.unknown_actor')
            : changedByName.trim();
        return ResolvedNotificationCopy(
          title: NotifyLocale.tr(locale, 'notify.admin.status_changed.title'),
          body: NotifyLocale.tr(locale, 'notify.admin.status_changed.body', {
            'title': contentTitle,
            'label': label,
            'by': by,
          }),
          actionText: NotifyLocale.tr(
            locale,
            'notify.admin.status_changed.action',
          ),
          emailDetails: NotificationEmailFields.labels(locale, {
            'notify.email.content': contentTitle,
            'notify.email.status': label,
            'notify.email.changed_by': by,
          }),
        );
      },
    );
  }

  static Future<void> notifyPromotionDeptNewPublishedContent({
    required String clientName,
    required String contentTitle,
    Map<String, String>? fcmDataExtras,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByDepartment(
      StorageKeys.departmentPromotion,
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      notificationType: 'promotion_new_published_content',
      referenceId: contentTitle,
      fcmDataExtras: fcmDataExtras,
      copyForLocale: (locale) => ResolvedNotificationCopy(
        title: NotifyLocale.tr(locale, 'notify.promo.new_published.title'),
        body: NotifyLocale.tr(locale, 'notify.promo.new_published.body', {
          'name': clientName,
          'title': contentTitle,
        }),
        actionText: NotifyLocale.tr(
          locale,
          'notify.promo.new_published.action',
        ),
        emailDetails: NotificationEmailFields.labels(locale, {
          'notify.email.client': clientName,
          'notify.email.content': contentTitle,
        }),
      ),
    );
  }
}
