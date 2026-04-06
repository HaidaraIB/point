import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Mobile/ClientContentDetails.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/ClientDashboard/client_profile_form.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/app_version_label.dart';
import 'package:point/Utils/AppNotificationInbox.dart';

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
            body: RefreshIndicator(
              onRefresh: () async {
                controller.fetchContents();
                await Future.delayed(const Duration(seconds: 1));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
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
                  AppVersionLabel(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: Color(0xFF888888),
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

  PreferredSizeWidget _buildClientAppBar(ClientController controller) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 10,
      title: Row(
        children: [
          Expanded(
            child: Obx(() {
              final client = controller.currentClient.value;
              final displayName = (client?.name ?? '').trim();
              final avatarUrl = client?.image ?? kDefaultAvatarUrl;
              final unreadInbox = unreadInAppInboxCount(
                Get.find<HomeController>().notifications,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: PopupMenuButton<String>(
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
                  ),
                  const SizedBox(width: 4),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          tooltip: 'header.notifications'.tr,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            final ctx = Get.context;
                            if (ctx != null) {
                              showInAppNotificationsDialog(ctx);
                            }
                          },
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: HeaderCountBadge(count: unreadInbox),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (displayName.isNotEmpty)
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
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
                          Text(
                            'user_type_client'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              color: Color(0xFF6E6E6E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (displayName.isNotEmpty) const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: PopupMenuButton<int>(
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
                          Get.offAllNamed('/auth/LoginUserAccount');
                          FunHelper.scheduleFirebaseSignOutAndClearPrefs();
                        } else if (value == 1) {
                          Get.toNamed('/auth/resetPassword');
                        } else if (value == 2) {
                          if (kIsWeb) {
                            showClientProfileDialog(Get.context!);
                          } else {
                            Get.toNamed('/clientProfile');
                          }
                        }
                      },
                      itemBuilder:
                          (context) => [
                            PopupMenuItem(
                              value: 2,
                              child: Row(
                                children: [
                                  Text(
                                    'client.profile.menu'.tr,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.person_outline,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(avatarUrl),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.expand_more,
                            size: 22,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ],
                      ),
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
