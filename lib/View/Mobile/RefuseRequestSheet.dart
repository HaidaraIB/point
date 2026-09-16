import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/ThemeController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/notification_navigation/notification_destination.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/app_theme.dart';

import 'package:point/View/Shared/InputText.dart';

class RefuseRequestSheet extends StatelessWidget {
  final ContentModel model;
  final bool asDialog;

  const RefuseRequestSheet({
    super.key,
    required this.model,
    this.asDialog = false,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ClientController>(
      builder: (controller) {
        final themeController = Get.find<ThemeController>();
        final appTheme = themeController.extension;
        final themeData =
            themeController.effectiveBrightness == Brightness.dark
                ? AppTheme.dark()
                : AppTheme.light();
        return Theme(
          data: themeData,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appTheme.cardSurface,
                borderRadius:
                    asDialog
                        ? BorderRadius.circular(16)
                        : const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Center(
                      child: Text(
                        'requests.sheet_refuse_heading'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: appTheme.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: (Get.width) - 25,
                      child: InputText(
                        labelText: 'requests.reject_title'.tr,
                        hintText: 'requests.details_hint'.tr,
                        height: 130,
                        controller: controller.notesController,
                        expanded: true,
                        borderRadius: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Obx(
                      () => Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  controller.isLoading.value
                                      ? null
                                      : () async {
                                        final ok = await controller
                                            .updateContent(
                                              model.copyWith(
                                                status:
                                                    StorageKeys.status_rejected,
                                                clientNotes:
                                                    controller
                                                        .notesController
                                                        .text,
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
                                        Get.back();
                                        controller.notesController.clear();
                                        FunHelper.showSnackbar(
                                          'success'.tr,
                                          'requests.reject_sent'.tr,
                                          snackPosition: SnackPosition.TOP,
                                          backgroundColor: Colors.green,
                                          colorText: Colors.white,
                                        );
                                        final clientName =
                                            Get.find<HomeController>()
                                                .clients
                                                .firstWhereOrNull(
                                                  (c) => c.id == model.clientId,
                                                )
                                                ?.name ??
                                            model.clientId;
                                        await NotificationService.notifyPublishDeptClientRejected(
                                          contentTitle: model.title,
                                          clientName: clientName,
                                          fcmDataExtras:
                                              notificationContentExtras(
                                                model.id,
                                              ),
                                        );
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
                                side: BorderSide(color: appTheme.accentBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                'common.cancel'.tr,
                                style: TextStyle(color: appTheme.accentText),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
