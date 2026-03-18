// ignore_for_file: unused_local_variable, no_leading_underscores_for_local_identifiers, unnecessary_cast

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/DesignTaskModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/Mobile/DesignTaskFormMobile.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Tasks/Dialogs/TaskFormDialogHeader.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/t.dart';

void designDialog(BuildContext context, {TaskModel? model}) {
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
  RxList platforms = (model?.designDetails?.platform ?? []).obs;

  final clientController = TextEditingController(text: model?.clientName);
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
  final notesController = TextEditingController();

  DateTime? startAt = model?.fromDate;
  DateTime? endAt = model?.toDate;

  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GetBuilder<HomeController>(
          builder: (controller) {
            final dialogW = (Get.width * 0.7).clamp(300.0, Get.width - 24.0);
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
                                    labelText: 'عنوان التصميم'.tr,
                                    hintText: 'اكتب اسم التصميم'.tr,
                                    height: 42,
                                    fillColor: Colors.white,
                                    controller: titleController,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return ' ';
                                      return null;
                                    },
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                  ),
                                ),

                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: DynamicDropdown(
                                    items:
                                        controller.employees
                                            .where(
                                              (a) => a.department == 'cat2',
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
                                    label: 'المنفذ'.tr,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
                                    onChanged: (value) {
                                      if (value != null) {
                                        executorController.text =
                                            (value as EmployeeModel).id ?? '';
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
                                    label: 'نوع المهمه'.tr,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
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
                                  child: DynamicDropdown(
                                    items:
                                        controller.clients
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text('${v.name}'),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        clientController.text.isEmpty
                                            ? null
                                            : controller.clients.firstWhereOrNull(
                                              (a) =>
                                                  a.id == clientController.text,
                                            ),

                                    label: 'chooseclient'.tr,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
                                    onChanged: (value) {
                                      if (value != null) {
                                        clientController.text =
                                            (value as ClientModel).id ?? '';
                                      }
                                    },
                                    validator: (v) {
                                      if (v == null) return ' ';
                                      return null;
                                    },
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
                                      borderColor: Colors.grey.shade300,
                                      height: 42,
                                      fillColor: Colors.white,

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
                                    label: 'نوع التصميم'.tr,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
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
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
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
                                    labelText: 'عدد التصاميم'.tr,
                                    hintText: 'عدد التصاميم'.tr,
                                    height: 42,
                                    fillColor: Colors.white,
                                    controller: designsCountController,
                                    validator:
                                        (v) =>
                                            v == null || v.isEmpty ? ' ' : null,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
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
                                    labelText: 'القياسات'.tr,
                                    hintText: 'اكتب القياسات'.tr,
                                    height: 42,
                                    fillColor: Colors.white,
                                    controller: dimensionsController,

                                    validator:
                                        (val) =>
                                            val == null || val.isEmpty
                                                ? ' '
                                                : null,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                  ),
                                ),
                                // start
                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: InputText(
                                    onTap: () async {
                                      final picked = await customDatePicker(
                                        context,
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
                                    fillColor: Colors.white,
                                    textInputType: TextInputType.datetime,
                                    controller: startDateController,
                                    readOnly: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return ' ';
                                      return null;
                                    },
                                    suffixIcon: Icon(
                                      CupertinoIcons.calendar,
                                      color: Colors.grey,
                                    ),
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                  ),
                                ),

                                // end
                                SizedBox(
                                  width: (dialogW / 3 - 25).clamp(60.0, double.infinity),
                                  child: InputText(
                                    onTap: () async {
                                      final picked = await customDatePicker(
                                        context,
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
                                    fillColor: Colors.white,
                                    textInputType: TextInputType.datetime,
                                    controller: endDateController,
                                    readOnly: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return ' ';
                                      return null;
                                    },
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
                                          labelText: 'سجل الملاحظات'.tr,
                                          hintText: ''.tr,
                                          height: 250,
                                          fillColor: Colors.white,
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
                                                      Text(
                                                        note.note,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              AppColors
                                                                  .primaryfontColor,
                                                        ),
                                                      ),
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
                                          borderColor: Colors.grey.shade300,
                                        ),
                                      ),
                                    SizedBox(
                                      width: (dialogW / 2 - 25).clamp(80.0, double.infinity),
                                      child: InputText(
                                        labelText: 'notes'.tr,
                                        hintText: 'enternotes'.tr,
                                        height: 30,
                                        fillColor: Colors.white,
                                        controller: notesController,
                                        // expanded: true,
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
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
                                            fillColor: Colors.white,
                                            // controller: notesController,
                                            expanded: true,

                                            body: Container(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
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
                                                    bordersize: 5,
                                                    height: 30,
                                                    fontsize: 12,
                                                    load:
                                                        controller
                                                            .isUploading
                                                            .value,
                                                    title: 'uploadfile'.tr,
                                                    backgroundcolor:
                                                        Colors.white,
                                                    fontcolor:
                                                        AppColors
                                                            .primaryfontColor,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            borderRadius: 5,
                                            borderColor: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),

                                      SizedBox(
                                        width: (dialogW / 2 - 30).clamp(80.0, double.infinity),
                                        child: Obx(
                                          () => Column(
                                            children: [
                                              for (var filePath
                                                  in controller
                                                      .uploadedFilesPaths)
                                                Row(
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        controller
                                                            .uploadedFilesPaths
                                                            .remove(filePath);
                                                      },
                                                      child: Icon(
                                                        Icons.cancel,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                    SizedBox(width: 5),
                                                    Text(
                                                      FunHelper.getFileNameFromUrl(
                                                        filePath,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.blue,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
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
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Obx(
                              () => SizedBox(
                                width: (dialogW - 212).clamp(80.0, double.infinity),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF5C5589),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 48,
                                      vertical: 20,
                                    ),
                                  ),
                                  onPressed: () {
                                    if (_key.currentState!.validate()) {
                                      if (model == null) {
                                        controller.addTask(
                                          TaskModel(
                                            title: titleController.text,
                                            description: notesController.text,
                                            status:
                                                StorageKeys
                                                    .status_not_start_yet,
                                            priority: priorityController.text,
                                            fromDate: startAt!,
                                            toDate: endAt!,
                                            assignedTo: executorController.text,
                                            clientName: clientController.text,
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
                                                          .currentemployee
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
                                                StorageKeys
                                                    .status_edit_requested,
                                            priority: priorityController.text,
                                            fromDate: startAt!,
                                            toDate: endAt!,
                                            assignedTo: executorController.text,
                                            clientName: clientController.text,
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
                                                model.files +
                                                controller.uploadedFilesPaths
                                                    .cast<String>()
                                                    .toList(),
                                            notes:
                                                model.notes +
                                                [
                                                  if (notesController
                                                      .text
                                                      .isNotEmpty)
                                                    NoteModel(
                                                      note:
                                                          notesController.text,
                                                      byWho:
                                                          controller
                                                              .currentemployee
                                                              .value
                                                              ?.name ??
                                                          '',
                                                      timestamp: DateTime.now(),
                                                    ),
                                                ],
                                            type: '1',
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
                                    }
                                  },
                                  child:
                                      controller.isLoading.value
                                          ? Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          )
                                          : Text(
                                            "حفظ",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            SizedBox(
                              width: 160,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 20,
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text("إلغاء"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
