import 'dart:ui';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController extends GetxController {
  static const _localeCodeKey = 'app_locale_code';
  final Rx<Locale> currentLocale = const Locale('ar').obs;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_localeCodeKey);
    // Default Arabic-first; users can switch to English in settings.
    const fallback = 'ar';
    final code = (savedCode == 'ar' || savedCode == 'en') ? savedCode! : fallback;
    await changeLanguage(code, persist: false);
  }

  Future<void> changeLanguage(String code, {bool persist = true}) async {
    if (code != 'ar' && code != 'en') return;
    final locale = Locale(code);
    currentLocale.value = locale;
    await Get.updateLocale(locale);
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeCodeKey, code);
    }
  }

  bool get isArabic => currentLocale.value.languageCode == 'ar';
}
