import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ContentWriteModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/t.dart';
import 'package:point/View/Tasks/Dialogs/GenericTaskFormDialog.dart';
import 'package:point/View/Tasks/Dialogs/TaskFormDialogDelegate.dart';
import 'package:point/View/Tasks/Mobile/GenericTaskFormMobilePage.dart';

void contentWriteDiloag(BuildContext context, {TaskModel? model}) {
  final ctx = Get.context;
  if (ctx != null && Responsive.isMobile(ctx)) {
    Get.to(() => GenericTaskFormMobilePage(model: model, typeForNew: '3'));
    return;
  }
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) => GenericTaskFormDialog(
      model: model,
      delegate: ContentWriteFormDelegate(),
    ),
  );
}

/// Delegate for ContentWrite (type '3') task form dialog.
class ContentWriteFormDelegate extends TaskFormDialogDelegate {
  final RxList<dynamic> platforms = <dynamic>[].obs;
  late final TextEditingController designTypeController;
  late final TextEditingController designsCountController;
  late final TextEditingController dimensionsController;

  ContentWriteFormDelegate() {
    designTypeController = TextEditingController();
    designsCountController = TextEditingController();
    dimensionsController = TextEditingController();
  }

  @override
  String get taskType => '3';

  @override
  String get executorDepartment => 'cat4';

  @override
  String get fcmTitleNewTask => 'tasks.fcm.new_task_assigned'.tr;

  @override
  String fcmBodyNewTask(String taskTitle) =>
      'tasks.fcm.new_task_content_write'.trParams({'title': taskTitle});

  @override
  void initFromModel(TaskModel? model) {
    if (model == null) return;
    platforms.assignAll(model.contentWriteModel?.platform ?? []);
    designTypeController.text = model.contentWriteModel?.contenttype ?? '';
    designsCountController.text = model.contentWriteModel?.designCount ?? '';
    dimensionsController.text = model.contentWriteModel?.designsDimensions ?? '';
  }

  @override
  Widget buildTypeSpecificFields(BuildContext context, double dialogWidth) {
    final w3 = (dialogWidth / 3) - 25;
    final w2 = (dialogWidth / 2) - 20;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => SizedBox(
              width: w2,
              child: DynamicDropdownMultiSelect<String>(
                items: StorageKeys.platformList.map((v) => v.tr).toList(),
                selectedValues: platforms.map((e) => e.toString()).toList(),
                label: 'platform'.tr,
                borderRadius: 5,
                borderColor: Colors.grey.shade300,
                height: 42,
                fillColor: Colors.white,
                validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                onChanged: (value) => platforms.assignAll(value),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: w3.clamp(60.0, double.infinity),
                child: DynamicDropdown<String>(
                  items: StorageKeys.contentTypes
                      .map((v) => DropdownMenuItem(value: v, child: Text(v.tr)))
                      .toList(),
                  value: designTypeController.text.isEmpty
                      ? null
                      : designTypeController.text,
                  label: 'task_details.content_type'.tr,
                  borderRadius: 5,
                  borderColor: Colors.grey.shade300,
                  height: 42,
                  fillColor: Colors.white,
                  onChanged: (value) {
                    if (value != null) designTypeController.text = value;
                  },
                  validator: (v) => v == null ? ' ' : null,
                ),
              ),
              SizedBox(
                width: w3.clamp(60.0, double.infinity),
                child: InputText(
                  labelText: 'task_details.photo_count'.tr,
                  hintText: 'task_details.photo_video_count'.tr,
                  height: 42,
                  fillColor: Colors.white,
                  controller: designsCountController,
                  validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                  borderRadius: 5,
                  borderColor: Colors.grey.shade300,
                ),
              ),
              SizedBox(
                width: w3.clamp(60.0, double.infinity),
                child: InputText(
                  labelText: 'task_details.dimensions'.tr,
                  hintText: '',
                  height: 42,
                  fillColor: Colors.white,
                  controller: dimensionsController,
                  borderRadius: 5,
                  borderColor: Colors.grey.shade300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  TaskModel buildTask(
    CommonFormData common,
    TaskModel? existing,
    HomeController controller,
  ) {
    final notes = existing != null
        ? [
            ...existing.notes,
            if (common.newNoteText != null && common.newNoteText!.isNotEmpty)
              NoteModel(
                note: common.newNoteText!,
                byWho: common.newNoteAuthor ?? '',
                timestamp: DateTime.now(),
              ),
          ]
        : [
            if (common.newNoteText != null && common.newNoteText!.isNotEmpty)
              NoteModel(
                note: common.newNoteText!,
                byWho: common.newNoteAuthor ?? '',
                timestamp: DateTime.now(),
              ),
          ];
    final contentWriteModel = ContentWriteModel(
      platform: platforms.toList(),
      contenttype: designTypeController.text,
      designCount: designsCountController.text,
      designsDimensions: dimensionsController.text.isEmpty
          ? null
          : dimensionsController.text,
    );
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
        contentWriteModel: contentWriteModel,
        notes: notes,
      );
    }
    return existing.copyWith(
      title: common.title,
      description: common.description,
      status: StorageKeys.status_edit_requested,
      priority: common.priority,
      fromDate: common.fromDate,
      toDate: common.toDate,
      assignedTo: common.assignedTo,
      clientName: common.clientName,
      notes: notes,
      files: common.files,
      contentWriteModel: contentWriteModel,
    );
  }

  @override
  void dispose() {
    designTypeController.dispose();
    designsCountController.dispose();
    dimensionsController.dispose();
  }
}
