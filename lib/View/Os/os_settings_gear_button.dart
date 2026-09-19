import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Opens Point OS settings; hidden on the settings route itself.
class OsSettingsGearButton extends StatelessWidget {
  const OsSettingsGearButton({super.key});

  static bool _isOnSettingsRoute() {
    final route = Get.currentRoute;
    final q = route.indexOf('?');
    final path = q >= 0 ? route.substring(0, q) : route;
    return path == '/os/settings';
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnSettingsRoute()) return const SizedBox.shrink();
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessOsSettings(emp)) {
      return const SizedBox.shrink();
    }

    final theme = context.appTheme;
    return IconButton(
      tooltip: AppLocaleKeys.osSettingsTitle.tr,
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.settings_outlined, color: theme.accentText),
      onPressed: () => Get.toNamed('/os/settings'),
    );
  }
}
