import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/Utils/AppNotificationInbox.dart';
import 'package:point/View/Chats/MChatPage.dart';
import 'package:point/View/EmployeeDashboard/employee_dashboard_dialogs.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/app_theme_menu_button.dart';
import 'package:point/View/Shared/internet_status_badge.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Shared white app bar for employee flows (dashboard, content management).
class EmployeeMobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EmployeeMobileAppBar({super.key, required this.controller});

  final HomeController controller;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final languageController = Get.find<LanguageController>();
    final theme = Theme.of(context);
    final appTheme = theme.colorScheme;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: appTheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      titleSpacing: 10,
      title: Row(
        children: [
          IconButton(
            tooltip: 'header.notifications'.tr,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined, color: context.appTheme.accentText),
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
            icon: Icon(Icons.language, color: context.appTheme.accentText),
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
          const AppThemeMenuButton(compact: true),
          IconButton(
            tooltip: 'header.chat'.tr,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.chat_bubble_outline, color: context.appTheme.accentText),
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
          if (kIsWeb) ...[
            const InternetStatusBadge(),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Obx(() {
              final emp = controller.currentEmployee.value;
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: context.appTheme.primaryText,
                            ),
                          ),
                        if (displayRole.isNotEmpty) ...[
                          if (displayName.isNotEmpty) const SizedBox(height: 2),
                          Text(
                            localizedRoleWithDepartments(
                              displayRole,
                              emp?.departments ?? const [],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.appTheme.mutedText,
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
                    color: context.appTheme.cardSurface,
                    elevation: 4,
                    onSelected: (value) async {
                      if (value == 0) {
                        final shouldLogout =
                            await confirmEmployeeLogoutDialog(Get.context!);
                        if (!shouldLogout) return;
                        controller.clearEmployeeSession();
                        Get.offAllNamed('/auth/login');
                        FunHelper.scheduleFirebaseSignOutAndClearPrefs();
                      } else if (value == 1) {
                        Get.toNamed('/auth/resetPassword');
                      } else if (value == 2) {
                        Get.toNamed('/employeeProfile');
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 2,
                            child: Row(
                              children: [
                                Text(
                                  'employee.profile.menu'.tr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: context.appTheme.primaryText,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.person_outline,
                                  color: context.appTheme.accentText,
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: context.appTheme.primaryText,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.lock_reset,
                                  color: context.appTheme.accentText,
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: context.appTheme.primaryText,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.logout, color: Colors.red),
                              ],
                            ),
                          ),
                        ],
                    child: AppUserAvatar(
                      url: avatarUrl,
                      radius: 16,
                      displayName: displayName,
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
