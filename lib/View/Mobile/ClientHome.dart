import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Mobile/ClientContentDetails.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/Shared/CustomHeader.dart';

class TabsController extends GetxController {
  RxInt selectedIndex =
      0.obs; // القيمة الافتراضية "الموافقة" (تقدر تخليها 0 لو عايزها "الكل")
}

class ClientHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tabsController = Get.put(TabsController());

    return GetBuilder<ClientController>(
      builder: (controller) {
        return Obx(
          () => Scaffold(
            backgroundColor: Colors.white,
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 35),
                  PreferredSize(
                    preferredSize: Size(Get.width, 60),
                    child: Obx(
                      () => HeaderWidget(
                        client: true,
                        employee: true,
                        name: controller.currentClient.value?.name ?? '',
                        role: '',
                        avatarUrl:
                            controller.currentClient.value?.image ??
                            kDefaultAvatarUrl,
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  Obx(() {
                    final tabs = [
                      'client.status_tab.all'.tr,
                      'client.status_tab.approved'.tr,
                      'client.status_tab.revision'.tr,
                      'client.status_tab.rejected'.tr,
                    ];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(tabs.length, (index) {
                          final isSelected =
                              tabsController.selectedIndex.value == index;

                          return GestureDetector(
                            onTap:
                                () =>
                                    tabsController.selectedIndex.value = index,

                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(0xFF62529A)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tabs[index],
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                  tabsController.selectedIndex.value == 0
                      ? Obx(() {
                        return controller.contents.isEmpty
                            ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('content.empty_display'.tr),
                            )
                            : ListView.builder(
                              physics: NeverScrollableScrollPhysics(),

                              shrinkWrap: true,
                              itemCount: controller.contents.length,
                              itemBuilder: (context, index) {
                                return ContentStatusCard(
                                  index: index,
                                  model: controller.contents[index],
                                  onTap: () async {
                                    // try {
                                    // } catch (e) {
                                    //   log(e.toString());
                                    // }
                                    Get.to(
                                      () => Clientcontentdetails(
                                        model: controller.contents[index],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                      })
                      : tabsController.selectedIndex.value == 1
                      ? Obx(() {
                        return controller.contents
                                .where(
                                  (a) =>
                                      a.status == StorageKeys.status_approved,
                                )
                                .isEmpty
                            ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('content.empty_display'.tr),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount:
                                  controller.contents
                                      .where(
                                        (a) =>
                                            a.status ==
                                            StorageKeys.status_approved,
                                      )
                                      .length,
                              itemBuilder: (context, index) {
                                return ContentStatusCard(
                                  index: index,
                                  model:
                                      controller.contents
                                          .where(
                                            (a) =>
                                                a.status ==
                                                StorageKeys.status_approved,
                                          )
                                          .toList()[index],
                                  onTap: () {
                                    Get.to(
                                      () => Clientcontentdetails(
                                        model:
                                            controller.contents
                                                .where(
                                                  (a) =>
                                                      a.status ==
                                                      StorageKeys
                                                          .status_approved,
                                                )
                                                .toList()[index],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                      })
                      : tabsController.selectedIndex.value == 2
                      ? Obx(() {
                        return controller.contents
                                .where(
                                  (a) =>
                                      a.status ==
                                      StorageKeys.status_edit_requested,
                                )
                                .isEmpty
                            ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('content.empty_display'.tr),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),

                              itemCount:
                                  controller.contents
                                      .where(
                                        (a) =>
                                            a.status ==
                                            StorageKeys.status_edit_requested,
                                      )
                                      .length,
                              itemBuilder: (context, index) {
                                return ContentStatusCard(
                                  index: index,
                                  model:
                                      controller.contents
                                          .where(
                                            (a) =>
                                                a.status ==
                                                StorageKeys
                                                    .status_edit_requested,
                                          )
                                          .toList()[index],
                                  onTap: () {
                                    Get.to(
                                      () => Clientcontentdetails(
                                        model:
                                            controller.contents
                                                .where(
                                                  (a) =>
                                                      a.status ==
                                                      StorageKeys
                                                          .status_edit_requested,
                                                )
                                                .toList()[index],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                      })
                      : Obx(() {
                        return controller.contents
                                .where(
                                  (a) =>
                                      a.status == StorageKeys.status_rejected,
                                )
                                .isEmpty
                            ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('content.empty_display'.tr),
                            )
                            : ListView.builder(
                              physics: NeverScrollableScrollPhysics(),

                              shrinkWrap: true,
                              itemCount:
                                  controller.contents
                                      .where(
                                        (a) =>
                                            a.status ==
                                            StorageKeys.status_rejected,
                                      )
                                      .length,
                              itemBuilder: (context, index) {
                                return ContentStatusCard(
                                  index: index,
                                  model:
                                      controller.contents
                                          .where(
                                            (a) =>
                                                a.status ==
                                                StorageKeys.status_rejected,
                                          )
                                          .toList()[index],
                                  onTap: () {
                                    Get.to(
                                      () => Clientcontentdetails(
                                        model:
                                            controller.contents
                                                .where(
                                                  (a) =>
                                                      a.status ==
                                                      StorageKeys
                                                          .status_rejected,
                                                )
                                                .toList()[index],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                      }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
