import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/notification_navigation/notification_destination.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Mobile/EditRequestSheet.dart';
import 'package:point/View/Mobile/RefuseRequestSheet.dart';
import 'package:point/View/Mobile/Shared/TopAppBar.dart';
import 'package:point/View/Mobile/Shared/VideoCart.dart';
import 'package:point/View/Shared/app_version_label.dart';
import 'package:point/View/Shared/button.dart';

class Clientcontentdetails extends StatelessWidget {
  final ContentModel? model;
  Clientcontentdetails({required this.model});
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ClientController>(
      builder: (controller) {
        return Obx(() {
          final id = model?.id;
          final live =
              id != null
                  ? controller.contents.firstWhereOrNull((c) => c.id == id)
                  : null;
          final m = live ?? model!;

          return Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 50),
                  TopAppBar(context, 'content.details_title'.tr),
                  SizedBox(height: 25),

                  VideoCard(model: m),
                  SizedBox(height: 100),
                  if (m.status == StorageKeys.status_under_revision)
                    Obx(
                      () => MainButton(
                        icon: false,
                        height: 50,
                        backgroundColor: Colors.green,
                        borderSize: 10,
                        load: controller.isLoading.value,

                        fontColor: Colors.white,
                        title: 'tasks.accept'.tr,
                        onPressed: () async {
                          final ok = await controller.updateContent(
                            m.copyWith(
                              status: StorageKeys.status_ready_to_publish,
                            ),
                          );
                          if (ok) {
                            await NotificationService.notifyClientApprovalConfirmed(
                              clientId: m.clientId,
                              fcmDataExtras: notificationContentExtras(m.id),
                            );
                            final clientName = controller.currentClient.value?.name ?? m.clientId;
                            await NotificationService.notifyManagersClientApprovedContent(
                              clientName: clientName,
                              contentTitle: m.title,
                              fcmDataExtras: notificationContentExtras(m.id),
                            );
                            await NotificationService.notifyPublishDeptClientApproved(
                              clientName: clientName,
                              contentTitle: m.title,
                              fcmDataExtras: notificationContentExtras(m.id),
                            );
                            FunHelper.showSnackbar(
                              'success'.tr,
                              'client.accept_success'.tr,
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                            );
                          } else {
                            FunHelper.showSnackbar(
                              'feedback.error_title'.tr,
                              'errors.network_failed'.tr,
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          }
                        },
                      ),
                    ),
                  SizedBox(height: 15),
                  MainButton(
                    icon: false,
                    height: 50,
                    backgroundColor: Color(0xffE6B802),
                    fontColor: Colors.white,
                    borderSize: 10,
                    title: 'edit'.tr,
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => EditRequestSheet(model: m),
                      );
                    },
                  ),
                  SizedBox(height: 15),
                  if (m.status == StorageKeys.status_under_revision)
                    MainButton(
                      icon: false,
                      height: 50,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => RefuseRequestSheet(model: m),
                        );
                      },

                      backgroundColor: Colors.red,
                      fontColor: Colors.white,
                      borderSize: 10,
                      title: 'tasks.reject'.tr,
                    ),
                  AppVersionLabel(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                    textStyle: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
