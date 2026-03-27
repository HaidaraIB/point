import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/Utils/AppNotificationInbox.dart';
import 'package:point/View/Chats/MChatPage.dart';
import 'package:point/View/EmployeeDashboard/employee_dashboard_dialogs.dart';
import 'package:point/View/Shared/CustomHeader.dart';

/// Shared white app bar for employee flows (dashboard, content management).
class EmployeeMobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EmployeeMobileAppBar({super.key, required this.controller});

  final HomeController controller;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final languageController = Get.find<LanguageController>();
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 10,
      title: Row(
        children: [
          IconButton(
            tooltip: 'header.notifications'.tr,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, color: AppColors.primary),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Obx(
                    () => HeaderCountBadge(
                      count: unreadInAppInboxCount(controller.notifications),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              showEmployeeNotificationsDialog(Get.context!, controller);
            },
          ),
          PopupMenuButton<String>(
            tooltip: AppLocaleKeys.appLanguage.tr,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.language, color: AppColors.primary),
            onSelected: (value) => languageController.changeLanguage(value),
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
          IconButton(
            tooltip: 'header.chat'.tr,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Obx(
                    () => HeaderCountBadge(
                      count: controller.totalUnreadMessages.value,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () => Get.to(() => ChatsListScreen(onMinimize: () {})),
          ),
          Expanded(
            child: Obx(() {
              final emp = controller.currentemployee.value;
              final displayName = (emp?.name ?? '').trim();
              final displayRole = (emp?.role ?? '').trim();
              final avatarUrl = emp?.image ?? kDefaultAvatarUrl;
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (displayName.isNotEmpty)
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
                        if (displayRole.isNotEmpty) ...[
                          if (displayName.isNotEmpty) const SizedBox(height: 2),
                          Text(
                            displayRole.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
                            await confirmEmployeeLogoutDialog(Get.context!);
                        if (!shouldLogout) return;
                        controller.clearEmployeeSession();
                        await FirestoreServices().signOut();
                        FunHelper.removeLoginData();
                        Get.offAllNamed('/auth/login');
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
}
