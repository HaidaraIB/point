import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/DesignTaskModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Shared/form_attachment_thumbnails_grid.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/Mobile/DesignTaskFormMobile.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Tasks/Dialogs/TaskFormDialogHeader.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/t.dart';
import 'package:point/View/Tasks/Dialogs/task_dialog_constants.dart';
import 'package:point/View/Tasks/Shared/task_form_dialog_actions.dart';
import 'package:point/View/Tasks/Shared/task_note_body.dart';
import 'package:point/View/Tasks/Shared/task_voice_form_helpers.dart';
import 'package:point/View/Tasks/Shared/task_voice_record_field.dart';
import 'package:point/Models/VoiceRecordEntry.dart';

void designDialog(BuildContext context, {TaskModel? model}) {
  const otherClientValue = kTaskOtherClientSentinel;
  // Use current context so mobile check works when called after navigation (e.g. from TaskDetailsMobile).
  final ctx = Get.context;
  if (ctx != null && Responsive.isMobile(ctx)) {
    Get.to(() => DesignTaskFormMobilePage(model: model));
    return;
  }

  final _key = GlobalKey<FormState>();

  final titleController = TextEditingController(text: model?.title);
  final executorController = TextEditingController(text: model?.assignedTo);
  final taskTypeController = TextEditingController(
    text: model?.designDetails?.taskType,
  );
  RxList platforms = normalizeTaskFormPlatformSelections(
    List<dynamic>.from(model?.designDetails?.platform ?? const []),
  ).obs;

  final clientController = TextEditingController(text: model?.clientName);
  final homeController = Get.find<HomeController>();
  final isCustomClient = (clientController.text.isNotEmpty &&
          !homeController.clients.any((c) => c.id == clientController.text))
      .obs;
  final customClientController = TextEditingController(
    text: isCustomClient.value ? clientController.text : '',
  );
  final designTypeController = TextEditingController(
    text: model?.designDetails?.designType,
  );
  final priorityController = TextEditingController(text: model?.priority);
  final designsCountController = TextEditingController(
    text: model?.designDetails?.designCount,
  );
  final dimensionsController = TextEditingController(
    text: model?.designDetails?.designsDimensions,
  );
  final startDateController = TextEditingController(
    text: FunHelper.formatdate(model?.fromDate),
  );
  final endDateController = TextEditingController(
    text: FunHelper.formatdate(model?.toDate),
  );
  // final attachmentController = TextEditingController();
  final notesController = TextEditingController(text: model?.description ?? '');

  DateTime? startAt = model?.fromDate;
  DateTime? endAt = model?.toDate;
  var voiceRecords = voiceRecordsFromTask(model);

  Get.find<HomeController>().uploadedFilesPaths.assignAll(
    List.from(model?.files ?? []),
  );

  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: context.appTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GetBuilder<HomeController>(
          builder: (controller) {
            final dialogW = (Get.width * 0.7).clamp(300.0, Get.width - 24.0);
            return StatefulBuilder(
              builder: (context, setLocal) {
                return Form(
              key: _key,
              child: SizedBox(
                width: dialogW,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TaskFormDialogHeader(),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: InputText(
                                    labelText: 'tasks.form.design_title_label'.tr,
                                    hintText: 'tasks.form.design_name_hint'.tr,
                                    height: 42,
                                    controller: titleController,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return ' ';
                                      return null;
                                    },
                                    borderRadius: 5,
                                  ),
                                ),

                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: DynamicDropdown(
                                    items:
                                        controller.employees
                                            .where(
                                              (a) => a.canBeAssignedAsExecutorFor(
                                                StorageKeys.departmentDesign,
                                              ),
                                            )
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(
                                                  '${v.name} (${v.role})',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        executorController.text.isEmpty
                                            ? null
                                            : controller.employees
                                                .firstWhereOrNull(
                                                  (a) =>
                                                      a.id ==
                                                      executorController.text,
                                                ),
                                    label: 'content.dialog.executor'.tr,
                                    borderRadius: 5,
                                    height: 42,
                                    onChanged: (value) {
                                      if (value != null) {
                                        executorController.text =
                                            (value).id ?? '';
                                      }
                                    },
                                    validator: (v) {
                                      if (v == null) return ' ';
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: DynamicDropdown(
                                    items:
                                        StorageKeys.tasktype
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(v.tr),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        taskTypeController.text.isEmpty
                                            ? null
                                            : taskTypeController.text,
                                    label: 'tasks.form.task_type_label'.tr,
                                    borderRadius: 5,
                                    height: 42,
                                    onChanged: (value) {
                                      if (value != null) {
                                        taskTypeController.text = value;
                                      }
                                    },
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return ' ';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: (dialogW / 2 - 20).clamp(80.0, double.infinity),
                                  child: Obx(
                                    () => Column(
                                      children: [
                                        DynamicDropdown<dynamic>(
                                          items: [
                                            ...controller.clients.map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text('${v.name}'),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: otherClientValue,
                                              child: Text('tasks.other_client'.tr),
                                            ),
                                          ],
                                          value: isCustomClient.value
                                              ? otherClientValue
                                              : (clientController.text.isEmpty
                                                  ? null
                                                  : controller.clients.firstWhereOrNull(
                                                      (a) => a.id == clientController.text,
                                                    )),
                                          label: 'chooseclient'.tr,
                                          borderRadius: 5,
                                          height: 42,
                                          onChanged: (value) {
                                            if (value == otherClientValue) {
                                              isCustomClient.value = true;
                                              clientController.text = '';
                                            } else if (value != null) {
                                              isCustomClient.value = false;
                                              clientController.text = (value as ClientModel).id ?? '';
                                            }
                                          },
                                          validator: (v) {
                                            if (v == null) return ' ';
                                            return null;
                                          },
                                        ),
                                        if (isCustomClient.value)
                                          InputText(
                                            labelText: 'tasks.form.client_name_label'.tr,
                                            hintText: 'tasks.form.client_name_hint'.tr,
                                            height: 42,
                                            controller: customClientController,
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty) ? ' ' : null,
                                            borderRadius: 5,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),

                                Obx(
                                  () => SizedBox(
                                    width: (dialogW / 2 - 25).clamp(80.0, double.infinity),

                                    child: DynamicDropdownMultiSelect(
                                      items:
                                          StorageKeys.platformList
                                              .map((v) => v.tr)
                                              .toList(),
                                      selectedValues: platforms.toList(),
                                      label: 'platform'.tr,
                                      borderRadius: 5,
                                      height: 42,

                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return ' ';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        platforms.assignAll(value);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // مزود المحتوى
                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: DynamicDropdown(
                                    items:
                                        StorageKeys.designTypes
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(v.tr),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        designTypeController.text.isEmpty
                                            ? null
                                            : designTypeController.text,
                                    label: 'tasks.form.design_type_label'.tr,
                                    borderRadius: 5,
                                    height: 42,
                                    onChanged: (value) {
                                      if (value != null) {
                                        designTypeController.text = value;
                                      }
                                    },
                                    validator: (v) => v == null ? ' ' : null,
                                  ),
                                ),

                                // الأولوية
                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: DynamicDropdown(
                                    items:
                                        StorageKeys.priority
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(v.tr),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        priorityController.text.isEmpty
                                            ? null
                                            : priorityController.text,
                                    label: 'priortity'.tr,
                                    borderRadius: 5,
                                    height: 42,
                                    onChanged: (value) {
                                      if (value != null) {
                                        priorityController.text =
                                            value.toString();
                                      }
                                    },
                                    validator: (v) => v == null ? ' ' : null,
                                  ),
                                ),

                                // العلامات
                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: InputText(
                                    labelText: 'task_details.design_count'.tr,
                                    hintText: 'task_details.design_count'.tr,
                                    height: 42,
                                    controller: designsCountController,
                                    validator:
                                        (v) =>
                                            v == null || v.isEmpty ? ' ' : null,
                                    borderRadius: 5,
                                  ),
                                ),
                              ],
                            ),

                            // صف 4: تاريخ البدء - تاريخ الانتهاء - رفع ملف
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: InputText(
                                    labelText: 'task_details.dimensions'.tr,
                                    hintText: 'tasks.form.write_dimensions_hint'.tr,
                                    height: 42,
                                    controller: dimensionsController,

                                    validator:
                                        (val) =>
                                            val == null || val.isEmpty
                                                ? ' '
                                                : null,
                                    borderRadius: 5,
                                  ),
                                ),
                                // start
                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: InputText(
                                    onTap: () async {
                                      final picked = await customDatePicker(
                                        context,
                                        initialDateTime: startAt,
                                      );
                                      if (picked != null) {
                                        startAt = picked;
                                        startDateController.text = DateFormat(
                                          'dd MM yyyy - hh:mm a',
                                        ).format(picked.toLocal());
                                      }
                                    },
                                    labelText: 'startat'.tr,
                                    hintText: '1/10/2025'.tr,
                                    height: 42,
                                    textInputType: TextInputType.datetime,
                                    controller: startDateController,
                                    readOnly: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return ' ';
                                      return null;
                                    },
                                    suffixIcon: Icon(
                                      CupertinoIcons.calendar,
                                      color: context.appTheme.secondaryText,
                                    ),
                                    borderRadius: 5,
                                  ),
                                ),

                                // end
                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: InputText(
                                    onTap: () async {
                                      final picked = await customDatePicker(
                                        context,
                                        initialDateTime: endAt,
                                      );
                                      if (picked != null) {
                                        endAt = picked;
                                        endDateController.text = DateFormat(
                                          'dd MM yyyy - hh:mm a',
                                        ).format(picked.toLocal());
                                      }
                                    },
                                    labelText: 'endat'.tr,
                                    hintText: '1/10/2026'.tr,
                                    height: 42,
                                    textInputType: TextInputType.datetime,
                                    controller: endDateController,
                                    readOnly: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return ' ';
                                      return null;
                                    },
                                    suffixIcon: Icon(
                                      CupertinoIcons.calendar,
                                      color: context.appTheme.secondaryText,
                                    ),
                                    borderRadius: 5,
                                  ),
                                ),
                              ],
                            ),

                            // الملاحظات (مربع كبير)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,

                              children: [
                                Column(
                                  children: [
                                    if (model != null)
                                      SizedBox(
                                        width: (dialogW / 2 - 25).clamp(80.0, double.infinity),
                                        child: InputText(
                                          labelText: 'tasks.form.notes_log'.tr,
                                          hintText: ''.tr,
                                          height: 250,
                                          enable: false,
                                          // controller: notesController,
                                          body: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                for (var note in model.notes)
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      TaskNoteBody(note: note),
                                                      Text(
                                                        note.byWho,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                      SizedBox(height: 5),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                          expanded: true,
                                          borderRadius: 5,
                                        ),
                                      ),
                                    SizedBox(
                                      width: (dialogW / 2 - 25).clamp(80.0, double.infinity),
                                      child: InputText(
                                        labelText: 'notes'.tr,
                                        hintText: 'enternotes'.tr,
                                        height: 30,
                                        controller: notesController,
                                        // expanded: true,
                                        borderRadius: 5,
                                      ),
                                    ),
                                  ],
                                ),
                                Obx(
                                  () => Column(
                                    children: [
                                      SizedBox(
                                        width: (dialogW / 2 - 30).clamp(80.0, double.infinity),
                                        child: GestureDetector(
                                          onTap: () async {
                                            final files =
                                                await controller
                                                    .pickMultiFiles();
                                            for (var file in files) {
                                              controller.uploadFiles(
                                                filePathOrBytes: file.bytes!,
                                                fileName: file.name,
                                              );
                                            }
                                          },
                                          child: InputText(
                                            labelText: 'dragfile'.tr,
                                            hintText: ''.tr,
                                            enable: false,
                                            height: 100,
                                            // controller: notesController,
                                            expanded: true,

                                            body: Container(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: context.appTheme.unselected,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Container(
                                                    margin:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                    child: Text(
                                                      'dragfile'.tr,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  MainButton(
                                                    width: 100,
                                                    borderSize: 5,
                                                    height: 30,
                                                    fontSize: 12,
                                                    load:
                                                        controller
                                                            .isUploading
                                                            .value,
                                                    title: 'uploadfile'.tr,
                                                    backgroundColor: context.appTheme.cardSurface,
                                                    fontColor:
                                                        AppColors
                                                            .primaryfontColor,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            borderRadius: 5,
                                          ),
                                        ),
                                      ),

                                      SizedBox(
                                        width: (dialogW / 2 - 30).clamp(80.0, double.infinity),
                                        child: Obx(
                                          () => FormAttachmentThumbnailsGrid(
                                            urls:
                                                controller.uploadedFilesPaths
                                                    .map((e) => e.toString())
                                                    .toList(),
                                            onRemoveUrl: (u) {
                                              controller.uploadedFilesPaths
                                                  .removeWhere(
                                                    (e) => e.toString() == u,
                                                  );
                                            },
                                            onOpenUrl: (u) async => await openUrlPreferInAppMedia(u),
                                            spacing: 6,
                                            tileExtent: 88,
                                            closeButtonSize: 20,
                                            closeIconSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TaskVoiceRecordField(
                          records: voiceRecords,
                          onRecordsChanged: (v) =>
                              setLocal(() => voiceRecords = v),
                        ),
                      ),

                      Obx(
                        () => TaskFormDialogActions(
                          isLoading: controller.isLoading.value,
                          onSave: () {
                                    final fallbackDate = DateTime.now();
                                    final effectiveStartAt = startAt ?? fallbackDate;
                                    final effectiveEndAt = endAt ?? effectiveStartAt;
                                    final resolvedClientName = isCustomClient.value
                                        ? customClientController.text.trim()
                                        : clientController.text.trim();
                                    if (model == null) {
                                        controller.addTask(
                                          TaskModel(
                                            title: titleController.text,
                                            description: notesController.text,
                                            status:
                                                StorageKeys
                                                    .status_not_start_yet,
                                            priority: priorityController.text,
                                            fromDate: effectiveStartAt,
                                            toDate: effectiveEndAt,
                                            assignedTo: executorController.text,
                                            clientName: resolvedClientName,
                                            assignedImageUrl:
                                                controller.employees
                                                    .firstWhereOrNull(
                                                      (a) =>
                                                          a.id ==
                                                          executorController
                                                              .text,
                                                    )
                                                    ?.image ??
                                                '',
                                            notes: [
                                              if (notesController
                                                  .text
                                                  .isNotEmpty)
                                                NoteModel(
                                                  note: notesController.text,
                                                  byWho:
                                                      controller
                                                          .currentEmployee
                                                          .value
                                                          ?.name ??
                                                      '',
                                                  timestamp: DateTime.now(),
                                                ),
                                            ],
                                            actionText: '',
                                            files:
                                                controller.uploadedFilesPaths,
                                            type: '1',
                                            voiceRecords: voiceRecords,
                                            voiceRecordUrl:
                                                VoiceRecordEntry.primaryUrl(
                                              voiceRecords,
                                            ),
                                            voiceRecordDurationSec:
                                                VoiceRecordEntry
                                                    .primaryDurationSec(
                                              voiceRecords,
                                            ),
                                            designDetails: DesignTaskModel(
                                              designsDimensions:
                                                  dimensionsController.text,
                                              taskType: taskTypeController.text,
                                              platform: platforms,
                                              designType:
                                                  designTypeController.text,
                                              designCount:
                                                  designsCountController.text,
                                            ),
                                          ),
                                        );
                                        Get.back();
                                        controller.uploadedFilesPaths.clear();
                                      } else {
                                        controller.updateTask(
                                          TaskModel(
                                            id: model.id,
                                            title: titleController.text,
                                            description: notesController.text,
                                            status:
                                                ((controller.currentEmployee.value?.role ==
                                                            'admin') ||
                                                        (controller.currentEmployee.value?.role ==
                                                            'supervisor'))
                                                    ? model.status
                                                    : StorageKeys
                                                        .status_edit_requested,
                                            priority: priorityController.text,
                                            fromDate: effectiveStartAt,
                                            toDate: effectiveEndAt,
                                            assignedTo: executorController.text,
                                            clientName: resolvedClientName,
                                            assignedImageUrl:
                                                controller.employees
                                                    .firstWhereOrNull(
                                                      (a) =>
                                                          a.id ==
                                                          executorController
                                                              .text,
                                                    )
                                                    ?.image ??
                                                '',
                                            actionText: '',
                                            files:
                                                controller.uploadedFilesPaths
                                                    .cast<String>()
                                                    .toList(),
                                            notes: model.notes,
                                            type: '1',
                                            voiceRecords: voiceRecords,
                                            voiceRecordUrl:
                                                VoiceRecordEntry.primaryUrl(
                                              voiceRecords,
                                            ),
                                            voiceRecordDurationSec:
                                                VoiceRecordEntry
                                                    .primaryDurationSec(
                                              voiceRecords,
                                            ),
                                            designDetails: DesignTaskModel(
                                              designsDimensions:
                                                  dimensionsController.text,
                                              taskType: taskTypeController.text,
                                              platform: platforms,
                                              designType:
                                                  designTypeController.text,
                                              designCount:
                                                  designsCountController.text,
                                            ),
                                          ),
                                        );
                                        Get.back();
                                        controller.uploadedFilesPaths.clear();
                                      }
                          },
                          saveLabel: (model != null &&
                                  ((controller.currentEmployee.value?.role ==
                                          'admin') ||
                                      (controller.currentEmployee.value?.role ==
                                          'supervisor')))
                              ? 'edit'.tr
                              : 'common.save'.tr,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
              },
            );
          },
        ),
      );
    },
  );
}
