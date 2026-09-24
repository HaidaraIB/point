import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/ThemeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/ContentLanguageController.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Utils/LibraryPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Overflow menu at the bar edge: library plus flyout submenus (language,
/// chat translation, theme) that stay open beside the parent menu.
class EmployeeHeaderMoreMenuButton extends StatelessWidget {
  const EmployeeHeaderMoreMenuButton({
    super.key,
    this.includeAppLanguage = true,
    this.includePreferences = true,
  });

  final bool includeAppLanguage;
  final bool includePreferences;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final hc = Get.find<HomeController>();

    return Obx(() {
      final canLibrary = LibraryPermissions.canAccessLibrary(hc.effectiveEmployee);
      final showLanguage = includeAppLanguage;
      final showPrefs = includePreferences;
      if (!canLibrary && !showLanguage && !showPrefs) {
        return const SizedBox.shrink();
      }

      final menuStyle = _menuStyle(theme);
      final itemStyle = _menuItemStyle(theme);

      return MenuAnchor(
        style: menuStyle,
        alignmentOffset: const Offset(0, 4),
        menuChildren: [
          if (canLibrary)
            MenuItemButton(
              style: itemStyle,
              onPressed: () => Get.toNamed('/library'),
              child: _MenuActionRow(
                label: 'library.sidebar'.tr,
                icon: Icons.folder_copy_outlined,
              ),
            ),
          if (showLanguage)
            SubmenuButton(
              style: itemStyle,
              menuStyle: menuStyle,
              menuChildren: _appLanguageItems(itemStyle),
              child: _SubmenuLabel(AppLocaleKeys.appLanguage.tr),
            ),
          if (showPrefs) ...[
            SubmenuButton(
              style: itemStyle,
              menuStyle: menuStyle,
              menuChildren: _chatTranslationItems(itemStyle),
              child: _SubmenuLabel(AppLocaleKeys.chatTranslationPreference.tr),
            ),
            SubmenuButton(
              style: itemStyle,
              menuStyle: menuStyle,
              menuChildren: _themeItems(itemStyle),
              child: _SubmenuLabel(AppLocaleKeys.appTheme.tr),
            ),
          ],
        ],
        builder: (context, controller, child) {
          return IconButton(
            tooltip: 'header.more'.tr,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(Icons.more_vert, color: theme.accentText),
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          );
        },
      );
    });
  }

  static MenuStyle _menuStyle(AppThemeExtension theme) {
    return MenuStyle(
      backgroundColor: WidgetStatePropertyAll(theme.cardSurface),
      surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      elevation: WidgetStatePropertyAll(4),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      padding: WidgetStatePropertyAll(
        const EdgeInsets.symmetric(vertical: 4),
      ),
    );
  }

  static ButtonStyle _menuItemStyle(AppThemeExtension theme) {
    return ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(theme.primaryText),
      padding: WidgetStatePropertyAll(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      minimumSize: WidgetStatePropertyAll(const Size(200, 44)),
      alignment: AlignmentDirectional.centerStart,
    );
  }

  static List<Widget> _appLanguageItems(ButtonStyle itemStyle) {
    final lc = Get.find<LanguageController>();
    return [
      MenuItemButton(
        style: itemStyle,
        onPressed: () => lc.changeLanguage('ar'),
        child: Text(AppLocaleKeys.appLanguageArabic.tr),
      ),
      MenuItemButton(
        style: itemStyle,
        onPressed: () => lc.changeLanguage('en'),
        child: Text(AppLocaleKeys.appLanguageEnglish.tr),
      ),
    ];
  }

  static List<Widget> _chatTranslationItems(ButtonStyle itemStyle) {
    final clc = Get.find<ContentLanguageController>();
    return [
      MenuItemButton(
        style: itemStyle,
        onPressed: () => clc.changeContentLanguage('ar'),
        child: Text(AppLocaleKeys.chatTranslationArabic.tr),
      ),
      MenuItemButton(
        style: itemStyle,
        onPressed: () => clc.changeContentLanguage('en'),
        child: Text(AppLocaleKeys.chatTranslationEnglish.tr),
      ),
      MenuItemButton(
        style: itemStyle,
        onPressed: () => clc.changeContentLanguage('fa'),
        child: Text(AppLocaleKeys.chatTranslationFarsi.tr),
      ),
    ];
  }

  static List<Widget> _themeItems(ButtonStyle itemStyle) {
    final tc = Get.find<ThemeController>();
    return [
      MenuItemButton(
        style: itemStyle,
        onPressed: () => tc.setThemeMode(ThemeMode.light),
        child: Text(AppLocaleKeys.appThemeLight.tr),
      ),
      MenuItemButton(
        style: itemStyle,
        onPressed: () => tc.setThemeMode(ThemeMode.dark),
        child: Text(AppLocaleKeys.appThemeDark.tr),
      ),
      MenuItemButton(
        style: itemStyle,
        onPressed: () => tc.setThemeMode(ThemeMode.system),
        child: Text(AppLocaleKeys.appThemeSystem.tr),
      ),
    ];
  }
}

class _MenuActionRow extends StatelessWidget {
  const _MenuActionRow({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.primaryText,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: theme.accentText),
      ],
    );
  }
}

class _SubmenuLabel extends StatelessWidget {
  const _SubmenuLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: context.appTheme.primaryText,
        ),
      ),
    );
  }
}
