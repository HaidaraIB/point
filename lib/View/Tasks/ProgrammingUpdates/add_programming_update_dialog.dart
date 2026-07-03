import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ProgrammingUpdateModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/form_attachment_thumbnails_grid.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/Dialogs/task_dialog_constants.dart';
import 'package:point/View/Tasks/ProgrammingUpdates/add_programming_update_mobile_page.dart';
import 'package:point/View/Tasks/Shared/task_form_dialog_actions.dart';
import 'package:point/View/Tasks/Shared/task_voice_form_helpers.dart';
import 'package:point/View/Tasks/Shared/task_voice_record_field.dart';

void showAddProgrammingUpdateDialog(
  BuildContext context, {
  ProgrammingUpdateModel? model,
}) {
  final ctx = Get.context;
  if (ctx != null && Responsive.isMobile(ctx)) {
    Get.to(() => AddProgrammingUpdateMobilePage(model: model));
    return;
  }

  const otherClientValue = kTaskOtherClientSentinel;
  final titleController = TextEditingController(text: model?.title);
  final executorController = TextEditingController(text: model?.assignedTo);
  final clientController = TextEditingController(text: model?.clientName);
  final homeController = Get.find<HomeController>();
  final isCustomClient = (clientController.text.isNotEmpty &&
          !homeController.clients.any((c) => c.id == clientController.text))
      .obs;
  final customClientController = TextEditingController(
    text: isCustomClient.value ? clientController.text : '',
  );
  final categoryController = TextEditingController(text: model?.category);
  final priorityController = TextEditingController(text: model?.priority);
  final startDateController = TextEditingController(
    text: FunHelper.formatdate(model?.fromDate) ?? '',
  );
  final endDateController = TextEditingController(
    text: FunHelper.formatdate(model?.toDate) ?? '',
  );
  final filesurlController = TextEditingController(text: model?.fileurl);
  final contenturlController = TextEditingController(text: model?.contenturl);
  final aboutTaskController = TextEditingController(text: model?.aboutTask);
  final notesController = TextEditingController(text: model?.description);

  DateTime? startAt = model?.fromDate;
  DateTime? endAt = model?.toDate;
  var voiceRecords = voiceRecordsFromUpdate(model);

  homeController.uploadedFilesPaths.assignAll(List.from(model?.files ?? []));

  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GetBuilder<HomeController>(
          builder: (controller) {
            return StatefulBuilder(
              builder: (context, setLocal) {
                return SizedBox(
                  width: Get.width * 0.7,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.update, color: Colors.white),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'programming.updates.form_title'.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: InputText(
                                      labelText: 'task_details.task_title'.tr,
                                      hintText: 'tasks.form.write_title_hint'.tr,
                                      height: 42,
                                      fillColor: Colors.white,
                                      controller: titleController,
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DynamicDropdown(
                                      items: controller.employees
                                          .where(
                                            (a) =>
                                                a.hasDepartment(
                                                  StorageKeys
                                                      .departmentProgramming,
                                                ) ||
                                                (((controller.currentEmployee
                                                                .value?.role ==
                                                            'admin') ||
                                                        (controller
                                                                .currentEmployee
                                                                .value
                                                                ?.role ==
                                                            'supervisor')) &&
                                                    a.id ==
                                                        controller
                                                            .currentEmployee
                                                            .value
                                                            ?.id),
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
                                      value: executorController.text.isEmpty
                                          ? null
                                          : controller.employees.firstWhereOrNull(
                                              (a) =>
                                                  a.id ==
                                                  executorController.text,
                                            ),
                                      label: 'tasks.form.select_executor'.tr,
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                      height: 42,
                                      fillColor: Colors.white,
                                      onChanged: (value) {
                                        if (value != null) {
                                          executorController.text =
                                              value.id ?? '';
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Obx(
                                () => DynamicDropdown<dynamic>(
                                  items: [
                                    ...controller.clients.map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v.name ?? ''),
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
                                          : controller.clients
                                              .firstWhereOrNull(
                                                (a) =>
                                                    a.id ==
                                                    clientController.text,
                                              )),
                                  label: 'chooseclient'.tr,
                                  borderRadius: 5,
                                  borderColor: Colors.grey.shade300,
                                  height: 42,
                                  fillColor: Colors.white,
                                  onChanged: (value) {
                                    if (value == otherClientValue) {
                                      isCustomClient.value = true;
                                      clientController.text = '';
                                    } else if (value != null) {
                                      isCustomClient.value = false;
                                      clientController.text = value.id ?? '';
                                    }
                                  },
                                ),
                              ),
                              if (isCustomClient.value)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: InputText(
                                    labelText:
                                        'tasks.form.client_name_label'.tr,
                                    hintText: 'tasks.form.client_name_hint'.tr,
                                    height: 42,
                                    fillColor: Colors.white,
                                    controller: customClientController,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: InputText(
                                      labelText:
                                          'task_details.content_link'.tr,
                                      hintText: '',
                                      height: 42,
                                      fillColor: Colors.white,
                                      controller: contenturlController,
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InputText(
                                      labelText: 'task_details.files_link'.tr,
                                      hintText: '',
                                      height: 42,
                                      fillColor: Colors.white,
                                      controller: filesurlController,
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DynamicDropdown<String>(
                                      items: StorageKeys.priority
                                          .map(
                                            (v) => DropdownMenuItem(
                                              value: v,
                                              child: Text(v.tr),
                                            ),
                                          )
                                          .toList(),
                                      value: priorityController.text.isEmpty
                                          ? null
                                          : priorityController.text,
                                      label: 'priortity'.tr,
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                      height: 42,
                                      fillColor: Colors.white,
                                      onChanged: (value) {
                                        if (value != null) {
                                          priorityController.text = value;
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InputText(
                                      labelText: 'task_details.category'.tr,
                                      hintText: '',
                                      height: 42,
                                      fillColor: Colors.white,
                                      controller: categoryController,
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: InputText(
                                      onTap: () async {
                                        final picked = await customDatePicker(
                                          context,
                                          initialDateTime: startAt,
                                        );
                                        if (picked != null) {
                                          setLocal(() {
                                            startAt = picked;
                                            startDateController.text =
                                                DateFormat(
                                                  'dd MM yyyy - hh:mm a',
                                                ).format(picked.toLocal());
                                          });
                                        }
                                      },
                                      labelText: 'startat'.tr,
                                      hintText: '1/10/2025'.tr,
                                      height: 42,
                                      fillColor: Colors.white,
                                      textInputType: TextInputType.datetime,
                                      controller: startDateController,
                                      readOnly: true,
                                      suffixIcon: Icon(
                                        CupertinoIcons.calendar,
                                        color: Colors.grey,
                                      ),
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InputText(
                                      onTap: () async {
                                        final picked = await customDatePicker(
                                          context,
                                          initialDateTime: endAt,
                                        );
                                        if (picked != null) {
                                          setLocal(() {
                                            endAt = picked;
                                            endDateController.text =
                                                DateFormat(
                                                  'dd MM yyyy - hh:mm a',
                                                ).format(picked.toLocal());
                                          });
                                        }
                                      },
                                      labelText: 'endat'.tr,
                                      hintText: '1/10/2026'.tr,
                                      height: 42,
                                      fillColor: Colors.white,
                                      textInputType: TextInputType.datetime,
                                      controller: endDateController,
                                      readOnly: true,
                                      suffixIcon: Icon(
                                        CupertinoIcons.calendar,
                                        color: Colors.grey,
                                      ),
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              InputText(
                                labelText: 'tasks.form.about_task_label'.tr,
                                hintText: 'tasks.form.about_task_hint'.tr,
                                height: 80,
                                fillColor: Colors.white,
                                controller: aboutTaskController,
                                expanded: true,
                                borderRadius: 5,
                                borderColor: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              InputText(
                                labelText: 'notes'.tr,
                                hintText: 'enternotes'.tr,
                                height: 60,
                                fillColor: Colors.white,
                                controller: notesController,
                                borderRadius: 5,
                                borderColor: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () async {
                                  final files =
                                      await controller.pickMultiFiles();
                                  for (final file in files) {
                                    controller.uploadFiles(
                                      filePathOrBytes: file.bytes!,
                                      fileName: file.name,
                                    );
                                  }
                                },
                                child: InputText(
                                  labelText: 'dragfile'.tr,
                                  hintText: '',
                                  enable: false,
                                  height: 80,
                                  fillColor: Colors.white,
                                  expanded: true,
                                  body: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    color: Colors.grey.shade200,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Text('dragfile'.tr),
                                        ),
                                        MainButton(
                                          width: 100,
                                          borderSize: 5,
                                          height: 30,
                                          fontSize: 12,
                                          load: controller.isUploading.value,
                                          title: 'uploadfile'.tr,
                                          backgroundColor: Colors.white,
                                          fontColor: AppColors.primaryfontColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                  borderRadius: 5,
                                  borderColor: Colors.grey.shade300,
                                ),
                              ),
                              Obx(
                                () => FormAttachmentThumbnailsGrid(
                                  urls: controller.uploadedFilesPaths
                                      .map((e) => e.toString())
                                      .toList(),
                                  onRemoveUrl: (u) {
                                    controller.uploadedFilesPaths.removeWhere(
                                      (e) => e.toString() == u,
                                    );
                                  },
                                  onOpenUrl: (u) async =>
                                      openUrlPreferInAppMedia(u),
                                  spacing: 6,
                                  tileExtent: 88,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TaskVoiceRecordField(
                                records: voiceRecords,
                                onRecordsChanged: (v) =>
                                    setLocal(() => voiceRecords = v),
                              ),
                            ],
                          ),
                        ),
                        Obx(
                          () => TaskFormDialogActions(
                            isLoading: controller.isLoading.value,
                            onCancel: () => Navigator.pop(dialogContext),
                            onSave: () async {
                              final resolvedClient = isCustomClient.value
                                  ? customClientController.text.trim()
                                  : clientController.text.trim();
                              final payload = applyVoiceRecordsToUpdate(
                                ProgrammingUpdateModel(
                                  id: model?.id,
                                  title: titleController.text.trim(),
                                  description: notesController.text.trim(),
                                  assignedTo: executorController.text.trim(),
                                  clientName: resolvedClient,
                                  priority: priorityController.text.trim(),
                                  fromDate: startAt,
                                  toDate: endAt,
                                  contenturl:
                                      contenturlController.text.trim(),
                                  category: categoryController.text.trim(),
                                  fileurl: filesurlController.text.trim(),
                                  aboutTask: aboutTaskController.text.trim(),
                                  files: controller.uploadedFilesPaths
                                      .cast<String>()
                                      .toList(),
                                  status: model?.status ??
                                      StorageKeys
                                          .programmingUpdateStatusPending,
                                ),
                                voiceRecords,
                              );
                              final ok = model == null
                                  ? await controller.addProgrammingUpdate(
                                      payload,
                                    )
                                  : await controller.updateProgrammingUpdate(
                                      payload,
                                    );
                              if (ok) {
                                Get.back();
                                controller.uploadedFilesPaths.clear();
                                FunHelper.showSnackbar(
                                  'common.success'.tr,
                                  'programming.updates.saved'.tr,
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: Colors.green,
                                  colorText: Colors.white,
                                );
                              }
                            },
                          ),
                        ),
                      ],
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
