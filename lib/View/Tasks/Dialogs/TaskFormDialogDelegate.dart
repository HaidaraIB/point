import 'package:flutter/material.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';

/// Common form data collected by [GenericTaskFormDialog] and passed to the
/// delegate to build the full [TaskModel].
class CommonFormData {
  final String title;
  final String description;
  final String priority;
  final DateTime fromDate;
  final DateTime toDate;
  final String assignedTo;
  final String clientName;
  final String assignedImageUrl;
  final List<NoteModel> notes;
  final String? newNoteText;
  final String? newNoteAuthor;
  final List<String> files;

  const CommonFormData({
    required this.title,
    required this.description,
    required this.priority,
    required this.fromDate,
    required this.toDate,
    required this.assignedTo,
    required this.clientName,
    required this.assignedImageUrl,
    required this.notes,
    this.newNoteText,
    this.newNoteAuthor,
    required this.files,
  });
}

/// Delegate for type-specific behavior in [GenericTaskFormDialog].
/// Each task type (Promotion, Photography, ContentWrite, etc.) implements this
/// to provide type-specific fields and task building.
abstract class TaskFormDialogDelegate {
  /// Task type string, e.g. '0' (Promotion), '3' (ContentWrite).
  String get taskType;

  /// Semantic department key for executor dropdown, e.g. 'content-writing'.
  String get executorDepartment;

  /// FCM title when a new task is assigned.
  String get fcmTitleNewTask;

  /// FCM body when a new task is assigned. [taskTitle] can be interpolated.
  String fcmBodyNewTask(String taskTitle);

  /// Initialize type-specific state from an existing task (for edit mode).
  void initFromModel(TaskModel? model);

  /// Build the type-specific form fields (inserted between client row and dates).
  Widget buildTypeSpecificFields(
    BuildContext context,
    double dialogWidth,
  );

  /// Build the full task for add or update. [existing] is null for add.
  TaskModel buildTask(
    CommonFormData common,
    TaskModel? existing,
    HomeController controller,
  );

  /// Release type-specific controllers. Called when the dialog is disposed.
  void dispose();
}
