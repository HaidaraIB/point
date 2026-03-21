import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/state_manager.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Mobile/EditRequestSheet.dart';
import 'package:point/View/Mobile/RefuseRequestSheet.dart';
import 'package:point/View/Mobile/Shared/TopAppBar.dart';
import 'package:point/View/Mobile/Shared/VideoCart.dart';
import 'package:point/View/Shared/button.dart';

class Clientcontentdetails extends StatelessWidget {
  final ContentModel? model;
  Clientcontentdetails({required this.model});
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ClientController>(
      builder: (controller) {
        return Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 50),
                TopAppBar('content.details_title'.tr),
                SizedBox(height: 25),

                VideoCard(model: model!),
                SizedBox(height: 100),
                if (model!.status == StorageKeys.status_under_revision)
                  Obx(
                    () => MainButton(
                      icon: false,
                      height: 50,
                      backgroundcolor: Colors.green,
                      bordersize: 10,
                      load: controller.isLoading.value,

                      fontcolor: Colors.white,
                      title: 'tasks.accept'.tr,
                      onpress: () async {
                        final ok = await controller.updateContent(
                          model!.copyWith(
                            status: StorageKeys.status_ready_to_publish,
                          ),
                        );
                        if (ok) {
                          await NotificationService.notifyClientApprovalConfirmed(clientId: model!.clientId);
                          final clientName = controller.currentClient.value?.name ?? model!.clientId;
                          await NotificationService.notifyManagersClientApprovedContent(clientName: clientName, contentTitle: model!.title);
                          await NotificationService.notifyPublishDeptClientApproved(clientName: clientName, contentTitle: model!.title);
                        }
                        FunHelper.showsnackbar(
                          'success'.tr,
                          'client.accept_success'.tr,
                          snackPosition: SnackPosition.TOP,
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      },
                    ),
                  ),
                SizedBox(height: 15),
                MainButton(
                  icon: false,
                  height: 50,
                  backgroundcolor: Color(0xffE6B802),
                  fontcolor: Colors.white,
                  bordersize: 10,
                  title: 'edit'.tr,
                  // load: controller.isLoading.value,
                  onpress: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => EditRequestSheet(model: model!),
                    );
                  },
                ),
                SizedBox(height: 15),
                if (model!.status == StorageKeys.status_under_revision)
                  MainButton(
                    icon: false,
                    height: 50,
                    onpress: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => RefuseRequestSheet(model: model!),
                      );
                    },

                    // load: controller.isLoading.value,
                    backgroundcolor: Colors.red,
                    fontcolor: Colors.white,
                    bordersize: 10,
                    title: 'tasks.reject'.tr,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
