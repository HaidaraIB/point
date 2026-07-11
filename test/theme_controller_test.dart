import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ThemeController.dart';
import 'package:point/Utils/app_theme.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(ThemeController(), permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  test('ThemeController defaults to system and persists dark mode', () async {
    final controller = Get.find<ThemeController>();
    await controller.initialize();
    expect(controller.themeMode.value, ThemeMode.system);

    await controller.setThemeMode(ThemeMode.dark);
    expect(controller.themeMode.value, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeController.prefsThemeModeKey), 'dark');
  });

  test('AppTheme exposes light and dark extensions', () {
    final light = AppTheme.light().extension<AppThemeExtension>();
    final dark = AppTheme.dark().extension<AppThemeExtension>();

    expect(light, isNotNull);
    expect(dark, isNotNull);
    expect(light!.cardSurface, const Color(0xffffffff));
    expect(dark!.cardSurface, const Color(0xff1A1A24));
  });
}
