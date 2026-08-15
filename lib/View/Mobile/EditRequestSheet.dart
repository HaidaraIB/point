import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/notification_navigation/notification_destination.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:point/Utils/app_theme_extension.dart';

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
            decoration: BoxDecoration(
              color: context.appTheme.cardSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Center(
                    child: Text(
                      'requests.sheet_edit_heading'.tr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.appTheme.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: (Get.width) - 25,
                    child: InputText(
                      labelText: 'requests.edit_title'.tr,
                      hintText: 'requests.details_hint'.tr,
                      height: 130,
                      controller: controller.notesController,
                      expanded: true,
                      borderRadius: 12,
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
                      'assets/svgs/edit_request_attachment_zone.svg',
                      width: Get.width,
                    ),
                  ),
                  GetBuilder<HomeController>(
                    builder: (home) {
                      return Obx(
                        () =>
                            home.uploadedFilesPaths.isEmpty
                                ? const SizedBox.shrink()
                                : Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: home.uploadedFilesPaths.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          mainAxisExtent: 96,
                                        ),
                                    itemBuilder: (context, i) {
                                      final filePath =
                                          home.uploadedFilesPaths[i]
                                              .toString();
                                      return Center(
                                        child: SizedBox(
                                          width: 88,
                                          height: 88,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned.fill(
                                                child:
                                                    TaskDetailsDialogHelpers.attachmentThumbnail(
                                                      filePath,
                                                      onOpen: () =>
                                                          _openEditAttachment(
                                                            filePath,
                                                          ),
                                                    ),
                                              ),
                                              PositionedDirectional(
                                                top: 4,
                                                end: 4,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      home.uploadedFilesPaths
                                                          .remove(filePath);
                                                    },
                                                    child: Container(
                                                      width: 22,
                                                      height: 22,
                                                      decoration: BoxDecoration(
                                                        color: context.appTheme.secondaryText,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              11,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
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
                            onPressed: controller.isLoading.value
                                ? null
                                : () async {
                                    final home = Get.find<HomeController>();
                                    final edits =
                                        List<dynamic>.from(
                                          home.uploadedFilesPaths,
                                        );
                                    final ok = await controller.updateContent(
                                      model.copyWith(
                                        status:
                                            StorageKeys.status_edit_requested,
                                        clientEdits: edits,
                                        clientNotes:
                                            controller.notesController.text,
                                      ),
                                    );
                                    if (!ok) {
                                      FunHelper.showSnackbar(
                                        'feedback.error_title'.tr,
                                        'errors.network_failed'.tr,
                                        snackPosition: SnackPosition.TOP,
                                        backgroundColor: Colors.red,
                                        colorText: Colors.white,
                                      );
                                      return;
                                    }
                                    home.uploadedFilesPaths.clear();
                                    Get.back();
                                    controller.notesController.clear();
                                    FunHelper.showSnackbar(
                                      'success'.tr,
                                      'requests.edit_sent'.tr,
                                      snackPosition: SnackPosition.TOP,
                                      backgroundColor: Colors.green,
                                      colorText: Colors.white,
                                    );
                                    final clientName =
                                        home.clients
                                            .firstWhereOrNull(
                                              (c) => c.id == model.clientId,
                                            )
                                            ?.name ??
                                        model.clientId;
                                    await NotificationService.notifyPublishDeptClientEditRequest(
                                      contentTitle: model.title,
                                      fcmDataExtras: notificationContentExtras(model.id),
                                    );
                                    await NotificationService.notifyManagersClientNotesOnContent(
                                      clientName: clientName,
                                      contentTitle: model.title,
                                      fcmDataExtras: notificationContentExtras(model.id),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child:
                                controller.isLoading.value
                                    ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    )
                                    : Text(
                                      'confirm'.tr,
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
                            child: Text(
                              'common.cancel'.tr,
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

Future<void> _openEditAttachment(String rawUrl) async {
  await openUrlPreferInAppMedia(rawUrl);
}
