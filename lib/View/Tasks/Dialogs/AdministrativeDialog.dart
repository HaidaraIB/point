import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/AdministrationTaskModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/Dialogs/GenericTaskFormDialog.dart';
import 'package:point/View/Tasks/Dialogs/TaskFormDialogDelegate.dart';
import 'package:point/View/Tasks/Mobile/GenericTaskFormMobilePage.dart';

void administrationDialog(BuildContext context, {TaskModel? model}) {
  final ctx = Get.context;
  if (ctx != null && Responsive.isMobile(ctx)) {
    Get.to(() => GenericTaskFormMobilePage(model: model, typeForNew: '7'));
    return;
  }
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) => GenericTaskFormDialog(
      model: model,
      delegate: AdministrationTaskFormDelegate(),
    ),
  );
}

class AdministrationTaskFormDelegate extends TaskFormDialogDelegate {
  @override
  String get taskType => '7';

  @override
  String get executorDepartment => StorageKeys.departmentAdministration;

  @override
  String get fcmTitleNewTask => 'tasks.fcm.new_task_assigned'.tr;

  @override
  String fcmBodyNewTask(String taskTitle) =>
      'tasks.fcm.new_task_administration'.trParams({'title': taskTitle});

  @override
  void initFromModel(TaskModel? model) {}

  @override
  Widget buildTypeSpecificFields(BuildContext context, double dialogWidth) {
    return const SizedBox.shrink();
  }

  @override
  TaskModel buildTask(
    CommonFormData common,
    TaskModel? existing,
    HomeController controller,
  ) {
    final keepStatusUnchanged =
        controller.currentEmployee.value?.role == 'admin' ||
        controller.currentEmployee.value?.role == 'supervisor';
    final notes =
        existing != null
            ? existing.notes
            : [
                if (common.newNoteText != null &&
                    common.newNoteText!.isNotEmpty)
                  NoteModel(
                    note: common.newNoteText!,
                    byWho: common.newNoteAuthor ?? '',
                    timestamp: DateTime.now(),
                  ),
              ];
    final extra = Map<String, dynamic>.from(
      existing?.administrationModel?.extra ?? const {},
    );
    final administrationModel = AdministrationTaskModel(extra: extra);

    if (existing == null) {
      return TaskModel(
        title: common.title,
        description: common.description,
        status: StorageKeys.status_not_start_yet,
        priority: common.priority,
        fromDate: common.fromDate,
        toDate: common.toDate,
        assignedTo: common.assignedTo,
        clientName: common.clientName,
        assignedImageUrl: common.assignedImageUrl,
        actionText: '',
        files: common.files,
        type: taskType,
        administrationModel: administrationModel,
        notes: notes,
      );
    }
    return existing.copyWith(
      title: common.title,
      description: common.description,
      status: keepStatusUnchanged
          ? existing.status
          : StorageKeys.status_edit_requested,
      priority: common.priority,
      fromDate: common.fromDate,
      toDate: common.toDate,
      assignedTo: common.assignedTo,
      clientName: common.clientName,
      notes: notes,
      files: common.files,
      administrationModel: administrationModel,
    );
  }

  @override
  void dispose() {}
}
