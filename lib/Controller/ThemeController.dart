import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static const prefsThemeModeKey = 'app_theme_mode';

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;

  /// Resolved brightness for the active [themeMode] (includes system preference).
  Brightness get effectiveBrightness {
    switch (themeMode.value) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return SchedulerBinding
            .instance
            .platformDispatcher
            .platformBrightness;
    }
  }

  AppThemeExtension get extension =>
      effectiveBrightness == Brightness.dark
          ? AppThemeExtension.dark
          : AppThemeExtension.light;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefsThemeModeKey);
    final mode = _parseThemeMode(saved) ?? ThemeMode.system;
    await setThemeMode(mode, persist: false);
  }

  ThemeMode? _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setThemeMode(ThemeMode mode, {bool persist = true}) async {
    if (themeMode.value == mode && !persist) return;
    themeMode.value = mode;
    // Do not call Get.changeThemeMode here — it updates Get.theme immediately and
    // triggers Get.forceAppUpdate before GetMaterialApp applies the new Theme,
    // leaving widgets with mixed light/dark colors until a full refresh.
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsThemeModeKey, _themeModeToString(mode));
    }
  }
}
