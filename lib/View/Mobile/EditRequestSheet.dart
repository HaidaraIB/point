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
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/Utils/app_theme.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';

class EditRequestSheet extends StatelessWidget {
  final ContentModel model;
  final bool asDialog;

  const EditRequestSheet({
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
              constraints: BoxConstraints(maxHeight: Get.height * 0.9),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!asDialog) ...[
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: appTheme.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 8),
                    Text(
                      'requests.sheet_edit_heading'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: appTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    InputText(
                      labelText: 'requests.edit_title'.tr,
                      hintText: 'requests.details_hint'.tr,
                      height: 120,
                      controller: controller.notesController,
                      expanded: true,
                      borderRadius: 12,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'client.edit_attach_hint'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: appTheme.mutedText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final home = Get.find<HomeController>();
                          final files = await home.pickMultiFiles();
                          for (final file in files) {
                            home.uploadFiles(
                              filePathOrBytes: file.bytes,
                              fileName: file.name,
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: appTheme.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: appTheme.accentBorder,
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 32,
                                color: appTheme.accentText,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'requests.attach_files'.tr,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: appTheme.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GetBuilder<HomeController>(
                      builder: (home) {
                        return Obx(
                          () =>
                              home.uploadedFilesPaths.isEmpty
                                  ? const SizedBox.shrink()
                                  : Padding(
                                    padding: const EdgeInsets.only(top: 12),
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
                                                        onOpen:
                                                            () =>
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
                                                      onTap:
                                                          () => home
                                                              .uploadedFilesPaths
                                                              .remove(filePath),
                                                      child: Container(
                                                        width: 22,
                                                        height: 22,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              appTheme
                                                                  .secondaryText,
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  controller.isLoading.value
                                      ? null
                                      : () async {
                                        final home = Get.find<HomeController>();
                                        final edits = List<dynamic>.from(
                                          home.uploadedFilesPaths,
                                        );
                                        final ok = await controller.updateContent(
                                          model.copyWith(
                                            status:
                                                StorageKeys
                                                    .status_edit_requested,
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
                                        await NotificationService
                                            .notifyPublishDeptClientEditRequest(
                                          contentTitle: model.title,
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
                                      ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Text(
                                        'confirm'.tr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

Future<void> _openEditAttachment(String rawUrl) async {
  await openUrlPreferInAppMedia(rawUrl);
}
