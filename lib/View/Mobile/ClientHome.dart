import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Mobile/ClientContentDetails.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart';
import 'package:point/Utils/AppConstants.dart';

class TabsController extends GetxController {
  RxInt selectedIndex =
      0.obs; // القيمة الافتراضية "الموافقة" (تقدر تخليها 0 لو عايزها "الكل")
}

class ClientHome extends StatelessWidget {
  final LanguageController _languageController = Get.find<LanguageController>();

  @override
  Widget build(BuildContext context) {
    final tabsController = Get.put(TabsController());

    return GetBuilder<ClientController>(
      builder: (controller) {
        return Obx(
          () => Scaffold(
            backgroundColor: Colors.white,
            appBar: _buildClientAppBar(controller),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (MediaQuery.of(context).size.width >= 800)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Spacer(),
                          _buildLanguageMenuButton(),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

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
                        children: List.generate(tabs.length, (index) {
                          final isSelected =
                              tabsController.selectedIndex.value == index;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  tabsController.selectedIndex.value = index,
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 6,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? const Color(0xFF62529A)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tabs[index],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
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

  PreferredSizeWidget _buildClientAppBar(ClientController controller) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 10,
      title: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: AppLocaleKeys.appLanguage.tr,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.language, color: AppColors.primary),
            onSelected: (value) => _languageController.changeLanguage(value),
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'ar',
                    child: Text(AppLocaleKeys.appLanguageArabic.tr),
                  ),
                  PopupMenuItem(
                    value: 'en',
                    child: Text(AppLocaleKeys.appLanguageEnglish.tr),
                  ),
                ],
          ),
          Expanded(
            child: Obx(() {
              final client = controller.currentClient.value;
              final displayName = (client?.name ?? '').trim();
              final avatarUrl = client?.image ?? kDefaultAvatarUrl;
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (displayName.isNotEmpty)
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  if (displayName.isNotEmpty) const SizedBox(width: 8),
                  PopupMenuButton<int>(
                    tooltip: 'tasks.options_tooltip'.tr,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.white,
                    elevation: 4,
                    onSelected: (value) async {
                      if (value == 0) {
                        final shouldLogout =
                            await _confirmClientLogoutDialog(Get.context!);
                        if (!shouldLogout) return;
                        controller.currentClient.value = null;
                        await FirestoreServices().signOut();
                        FunHelper.removeLoginData();
                        Get.offAllNamed('/auth/LoginUserAccount');
                      } else if (value == 1) {
                        Get.toNamed('/auth/resetPassword');
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 1,
                            child: Row(
                              children: [
                                Text(
                                  'resetpassword'.tr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.lock_reset,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 0,
                            child: Row(
                              children: [
                                Text(
                                  'logout'.tr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.logout, color: Colors.red),
                              ],
                            ),
                          ),
                        ],
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(avatarUrl),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageMenuButton() {
    return PopupMenuButton<String>(
      tooltip: AppLocaleKeys.appLanguage.tr,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            AppLocaleKeys.appLanguage.tr,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: AppColors.primary),
        ],
      ),
      onSelected: (value) => _languageController.changeLanguage(value),
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: 'ar',
              child: Text(AppLocaleKeys.appLanguageArabic.tr),
            ),
            PopupMenuItem(
              value: 'en',
              child: Text(AppLocaleKeys.appLanguageEnglish.tr),
            ),
          ],
    );
  }
}

Future<bool> _confirmClientLogoutDialog(BuildContext context) async {
  final isArabic = Get.locale?.languageCode == 'ar';
  final result = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text('logout'.tr),
          content: Text(
            isArabic
                ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
                : 'Are you sure you want to log out?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('cancel'.tr),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'logout'.tr,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
  );
  return result ?? false;
}
