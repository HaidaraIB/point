import 'package:get/get.dart';

/// Context for building task-related email detail rows.
class TaskEmailContext {
  const TaskEmailContext({
    required this.taskTitle,
    this.department,
    this.dueDate,
    this.startDate,
    this.priority,
    this.clientName,
    this.editMessage,
    this.requestedBy,
    this.rejectionReason,
    this.rejectedBy,
    this.commentPreview,
    this.commenterName,
    this.newStatus,
    this.changedBy,
    this.attachmentCount,
    this.addedBy,
    this.extensionReason,
    this.newDueDate,
    this.denialNote,
  });

  final String taskTitle;
  final String? department;
  final String? dueDate;
  final String? startDate;
  final String? priority;
  final String? clientName;
  final String? editMessage;
  final String? requestedBy;
  final String? rejectionReason;
  final String? rejectedBy;
  final String? commentPreview;
  final String? commenterName;
  final String? newStatus;
  final String? changedBy;
  final int? attachmentCount;
  final String? addedBy;
  final String? extensionReason;
  final String? newDueDate;
  final String? denialNote;

  TaskEmailContext copyWith({
    String? newStatus,
    String? changedBy,
    String? commenterName,
    String? commentPreview,
    String? requestedBy,
    String? rejectedBy,
    String? addedBy,
    int? attachmentCount,
    String? newDueDate,
    String? denialNote,
  }) {
    return TaskEmailContext(
      taskTitle: taskTitle,
      department: department,
      dueDate: dueDate,
      startDate: startDate,
      priority: priority,
      clientName: clientName,
      editMessage: editMessage,
      requestedBy: requestedBy ?? this.requestedBy,
      rejectionReason: rejectionReason,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      commentPreview: commentPreview ?? this.commentPreview,
      commenterName: commenterName ?? this.commenterName,
      newStatus: newStatus ?? this.newStatus,
      changedBy: changedBy ?? this.changedBy,
      attachmentCount: attachmentCount ?? this.attachmentCount,
      addedBy: addedBy ?? this.addedBy,
      extensionReason: extensionReason,
      newDueDate: newDueDate ?? this.newDueDate,
      denialNote: denialNote ?? this.denialNote,
    );
  }
}

/// Builds localized email detail maps per notification type.
class NotificationEmailFields {
  NotificationEmailFields._();

  static Map<String, String> labels(Map<String, String> fields) => {
    for (final e in fields.entries) e.key.tr: e.value,
  };

  static String? truncate(String? text, {int maxLen = 200}) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen)}…';
  }

  static void _put(
    Map<String, String> out,
    String labelKey,
    String? value,
  ) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return;
    out[labelKey.tr] = v;
  }

  static void _putTaskCommon(Map<String, String> out, TaskEmailContext ctx) {
    _put(out, 'notify.email.department', ctx.department);
    _put(out, 'notify.email.due_date', ctx.dueDate);
    _put(out, 'notify.email.start_date', ctx.startDate);
    _put(out, 'notify.email.priority', ctx.priority);
    _put(out, 'notify.email.client', ctx.clientName);
  }

  static Map<String, String> employeeTaskAssigned(TaskEmailContext ctx) {
    final out = <String, String>{};
    _putTaskCommon(out, ctx);
    return out;
  }

  static Map<String, String> employeeTaskEditRequested(TaskEmailContext ctx) {
    final out = <String, String>{};
    _put(out, 'notify.email.edit_message', truncate(ctx.editMessage));
    _put(out, 'notify.email.requested_by', ctx.requestedBy);
    _put(out, 'notify.email.due_date', ctx.dueDate);
    return out;
  }

  static Map<String, String> employeeTaskRejected(TaskEmailContext ctx) {
    final out = <String, String>{};
    _put(out, 'notify.email.rejection_reason', truncate(ctx.rejectionReason));
    _put(out, 'notify.email.rejected_by', ctx.rejectedBy);
    _put(out, 'notify.email.due_date', ctx.dueDate);
    return out;
  }

  static Map<String, String> employeeTaskReopened(TaskEmailContext ctx) {
    final out = <String, String>{};
    _put(out, 'notify.email.due_date', ctx.dueDate);
    _put(out, 'notify.email.department', ctx.department);
    return out;
  }

  static Map<String, String> employeeTaskNewAttachments(TaskEmailContext ctx) {
    final out = <String, String>{};
    if (ctx.attachmentCount != null && ctx.attachmentCount! > 0) {
      out['notify.email.attachment_count'.tr] = ctx.attachmentCount.toString();
    }
    _put(out, 'notify.email.added_by', ctx.addedBy);
    return out;
  }

  static Map<String, String> employeeTaskNewComment(TaskEmailContext ctx) {
    final out = <String, String>{};
    _put(out, 'notify.email.changed_by', ctx.commenterName);
    _put(out, 'notify.email.comment_preview', truncate(ctx.commentPreview));
    return out;
  }

  static Map<String, String> employeeTaskStatusChanged(TaskEmailContext ctx) {
    final out = <String, String>{};
    _put(out, 'notify.email.new_status', ctx.newStatus);
    _put(out, 'notify.email.changed_by', ctx.changedBy);
    return out;
  }

  static Map<String, String> employeeDeadlineExtensionApproved(
    TaskEmailContext ctx,
  ) {
    final out = <String, String>{};
    _put(out, 'notify.email.due_date', ctx.newDueDate ?? ctx.dueDate);
    return out;
  }

  static Map<String, String> employeeDeadlineExtensionDenied(
    TaskEmailContext ctx,
  ) {
    final out = <String, String>{};
    _put(out, 'notify.email.denial_note', truncate(ctx.denialNote));
    _put(out, 'notify.email.due_date', ctx.dueDate);
    return out;
  }

  static Map<String, String> managerTaskWithEmployee(TaskEmailContext ctx) {
    final out = <String, String>{};
    _put(out, 'notify.email.employee', ctx.changedBy ?? ctx.addedBy);
    _put(out, 'notify.email.department', ctx.department);
    _put(out, 'notify.email.due_date', ctx.dueDate);
    return out;
  }

  static Map<String, String> managerTaskComment(TaskEmailContext ctx) {
    final out = <String, String>{};
    _put(out, 'notify.email.employee', ctx.changedBy ?? ctx.addedBy);
    _put(out, 'notify.email.update_type', ctx.newStatus);
    _put(out, 'notify.email.comment_preview', truncate(ctx.commentPreview));
    return out;
  }

  static Map<String, String> managerDeadlineExtensionRequested(
    TaskEmailContext ctx,
  ) {
    final out = <String, String>{};
    _put(out, 'notify.email.employee', ctx.changedBy ?? ctx.addedBy);
    _put(out, 'notify.email.due_date', ctx.newDueDate);
    _put(out, 'notify.email.extension_reason', truncate(ctx.extensionReason));
    return out;
  }

  static Map<String, String> managerNewTaskDepartment({
    required String department,
    required String dueDate,
    String? clientName,
  }) {
    final out = <String, String>{};
    _put(out, 'notify.email.department', department);
    _put(out, 'notify.email.due_date', dueDate);
    _put(out, 'notify.email.client', clientName);
    return out;
  }

  static Map<String, String> adminSupervisorEscalated({
    required String supervisorName,
    required String dueDate,
    String? department,
  }) {
    final out = <String, String>{};
    _put(out, 'notify.email.employee', supervisorName);
    _put(out, 'notify.email.department', department);
    _put(out, 'notify.email.due_date', dueDate);
    return out;
  }
}
