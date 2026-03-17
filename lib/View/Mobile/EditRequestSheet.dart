import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Shared/InputText.dart';

class EditRequestSheet extends StatelessWidget {
  final ContentModel model;
  EditRequestSheet({super.key, required this.model});
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ClientController>(
      builder: (controller) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Center(
                    child: Text(
                      'طلب تعديل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: (Get.width) - 25,
                    child: InputText(
                      labelText: ' التعديل '.tr,
                      hintText: 'اكتب التفاصيل'.tr,
                      height: 130,
                      fillColor: Colors.grey.shade100,
                      controller: controller.notesController,
                      expanded: true,
                      borderRadius: 12,
                      borderColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final controller = Get.find<HomeController>();
                      final files = await controller.pickMultiFiles();
                      for (var file in files) {
                        controller.uploadFiles(
                          filePathOrBytes: file.bytes!,
                          fileName: file.name,
                        );
                      }
                    },
                    child: SvgPicture.asset(
                      'assets/svgs/Component 139.svg',
                      width: Get.width,
                    ),
                  ),
                  GetBuilder<HomeController>(
                    builder: (controller) {
                      return SizedBox(
                        width: (Get.width * 0.9) - 30,
                        child: Obx(
                          () => Column(
                            children: [
                              for (var filePath
                                  in controller.uploadedFilesPaths)
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        controller.uploadedFilesPaths.remove(
                                          filePath,
                                        );
                                      },
                                      child: Icon(
                                        Icons.cancel,
                                        color: Colors.red,
                                      ),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      FunHelper.getFileNameFromUrl(filePath),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Obx(
                    () => Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await controller
                                  .updateContent(
                                    model.copyWith(
                                      status: StorageKeys.status_edit_requested,
                                      // ignore: invalid_use_of_protected_member
                                      clientEdits:
                                          Get.find<HomeController>()
                                              .uploadedFilesPaths,
                                      clientNotes:
                                          controller.notesController.text,
                                    ),
                                  )
                                  .then((v) {
                                    Get.back();
                                    controller.notesController.clear();

                                    FunHelper.showsnackbar(
                                      'success'.tr,
                                      'تم ارسال طلب التعديل '.tr,
                                      snackPosition: SnackPosition.TOP,
                                      backgroundColor: Colors.green,
                                      colorText: Colors.white,
                                    );
                                  });
                              final clientName = Get.find<HomeController>().clients.firstWhereOrNull((c) => c.id == model.clientId)?.name ?? model.clientId;
                              await NotificationService.notifyPublishDeptClientEditRequest(contentTitle: model.title);
                              await NotificationService.notifyManagersClientNotesOnContent(clientName: clientName, contentTitle: model.title);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child:
                                Get.find<HomeController>().isLoading.value
                                    ? Center(child: CircularProgressIndicator())
                                    : const Text(
                                      'تأكيد',
                                      style: TextStyle(color: Colors.white),
                                    ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.teal),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(color: Colors.teal),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 50),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
