import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

void addContentEmployeeDialog(
  BuildContext context, {
  required TaskModel? model,
}) {
  final filecontroller = TextEditingController();
  final notesController = TextEditingController(text: model?.description ?? '');
  var _key = GlobalKey<FormState>();
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GetBuilder<HomeController>(
          builder: (controller) {
            return Form(
              key: _key,
              child: SizedBox(
                width:
                    Responsive.isDesktop(context)
                        ? (Get.width / 2) - 100
                        : Get.width - 20,
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
                            SvgPicture.asset(
                              'assets/svgs/icon_check_circle.svg',
                            ),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'addcontent'.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'addcontenthint'.tr,
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
                            Obx(
                              () => Column(
                                children: [
                                  SizedBox(
                                    width:
                                        Responsive.isDesktop(context)
                                            ? (Get.width / 2) - 100
                                            : Get.width - 20,

                                    child: GestureDetector(
                                      onTap: () async {
                                        final files =
                                            await controller.pickMultiFiles();
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
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                margin: EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                ),
                                                child: Text(
                                                  'dragfile'.tr,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
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
                                                backgroundColor: Colors.white,
                                                fontColor:
                                                    AppColors.primaryfontColor,
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
                                    width:
                                        Responsive.isDesktop(context)
                                            ? (Get.width / 2) - 100
                                            : Get.width - 20,
                                    child: InputText(
                                      labelText: 'content.form.insert_link'.tr,
                                      hintText: 'googledrivelink .com'.tr,
                                      height: 40,
                                      fillColor: Colors.white,

                                      controller: filecontroller,
                                      suffixIcon: Container(
                                        width: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          color: Colors.grey.shade200,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Copy',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 5),
                                            Icon(
                                              Icons.copy_rounded,
                                              weight: 1,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                    ),
                                  ),
                                  SizedBox(
                                    width:
                                        Responsive.isDesktop(context)
                                            ? (Get.width / 2) - 100
                                            : Get.width - 20,
                                    child: Obx(
                                      () => Column(
                                        children: [
                                          for (var filePath
                                              in controller.uploadedFilesPaths)
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

                            SizedBox(
                              width:
                                  Responsive.isDesktop(context)
                                      ? (Get.width / 2) - 50
                                      : Get.width - 50,
                              child: InputText(
                                labelText: 'notes'.tr,
                                hintText: 'enternotes'.tr,
                                height: 100,
                                fillColor: Colors.white,
                                controller: notesController,
                                expanded: true,

                                borderRadius: 5,
                                borderColor: Colors.grey.shade300,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Obx(
                              () => SizedBox(
                                width:
                                    Responsive.isDesktop(context)
                                        ? Get.width * 0.4 - 260
                                        : Get.width * 0.4,
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
                                  onPressed: () async {
                                    if (_key.currentState!.validate()) {
                                      await controller
                                          .updateTask(
                                            model!.copyWith(
                                              description: notesController.text,
                                              files: [
                                                ...model
                                                    .files, // الملفات القديمة (لو موجودة)
                                                ...controller
                                                    .uploadedFilesPaths,
                                                ...filecontroller.text.isEmpty
                                                    ? []
                                                    : [
                                                      filecontroller.text
                                                          .trim(),
                                                    ], // الملفات الجديدة
                                              ],
                                            ),
                                          )
                                          .then((v) {
                                            if (v) {
                                              Get.back();
                                              FunHelper.showSnackbar(
                                                'success'.tr,
                                                'content.add_success'.tr,
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                                backgroundColor: Colors.green,
                                                colorText: Colors.white,
                                              );
                                            }
                                          });
                                      controller.uploadedFilesPaths.clear();
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
                                            'common.save'.tr,
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
                                child: Text('common.cancel'.tr),
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
