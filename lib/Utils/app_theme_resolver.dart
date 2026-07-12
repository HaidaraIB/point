import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ThemeController.dart';
import 'package:point/Utils/app_theme_extension.dart';

AppThemeExtension resolveAppTheme([BuildContext? context]) {
  if (context != null) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark
        ? AppThemeExtension.dark
        : AppThemeExtension.light;
  }
  if (Get.isRegistered<ThemeController>()) {
    return Get.find<ThemeController>().extension;
  }
  return AppThemeExtension.light;
}
