import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/PhotographyModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Shared/form_attachment_thumbnails_grid.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/t.dart';
import 'package:point/View/Tasks/Mobile/GenericTaskFormMobilePage.dart';
import 'package:point/View/Tasks/Dialogs/task_dialog_constants.dart';
import 'package:point/View/Tasks/Shared/task_form_dialog_actions.dart';
import 'package:point/View/Tasks/Shared/task_note_body.dart';
import 'package:point/View/Tasks/Shared/task_voice_form_helpers.dart';
import 'package:point/View/Tasks/Shared/task_voice_record_field.dart';
import 'package:point/Models/VoiceRecordEntry.dart';

void photographyDialog(BuildContext context, {TaskModel? model}) {
  const otherClientValue = kTaskOtherClientSentinel;
  final ctx = Get.context;
  if (ctx != null && Responsive.isMobile(ctx)) {
    Get.to(() => GenericTaskFormMobilePage(model: model, typeForNew: '2'));
    return;
  }
  final _key = GlobalKey<FormState>();

  final titleController = TextEditingController(text: model?.title);
  final executorController = TextEditingController(text: model?.assignedTo);
  // final taskTypeController = TextEditingController(text: model?.photoGrapghyModel.);
  RxList platforms = normalizeTaskFormPlatformSelections(
    List<dynamic>.from(model?.photoGrapghyModel?.platform ?? const []),
  ).obs;

  final clientController = TextEditingController(text: model?.clientName);
  final homeController = Get.find<HomeController>();
  final isCustomClient = (clientController.text.isNotEmpty &&
          !homeController.clients.any((c) => c.id == clientController.text))
      .obs;
  final customClientController = TextEditingController(
    text: isCustomClient.value ? clientController.text : '',
  );
  final shootingloction = TextEditingController(
    text: model?.photoGrapghyModel?.shootinglocation,
  );
  final shootingtype = TextEditingController(
    text: model?.photoGrapghyModel?.shootingtype,
  );

  final priorityController = TextEditingController(text: model?.priority);
  final designsCountController = TextEditingController(
    text: model?.photoGrapghyModel?.designCount,
  );
  final shootingduration = TextEditingController(
    text: model?.photoGrapghyModel?.duration,
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
            return StatefulBuilder(
              builder: (context, setLocal) {
                return Form(
              key: _key,
              child: SizedBox(
                width: Get.width * 0.7,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: context.appTheme.navSurface,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SvgPicture.asset('assets/svgs/icon_check_circle.svg'),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'tasks.form.add_title'.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'tasks.form.fill_required'.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: (Get.width * 0.7 / 2) - 25,
                                  child: InputText(
                                    labelText: 'tasks.form.shooting_title_label'.tr,
                                    hintText: 'tasks.form.write_title_hint'.tr,
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
                                  width: (Get.width * 0.7 / 2) - 25,
                                  child: DynamicDropdown(
                                    items:
                                        controller.employees
                                            .where(
                                              (a) => a.hasDepartment(
                                                StorageKeys.departmentPhotography,
                                              ) ||
                                              (((controller.currentEmployee.value?.role ==
                                                          'admin') ||
                                                      (controller.currentEmployee.value?.role ==
                                                          'supervisor')) &&
                                                  a.id ==
                                                      controller.currentEmployee.value?.id),
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
                                            : controller.employees.firstWhere(
                                              (a) =>
                                                  a.id ==
                                                  executorController.text,
                                            ),
                                    label: 'tasks.form.select_photographer'.tr,
                                    borderRadius: 5,
                                    height: 42,
                                    onChanged: (value) {
                                      if (value != null) {
                                        executorController.text =
                                            value.id ?? '';
                                      }
                                    },
                                    validator: (v) {
                                      if (v == null) return ' ';
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
                                  width: (Get.width * 0.7 / 3) - 20,
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
                                              clientController.text = value.id ?? '';
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
                                    width: (Get.width * 0.7 / 3) - 30,

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
                                SizedBox(
                                  width: (Get.width * 0.7 / 3) - 20,
                                  child: DynamicDropdown(
                                    items:
                                        StorageKeys.shootingLocations
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(v.tr),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        shootingloction.text.isEmpty
                                            ? null
                                            : shootingloction.text,
                                    label: 'tasks.form.shooting_place'.tr,
                                    borderRadius: 5,
                                    height: 42,
                                    validator:
                                        (v) =>
                                            v == null || v.isEmpty ? ' ' : null,
                                    onChanged: (value) {
                                      if (value != null) {
                                        shootingloction.text = value;
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // مزود المحتوى
                                SizedBox(
                                  width: (Get.width * 0.7 / 3) - 25,
                                  child: DynamicDropdown(
                                    items:
                                        StorageKeys.shootingtype
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(v.tr),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        shootingtype.text.isEmpty
                                            ? null
                                            : shootingtype.text,
                                    label: 'tasks.form.photography_shooting_type'.tr,
                                    borderRadius: 5,
                                    height: 42,
                                    onChanged: (value) {
                                      if (value != null) {
                                        shootingtype.text = value;
                                      }
                                    },
                                    validator: (v) => v == null ? ' ' : null,
                                  ),
                                ),

                                // الأولوية
                                SizedBox(
                                  width: (Get.width * 0.7 / 3) - 25,
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
                                  width: (Get.width * 0.7 / 3) - 25,
                                  child: InputText(
                                    labelText: 'task_details.photo_count'.tr,
                                    hintText: 'task_details.photo_video_count'.tr,
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
                                  width: (Get.width * 0.7 / 3) - 25,
                                  child: InputText(
                                    labelText: 'tasks.form.photography_duration_label'.tr,
                                    hintText: 'tasks.form.photography_duration_hint'.tr,
                                    height: 42,
                                    controller: shootingduration,

                                    borderRadius: 5,
                                  ),
                                ),
                                // start
                                SizedBox(
                                  width: (Get.width * 0.7 / 3) - 25,
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
                                  width: (Get.width * 0.7 / 3) - 25,
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
                                        width: (Get.width * 0.7 / 2) - 25,
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
                                      width: (Get.width * 0.7 / 2) - 25,
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
                                        width: (Get.width * 0.7 / 2) - 30,
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
                                        width: (Get.width * 0.7 / 2) - 30,
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
                                                controller.uploadedFilesPaths,
                                            type: '2',
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
                                            photoGrapghyModel:
                                                PhotographyModel(
                                                  shootingtype:
                                                      shootingtype.text,
                                                  platform: platforms,
                                                  shootinglocation:
                                                      shootingloction.text,
                                                  designCount:
                                                      designsCountController
                                                          .text,
                                                  duration:
                                                      shootingduration.text,
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
                                            notes: model.notes,
                                            files:
                                                controller.uploadedFilesPaths
                                                    .cast<String>()
                                                    .toList(),
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
                                            type: '2',
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
                                            photoGrapghyModel:
                                                PhotographyModel(
                                                  shootingtype:
                                                      shootingtype.text,
                                                  platform: platforms,
                                                  shootinglocation:
                                                      shootingloction.text,
                                                  designCount:
                                                      designsCountController
                                                          .text,
                                                  duration:
                                                      shootingduration.text,
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
