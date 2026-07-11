import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/PromotionModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Shared/form_attachment_thumbnails_grid.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/MultiSelectDropDown.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/t.dart';
import 'package:point/View/Tasks/Mobile/GenericTaskFormMobilePage.dart';
import 'package:point/View/Tasks/Dialogs/task_dialog_constants.dart';
import 'package:point/View/Tasks/Shared/task_form_dialog_actions.dart';
import 'package:point/View/Tasks/Shared/task_voice_form_helpers.dart';
import 'package:point/View/Tasks/Shared/task_voice_record_field.dart';
import 'package:point/Models/VoiceRecordEntry.dart';
import 'package:point/Utils/app_theme_extension.dart';

void showPromotionDialog(BuildContext context, {TaskModel? model}) {
  const otherClientValue = kTaskOtherClientSentinel;
  final ctx = Get.context;
  if (ctx != null && Responsive.isMobile(ctx)) {
    Get.to(() => GenericTaskFormMobilePage(model: model, typeForNew: '0'));
    return;
  }
  // ✅ Controllers
  final titleController = TextEditingController(text: model?.title);
  final executorController = TextEditingController(text: model?.assignedTo);
  // final taskTypeController = TextEditingController(

  // );
  RxList platforms = normalizeTaskFormPlatformSelections(
    List<dynamic>.from(model?.promotionModel?.platforms ?? const []),
  ).obs;

  final clientcontroller = TextEditingController(text: model?.clientName);
  final homeController = Get.find<HomeController>();
  final isCustomClient = (clientcontroller.text.isNotEmpty &&
          !homeController.clients.any((c) => c.id == clientcontroller.text))
      .obs;
  final customClientController = TextEditingController(
    text: isCustomClient.value ? clientcontroller.text : '',
  );
  // final designTypeController = TextEditingController();
  final priorityController = TextEditingController(text: model?.priority);
  final campaignReasonController = TextEditingController(
    text: model?.promotionModel?.target,
  );
  final marksController = TextEditingController(
    text: model?.promotionModel?.tags,
  );
  final durationController = TextEditingController(
    text: model?.promotionModel?.duration,
  );
  final campaignBudgetController = TextEditingController(
    text: model?.promotionModel?.campaignBudget,
  );
  List<String> countriesList = model?.promotionModel?.countries ?? [];
  List<String> interestsList = model?.promotionModel?.interests ?? [];
  List<String> cityList = model?.promotionModel?.cities ?? [];
  final tagsController = TextEditingController(
    text: model?.promotionModel?.ageRanges,
  );
  List<String> specializationList =
      model?.promotionModel?.specializations ?? [];
  final startDateController = TextEditingController(
    text: FunHelper.formatdate(model?.fromDate),
  );
  final endDateController = TextEditingController(
    text: FunHelper.formatdate(model?.toDate),
  );
  final attachmentController = TextEditingController(
    text: model?.promotionModel?.attachementurl,
  );
  final notesController = TextEditingController(text: model?.description ?? '');

  Get.find<HomeController>().uploadedFilesPaths.assignAll(
      List.from(model?.files ?? []));

  DateTime? startAt = model?.fromDate;
  DateTime? endAt = model?.toDate;
  var voiceRecords = voiceRecordsFromTask(model);

  var _key = GlobalKey<FormState>();

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
              builder: (context, setstate) {
                return Form(
                  key: _key,
                  child: SizedBox(
                    width: Get.width * 0.7,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
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

                          // Content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // 🔹 اسم الحملة
                                SizedBox(
                                  width: (Get.width * 0.7) - 30,
                                  child: InputText(
                                    labelText: 'campainname'.tr,
                                    hintText: 'entercampainname'.tr,
                                    height: 42,
                                    controller: titleController,
                                    validator:
                                        (v) =>
                                            v == null || v.isEmpty ? ' ' : null,
                                    borderRadius: 5,
                                  ),
                                ),

                                // 🔹 الصف الأول
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // العميل
                                    SizedBox(
                                      width: (Get.width * 0.7 / 3) - 25,
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
                                                  : (clientcontroller.text.isEmpty
                                                      ? null
                                                      : controller.clients.firstWhereOrNull(
                                                          (a) => a.id == clientcontroller.text,
                                                        )),
                                              label: 'chooseclient'.tr,
                                              borderRadius: 5,
                                              height: 42,
                                              onChanged: (value) {
                                                if (value == otherClientValue) {
                                                  isCustomClient.value = true;
                                                  clientcontroller.text = '';
                                                } else if (value != null) {
                                                  isCustomClient.value = false;
                                                  clientcontroller.text = value.id ?? '';
                                                }
                                              },
                                              validator: (v) => v == null ? ' ' : null,
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

                                    // سبب الحملة
                                    SizedBox(
                                      width: (Get.width * 0.7 / 3) - 25,
                                      child: DynamicDropdown(
                                        items:
                                            StorageKeys.campaignTarget
                                                .map(
                                                  (v) => DropdownMenuItem(
                                                    value: v,
                                                    child: Text(v.tr),
                                                  ),
                                                )
                                                .toList(),
                                        value:
                                            campaignReasonController
                                                    .text
                                                    .isEmpty
                                                ? null
                                                : campaignReasonController.text,
                                        label: 'campainreason'.tr,
                                        borderRadius: 5,
                                        height: 42,
                                        onChanged: (value) {
                                          if (value != null) {
                                            campaignReasonController.text =
                                                value.toString();
                                          }
                                        },
                                        validator:
                                            (v) => v == null ? ' ' : null,
                                      ),
                                    ),

                                    // المنصة
                                    Obx(
                                      () => SizedBox(
                                        width: (Get.width * 0.7 / 3) - 25,

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

                                // 🔹 الصف الثاني
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: (Get.width * 0.7 / 3) - 25,
                                      child: DynamicDropdown(
                                        items:
                                            controller.employees
                                                .where(
                                                  (a) => a.hasDepartment(
                                                    StorageKeys.departmentPromotion,
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
                                                : controller.employees
                                                    .firstWhere(
                                                      (a) =>
                                                          a.id ==
                                                          executorController
                                                              .text,
                                                    ),
                                        label: 'content.dialog.executor'.tr,
                                        borderRadius: 5,
                                        height: 42,
                                        onChanged: (value) {
                                          if (value != null) {
                                            executorController.text =
                                                value.id ?? '';
                                          }
                                        },
                                        validator:
                                            (v) => v == null ? ' ' : null,
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
                                        validator:
                                            (v) => v == null ? ' ' : null,
                                      ),
                                    ),

                                    // العلامات
                                    SizedBox(
                                      width: (Get.width * 0.7 / 3) - 25,
                                      child: InputText(
                                        labelText: 'marks'.tr,
                                        hintText: 'addmark'.tr,
                                        height: 42,
                                        controller: marksController,
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                        borderRadius: 5,
                                      ),
                                    ),
                                  ],
                                ),

                                // 🔹 المدة + الميزانية
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: (Get.width * 0.7 / 2) - 25,
                                      child: InputText(
                                        labelText: 'task_details.duration'.tr,
                                        hintText: 'promotion.campaign_duration_hint'.tr,

                                        height: 42,
                                        controller: durationController,

                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                        borderRadius: 5,
                                      ),
                                    ),
                                    SizedBox(
                                      width: (Get.width * 0.7 / 2) - 25,
                                      child: InputText(
                                        labelText:
                                            'promotion.campaign_budget'.tr,
                                        hintText:
                                            'promotion.campaign_budget_hint'
                                                .tr,
                                        height: 42,
                                        controller: campaignBudgetController,
                                        borderRadius: 5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // 🔹 التواريخ
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: (Get.width * 0.7 / 2) - 25,
                                      child: InputText(
                                        onTap: () async {
                                          await customDatePicker(
                                            context,
                                            initialDateTime: startAt,
                                          ).then((
                                            picked,
                                          ) {
                                            if (picked != null) {
                                              startAt = picked;
                                              startDateController.text =
                                                  "${picked.toLocal()}".split(
                                                    " ",
                                                  )[0];
                                            }
                                          });
                                        },
                                        labelText: 'startat'.tr,
                                        hintText: '1/10/2025'.tr,
                                        height: 42,
                                        textInputType: TextInputType.datetime,
                                        controller: startDateController,
                                        readOnly: true,
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                        suffixIcon: Icon(
                                          CupertinoIcons.calendar,
                                          color: context.appTheme.secondaryText,
                                        ),
                                        borderRadius: 5,
                                      ),
                                    ),

                                    SizedBox(
                                      width: (Get.width * 0.7 / 2) - 25,
                                      child: InputText(
                                        labelText: 'endat'.tr,
                                        hintText: '1/10/2026'.tr,
                                        readOnly: true,
                                        onTap: () async {
                                          await customDatePicker(
                                            context,
                                            initialDateTime: endAt,
                                          ).then((
                                            picked,
                                          ) {
                                            if (picked != null) {
                                              endAt = picked;
                                              endDateController.text =
                                                  "${picked.toLocal()}".split(
                                                    " ",
                                                  )[0];
                                            }
                                          });
                                        },
                                        height: 42,
                                        textInputType: TextInputType.datetime,
                                        controller: endDateController,
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                        suffixIcon: Icon(
                                          CupertinoIcons.calendar,
                                          color: context.appTheme.secondaryText,
                                        ),
                                        borderRadius: 5,
                                      ),
                                    ),
                                  ],
                                ),

                                // 🔹 رابط الملفات + إدراج مرفق
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: (Get.width * 0.7 / 2) - 25,
                                      child: InputText(
                                        labelText: 'task_details.files_link'.tr,
                                        hintText: 'task_details.files_link_hint'.tr,
                                        height: 42,
                                        controller: attachmentController,
                                        borderRadius: 5,
                                      ),
                                    ),
                                    SizedBox(
                                      width: (Get.width * 0.7 / 2) - 25,
                                      child: InkWell(
                                        onTap: () async {
                                          final files = await controller
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
                                                          .isUploading.value,
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
                                  ],
                                ),
                                Obx(
                                  () => SizedBox(
                                    width: Get.width * 0.7 - 32,
                                    child: FormAttachmentThumbnailsGrid(
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

                                // 🔹 بيانات الجمهور
                                Container(
                                  width: Get.width,
                                  alignment: Alignment.center,
                                  margin: EdgeInsets.symmetric(vertical: 7),
                                  padding: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: context.appTheme.unselected,
                                  ),
                                  child: Text(
                                    'promotion.audience_section'.tr,
                                    style: TextStyle(
                                      color: context.appTheme.secondaryText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                // 🔹 البلد - الاهتمامات - المدن
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // البلد
                                    SizedBox(
                                      width: (Get.width * 0.7 / 3) - 25,
                                      child: DynamicMultiSelect(
                                        selectedValues: countriesList,
                                        items:
                                            StorageKeys.countryCitiesMap.keys
                                                .toList(),

                                        label: 'task_details.country'.tr,
                                        borderRadius: 5,
                                        height: 42,
                                        onChanged: (value) {
                                          countriesList = value;
                                          final allowedCities =
                                              StorageKeys.getCitiesForCountries(
                                                value,
                                              );
                                          cityList =
                                              cityList
                                                  .where(
                                                    (c) => allowedCities
                                                        .contains(c),
                                                  )
                                                  .toList();
                                          setstate(() {});
                                        },
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                      ),
                                    ),

                                    // الاهتمامات
                                    SizedBox(
                                      width: (Get.width * 0.7 / 3) - 25,
                                      child: DynamicMultiSelect(
                                        selectedValues: interestsList,
                                        items: StorageKeys.interestsList,

                                        // value:
                                        //     interestsController.text.isEmpty
                                        //         ? null
                                        //         : interestsController.text,
                                        label: 'task_details.interests'.tr,
                                        borderRadius: 5,
                                        height: 42,
                                        onChanged: (value) {
                                          interestsList = value;
                                        },
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                      ),
                                    ),

                                    // المدن (فقط مدن البلد/البلدان المختارة)
                                    SizedBox(
                                      width: (Get.width * 0.7 / 3) - 25,
                                      child: DynamicMultiSelect(
                                        selectedValues: cityList,
                                        items:
                                            StorageKeys.getCitiesForCountries(
                                              countriesList,
                                            ),
                                        label: 'task_details.cities'.tr,
                                        borderRadius: 5,
                                        height: 42,
                                        onChanged: (value) {
                                          cityList = value;
                                        },
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                      ),
                                    ),
                                  ],
                                ),

                                // 🔹 العلامات ومجال التخصص
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: (Get.width * 0.7 / 2) - 25,
                                      child: InputText(
                                        labelText: 'promotion.age_label'.tr,
                                        hintText: 'promotion.age_range_hint'.tr,
                                        height: 42,
                                        controller: tagsController,
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                        borderRadius: 5,
                                      ),
                                    ),
                                    SizedBox(
                                      width: (Get.width * 0.7 / 2) - 25,
                                      child: DynamicMultiSelect(
                                        selectedValues: specializationList,
                                        items: StorageKeys.specialist,

                                        label: 'promotion.specialization_label'.tr,
                                        borderRadius: 5,
                                        height: 42,
                                        onChanged: (value) {
                                          specializationList = value;
                                        },
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                      ),
                                    ),
                                  ],
                                ),

                                // 🔹 الملاحظات
                                if (model != null)
                                  SizedBox(
                                    width: (Get.width * 0.7 / 1) - 25,
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
                                                    CrossAxisAlignment.start,
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
                                    ),
                                  ),
                                SizedBox(
                                  width: (Get.width * 0.7 / 1) - 25,
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
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TaskVoiceRecordField(
                              records: voiceRecords,
                              onRecordsChanged: (v) =>
                                  setstate(() => voiceRecords = v),
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
                                            : clientcontroller.text.trim();
                                        if (model == null) {
                                            controller.addTask(
                                              TaskModel(
                                                title: titleController.text,
                                                description:
                                                    notesController.text,
                                                status: StorageKeys
                                                    .status_promotion_in_progress,
                                                notes: [
                                                  if (notesController
                                                      .text
                                                      .isNotEmpty)
                                                    NoteModel(
                                                      note:
                                                          notesController.text,
                                                      byWho:
                                                          controller
                                                              .currentEmployee
                                                              .value
                                                              ?.name ??
                                                          '',
                                                      timestamp: DateTime.now(),
                                                    ),
                                                ],
                                                priority:
                                                    priorityController.text,
                                                fromDate: effectiveStartAt,
                                                toDate: effectiveEndAt,
                                                assignedTo:
                                                    executorController.text,
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
                                                    controller
                                                        .uploadedFilesPaths,
                                                type: '0',
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

                                                promotionModel: PromotionModel(
                                                  cities: cityList,
                                                  ageRanges:
                                                      tagsController.text,
                                                  specializations:
                                                      specializationList,
                                                  interests: interestsList,
                                                  countries: countriesList,
                                                  duration:
                                                      durationController.text,
                                                  campaignBudget:
                                                      campaignBudgetController
                                                          .text
                                                          .trim()
                                                          .isEmpty
                                                      ? null
                                                      : campaignBudgetController
                                                          .text
                                                          .trim(),
                                                  tags: marksController.text,
                                                  name: titleController.text,
                                                  target:
                                                      campaignReasonController
                                                          .text,
                                                  campaignName:
                                                      titleController.text,
                                                  type: '0',
                                                  priority:
                                                      priorityController.text,
                                                  status: StorageKeys
                                                      .status_promotion_in_progress,
                                                  platforms: platforms,
                                                  attachementurl:
                                                      attachmentController
                                                          .text,
                                                ),
                                              ),
                                            );
                                            Get.back();
                                            controller.uploadedFilesPaths
                                                .clear();
                                          } else {
                                            final nextTaskStatus =
                                                ((controller
                                                            .currentEmployee
                                                            .value
                                                            ?.role ==
                                                        'admin') ||
                                                    (controller
                                                            .currentEmployee
                                                            .value
                                                            ?.role ==
                                                        'supervisor'))
                                                    ? model.status
                                                    : StorageKeys
                                                        .status_edit_requested;
                                            controller.updateTask(
                                              TaskModel(
                                                id: model.id,
                                                title: titleController.text,
                                                description:
                                                    notesController.text,
                                                notes: model.notes,
                                                status: nextTaskStatus,
                                                priority:
                                                    priorityController.text,
                                                fromDate: effectiveStartAt,
                                                toDate: effectiveEndAt,
                                                assignedTo:
                                                    executorController.text,
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
                                                    controller
                                                        .uploadedFilesPaths,
                                                type: '0',
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

                                                promotionModel: PromotionModel(
                                                  cities: cityList,
                                                  ageRanges:
                                                      tagsController.text,
                                                  specializations:
                                                      specializationList,
                                                  interests: interestsList,
                                                  countries: countriesList,
                                                  duration:
                                                      durationController.text,
                                                  campaignBudget:
                                                      campaignBudgetController
                                                          .text
                                                          .trim()
                                                          .isEmpty
                                                      ? null
                                                      : campaignBudgetController
                                                          .text
                                                          .trim(),
                                                  tags: marksController.text,
                                                  name: titleController.text,
                                                  target:
                                                      campaignReasonController
                                                          .text,
                                                  campaignName:
                                                      titleController.text,
                                                  type: '0',
                                                  priority:
                                                      priorityController.text,
                                                  status: nextTaskStatus,
                                                  platforms: platforms,
                                                  attachementurl:
                                                      attachmentController
                                                          .text,
                                                ),
                                              ),
                                            );
                                            Get.back();
                                            controller.uploadedFilesPaths
                                                .clear();
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
