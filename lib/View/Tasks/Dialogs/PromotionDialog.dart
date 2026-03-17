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
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/MultiSelectDropDown.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/t.dart';
import 'package:point/View/Tasks/Mobile/GenericTaskFormMobilePage.dart';

void showPromotionDialog(BuildContext context, {TaskModel? model}) {
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
  RxList platforms = (model?.promotionModel?.platforms ?? []).obs;

  final clientcontroller = TextEditingController(text: model?.clientName);
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
  final notesController = TextEditingController();

  Get.find<HomeController>().uploadedFilesPaths.assignAll(
      List.from(model?.files ?? []));

  DateTime? startAt = model?.fromDate;
  DateTime? endAt = model?.toDate;

  var _key = GlobalKey<FormState>();

  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
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
                              color: Color(0xFF5C5589),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SvgPicture.asset('assets/svgs/Check_circle.svg'),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'اضافة مهمة'.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'من فضلك قم بادخال بيانات المهمه'.tr,
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
                                    fillColor: Colors.white,
                                    controller: titleController,
                                    validator:
                                        (v) =>
                                            v == null || v.isEmpty ? ' ' : null,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
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
                                            clientcontroller.text.isEmpty
                                                ? null
                                                : controller.clients.firstWhere(
                                                  (a) =>
                                                      a.id ==
                                                      clientcontroller.text,
                                                ),
                                        label: 'chooseclient'.tr,
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                        height: 42,
                                        fillColor: Colors.white,
                                        onChanged: (value) {
                                          if (value != null) {
                                            clientcontroller.text =
                                                value.id ?? '';
                                          }
                                        },
                                        validator:
                                            (v) => v == null ? ' ' : null,
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
                                        borderColor: Colors.grey.shade300,
                                        height: 42,
                                        fillColor: Colors.white,
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
                                                  (a) => a.department == 'cat1',
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
                                        label: 'المنفذ'.tr,
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
                                        borderColor: Colors.grey.shade300,
                                        height: 42,
                                        fillColor: Colors.white,
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
                                        fillColor: Colors.white,
                                        controller: marksController,
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                      ),
                                    ),
                                  ],
                                ),

                                // 🔹 التواريخ والمنصة
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: (Get.width * 0.7 / 3) - 25,
                                      child: InputText(
                                        labelText: 'المدة'.tr,
                                        hintText: 'مدة الحملة'.tr,

                                        height: 42,
                                        fillColor: Colors.white,
                                        controller: durationController,

                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                      ),
                                    ),
                                    // تاريخ البدء
                                    SizedBox(
                                      width: (Get.width * 0.7 / 3) - 25,
                                      child: InputText(
                                        ontap: () async {
                                          await customDatePicker(context).then((
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
                                        fillColor: Colors.white,
                                        textInputType: TextInputType.datetime,
                                        controller: startDateController,
                                        readonly: true,
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                        suffixIcon: Icon(
                                          CupertinoIcons.calendar,
                                          color: Colors.grey,
                                        ),
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                      ),
                                    ),

                                    // تاريخ الانتهاء
                                    SizedBox(
                                      width: (Get.width * 0.7 / 3) - 25,
                                      child: InputText(
                                        labelText: 'endat'.tr,
                                        hintText: '1/10/2026'.tr,
                                        readonly: true,
                                        ontap: () async {
                                          await customDatePicker(context).then((
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
                                        fillColor: Colors.white,
                                        textInputType: TextInputType.datetime,
                                        controller: endDateController,
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                        suffixIcon: Icon(
                                          CupertinoIcons.calendar,
                                          color: Colors.grey,
                                        ),
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                      ),
                                    ),

                                    // المنصة (مرة تانية)
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
                                        labelText: 'رابط الملفات'.tr,
                                        hintText: 'اكتب رابط الملفات'.tr,
                                        height: 42,
                                        fillColor: Colors.white,
                                        controller: attachmentController,
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
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
                                          fillColor: Colors.white,
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
                                                          .isUploading.value,
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
                                  ],
                                ),
                                Obx(
                                  () => controller.uploadedFilesPaths.isEmpty
                                      ? SizedBox.shrink()
                                      : SizedBox(
                                          width: Get.width * 0.7 - 32,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                                    Expanded(
                                                      child: Text(
                                                        FunHelper
                                                            .getFileNameFromUrl(
                                                          filePath,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.blue,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
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
                                    color: Colors.grey.shade200,
                                  ),
                                  child: Text(
                                    'بيانات الجمهور',
                                    style: TextStyle(
                                      color: AppColors.fontColorGrey,
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

                                        label: 'البلد'.tr,
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                        height: 42,
                                        fillColor: Colors.white,
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
                                        label: 'الاهتمامات'.tr,
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                        height: 42,
                                        fillColor: Colors.white,
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
                                        label: 'المدن'.tr,
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                        height: 42,
                                        fillColor: Colors.white,
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
                                        labelText: 'الاعمار'.tr,
                                        hintText: 'من-الى'.tr,
                                        height: 42,
                                        fillColor: Colors.white,
                                        controller: tagsController,
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? ' '
                                                    : null,
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                      ),
                                    ),
                                    SizedBox(
                                      width: (Get.width * 0.7 / 2) - 25,
                                      child: DynamicMultiSelect(
                                        selectedValues: specializationList,
                                        items: StorageKeys.specialist,

                                        label: 'مجال الاختصاصات',
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                        height: 42,
                                        fillColor: Colors.white,
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
                                      borderColor: Colors.grey.shade300,
                                    ),
                                  ),
                                SizedBox(
                                  width: (Get.width * 0.7 / 1) - 25,
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
                          ),

                          // الأزرار (نفسها)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Obx(
                                  () => SizedBox(
                                    width: Get.width * 0.4 - 260,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF5C5589),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
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
                                                description:
                                                    notesController.text,
                                                status:
                                                    StorageKeys
                                                        .status_not_start_yet,
                                                notes: [
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
                                                priority:
                                                    priorityController.text,
                                                fromDate: startAt!,
                                                toDate: endAt!,
                                                assignedTo:
                                                    executorController.text,
                                                clientName:
                                                    clientcontroller.text,
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
                                                  tags: marksController.text,
                                                  name: 'name',
                                                  target:
                                                      campaignReasonController
                                                          .text,
                                                  campaignName: 'campaignName',
                                                  type: 'type',
                                                  priority: ' priority',
                                                  status: 'status',
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
                                            controller.updateTask(
                                              TaskModel(
                                                id: model.id,
                                                title: titleController.text,
                                                description:
                                                    notesController.text,
                                                notes:
                                                    model.notes +
                                                    [
                                                      if (notesController
                                                          .text
                                                          .isNotEmpty)
                                                        NoteModel(
                                                          note:
                                                              notesController
                                                                  .text,
                                                          byWho:
                                                              controller
                                                                  .currentemployee
                                                                  .value
                                                                  ?.name ??
                                                              '',
                                                          timestamp:
                                                              DateTime.now(),
                                                        ),
                                                    ],
                                                status:
                                                    StorageKeys
                                                        .status_edit_requested,
                                                priority:
                                                    priorityController.text,
                                                fromDate: startAt!,
                                                toDate: endAt!,
                                                assignedTo:
                                                    executorController.text,
                                                clientName:
                                                    clientcontroller.text,
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
                                                  tags: marksController.text,
                                                  name: 'name',
                                                  target:
                                                      campaignReasonController
                                                          .text,
                                                  campaignName: 'campaignName',
                                                  type: 'type',
                                                  priority: ' priority',
                                                  status: 'status',
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
                                        }
                                      },
                                      child:
                                          controller.isLoading.value
                                              ? Center(
                                                child:
                                                    CircularProgressIndicator(),
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
            );
          },
        ),
      );
    },
  );
}
