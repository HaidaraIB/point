import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/ThemeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Mobile/ClientContentDetails.dart';
import 'package:point/View/Mobile/ClientContentGridCard.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/ClientDashboard/client_profile_form.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/app_theme_menu_button.dart';
import 'package:point/View/Shared/chat_translation_language_menu.dart';
import 'package:point/View/Shared/app_version_label.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/Utils/AppNotificationInbox.dart';
import 'package:point/Utils/app_theme.dart';
import 'package:point/Utils/app_theme_extension.dart';

class TabsController extends GetxController {
  RxInt selectedIndex = 0.obs;
}

class ClientHome extends StatelessWidget {
  final LanguageController _languageController = Get.find<LanguageController>();

  static const double _maxContentWidth = 1240;

  @override
  Widget build(BuildContext context) {
    final tabsController = Get.put(TabsController());

    return GetBuilder<ClientController>(
      builder: (controller) {
        return Obx(() {
          final themeController = Get.find<ThemeController>();
          final _ = themeController.themeMode.value;
          final appTheme = themeController.extension;
          final themeData =
              themeController.effectiveBrightness == Brightness.dark
                  ? AppTheme.dark()
                  : AppTheme.light();
          final isWide = !Responsive.isMobile(context);

          return Theme(
            data: themeData,
            child: Scaffold(
              backgroundColor:
                  isWide ? appTheme.pageBackground : appTheme.cardSurface,
              appBar: _buildClientAppBar(controller, appTheme),
              body: RefreshIndicator(
                onRefresh: () async {
                  controller.fetchContents();
                  await Future.delayed(const Duration(seconds: 1));
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _maxContentWidth,
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  isWide ? 32 : 20,
                                  isWide ? 28 : 16,
                                  isWide ? 32 : 20,
                                  0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (isWide) ...[
                                      Text(
                                        'client.home.items_count'.trParams({
                                          'count':
                                              '${_filteredContents(controller, tabsController.selectedIndex.value).length}',
                                        }),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: appTheme.mutedText,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    _ClientStatusTabs(
                                      tabsController: tabsController,
                                      appTheme: appTheme,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Obx(() {
                          final items = _filteredContents(
                            controller,
                            tabsController.selectedIndex.value,
                          );

                          if (items.isEmpty) {
                            return SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: _maxContentWidth,
                                  ),
                                  child: _ClientHomeEmptyState(
                                    appTheme: appTheme,
                                    isWide: isWide,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (isWide) {
                            const gap = 16.0;
                            final crossAxisCount =
                                constraints.maxWidth >= 1100 ? 3 : 2;
                            final gridWidth = (_maxContentWidth).clamp(
                              0.0,
                              constraints.maxWidth - 64,
                            );
                            final cardWidth =
                                (gridWidth - gap * (crossAxisCount - 1)) /
                                crossAxisCount;
                            return SliverPadding(
                              padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
                              sliver: SliverToBoxAdapter(
                                child: Center(
                                  child: SizedBox(
                                    width: gridWidth,
                                    child: Wrap(
                                      spacing: gap,
                                      runSpacing: gap,
                                      children:
                                          items.map((model) {
                                            return SizedBox(
                                              width: cardWidth,
                                              child: ClientContentGridCard(
                                                model: model,
                                                onTap:
                                                    () =>
                                                        openClientContentDetails(
                                                          context,
                                                          model,
                                                        ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            sliver: SliverList.separated(
                              itemCount: items.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final model = items[index];
                                return ContentStatusCard(
                                  index: index,
                                  model: model,
                                  onTap:
                                      () => openClientContentDetails(
                                        context,
                                        model,
                                      ),
                                );
                              },
                            ),
                          );
                        }),
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _maxContentWidth,
                              ),
                              child: AppVersionLabel(
                                padding: EdgeInsets.fromLTRB(
                                  isWide ? 32 : 20,
                                  24,
                                  isWide ? 32 : 20,
                                  16,
                                ),
                                textStyle: TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: appTheme.mutedText,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        });
      },
    );
  }

  PreferredSizeWidget _buildClientAppBar(
    ClientController controller,
    AppThemeExtension appTheme,
  ) {
    return AppBar(
      backgroundColor: appTheme.cardSurface,
      surfaceTintColor: Colors.transparent,
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
                      color: appTheme.elevatedSurface,
                      surfaceTintColor: Colors.transparent,
                      icon: Icon(Icons.language, color: appTheme.accentText),
                      onSelected:
                          (value) => _languageController.changeLanguage(value),
                      itemBuilder:
                          (context) => [
                            PopupMenuItem(
                              value: 'ar',
                              child: Text(
                                AppLocaleKeys.appLanguageArabic.tr,
                                style: TextStyle(color: appTheme.primaryText),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'en',
                              child: Text(
                                AppLocaleKeys.appLanguageEnglish.tr,
                                style: TextStyle(color: appTheme.primaryText),
                              ),
                            ),
                          ],
                    ),
                  ),
                  ChatTranslationLanguageMenu(
                    iconColor: appTheme.accentText,
                    compact: true,
                  ),
                  const AppThemeMenuButton(compact: true),
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
                          icon: Icon(
                            Icons.notifications_outlined,
                            color: appTheme.accentText,
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: appTheme.primaryText,
                            ),
                          ),
                          Text(
                            'user_type_client'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              color: appTheme.mutedText,
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
                      color: appTheme.elevatedSurface,
                      surfaceTintColor: Colors.transparent,
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: appTheme.primaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.person_outline,
                                    color: appTheme.accentText,
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
                                      color: appTheme.primaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.lock_reset,
                                    color: appTheme.accentText,
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
                                      color: appTheme.primaryText,
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
                          AppUserAvatar(
                            url: avatarUrl,
                            radius: 16,
                            displayName: displayName,
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.expand_more,
                            size: 22,
                            color: appTheme.primaryText,
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

List<ContentModel> _filteredContents(
  ClientController controller,
  int tabIndex,
) {
  final all = controller.contents;
  switch (tabIndex) {
    case 1:
      return all
          .where((c) => c.status == StorageKeys.status_approved)
          .toList();
    case 2:
      return all
          .where((c) => c.status == StorageKeys.status_edit_requested)
          .toList();
    case 3:
      return all
          .where((c) => c.status == StorageKeys.status_rejected)
          .toList();
    default:
      return all.toList();
  }
}

class _ClientStatusTabs extends StatelessWidget {
  const _ClientStatusTabs({
    required this.tabsController,
    required this.appTheme,
  });

  static const Color _selectedTabColor = Color(0xFF62529A);

  final TabsController tabsController;
  final AppThemeExtension appTheme;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      'client.status_tab.all'.tr,
      'client.status_tab.approved'.tr,
      'client.status_tab.revision'.tr,
      'client.status_tab.rejected'.tr,
    ];

    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: appTheme.unselected,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = tabsController.selectedIndex.value == index;
            return Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => tabsController.selectedIndex.value = index,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? _selectedTabColor
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
                            isSelected ? Colors.white : appTheme.primaryText,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
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
    });
  }
}

class _ClientHomeEmptyState extends StatelessWidget {
  const _ClientHomeEmptyState({
    required this.appTheme,
    required this.isWide,
  });

  final AppThemeExtension appTheme;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 32 : 20,
        vertical: isWide ? 48 : 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: appTheme.panelTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 36,
              color: appTheme.mutedText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'content.empty_display'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isWide ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: appTheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmClientLogoutDialog(BuildContext context) async {
  final isArabic = Get.locale?.languageCode == 'ar';
  final theme = resolveAppTheme();
  final result = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          backgroundColor: theme.elevatedSurface,
          title: Text(
            'logout'.tr,
            style: TextStyle(color: theme.primaryText),
          ),
          content: Text(
            isArabic
                ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
                : 'Are you sure you want to log out?',
            style: TextStyle(color: theme.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'cancel'.tr,
                style: TextStyle(color: theme.secondaryText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'logout'.tr,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
  );
  return result ?? false;
}
