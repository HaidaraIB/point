import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static const prefsThemeModeKey = 'app_theme_mode';

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;

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
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsThemeModeKey, _themeModeToString(mode));
    }
  }
}
