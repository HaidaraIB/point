import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ThemeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';

class AppThemeMenuButton extends StatelessWidget {
  const AppThemeMenuButton({
    super.key,
    this.iconColor,
    this.compact = false,
    this.onDarkSurface = false,
  });

  final Color? iconColor;
  final bool compact;
  final bool onDarkSurface;

  String _labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppLocaleKeys.appThemeLight.tr;
      case ThemeMode.dark:
        return AppLocaleKeys.appThemeDark.tr;
      case ThemeMode.system:
        return AppLocaleKeys.appThemeSystem.tr;
    }
  }

  List<PopupMenuEntry<ThemeMode>> _buildItems(ThemeMode selected) {
    return ThemeMode.values.map((mode) {
      return PopupMenuItem(
        value: mode,
        child: Row(
          children: [
            if (mode == selected)
              const Icon(Icons.check, size: 18)
            else
              const SizedBox(width: 18),
            const SizedBox(width: 8),
            Text(_labelFor(mode)),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<ThemeController>();
    final resolvedIconColor = iconColor ??
        (onDarkSurface ? Colors.white : context.appTheme.accentText);

    if (compact) {
      return Obx(() {
        final selected = tc.themeMode.value;
        return PopupMenuButton<ThemeMode>(
          tooltip: AppLocaleKeys.appTheme.tr,
          padding: EdgeInsets.zero,
          icon: Icon(Icons.brightness_6, color: resolvedIconColor),
          onSelected: tc.setThemeMode,
          itemBuilder: (context) => _buildItems(selected),
        );
      });
    }

    return Obx(() {
      final selected = tc.themeMode.value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.brightness_6, color: resolvedIconColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocaleKeys.appTheme.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: resolvedIconColor,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              _labelFor(selected),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: resolvedIconColor.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            PopupMenuButton<ThemeMode>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              color: Theme.of(context).colorScheme.surface,
              icon: Icon(Icons.arrow_drop_down, color: resolvedIconColor),
              onSelected: tc.setThemeMode,
              itemBuilder: (context) => _buildItems(selected),
            ),
          ],
        ),
      );
    });
  }
}
