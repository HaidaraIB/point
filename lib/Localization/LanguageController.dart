import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController extends GetxController {
  /// Shared with [StorageKeys] consumers that sync locale to Firestore (FCM cache).
  static const prefsLocaleCodeKey = 'app_locale_code';
  final Rx<Locale> currentLocale = const Locale('ar').obs;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(prefsLocaleCodeKey);
    // Default Arabic-first; users can switch to English in settings.
    const fallback = 'ar';
    final code = (savedCode == 'ar' || savedCode == 'en') ? savedCode! : fallback;
    await changeLanguage(code, persist: false);
  }

  /// Writes current saved (or in-memory) locale to `employees` / `clients` when
  /// FCM prefs hold a role + user id. Safe no-op when logged out or offline.
  static Future<void> syncPersistedLocaleToFirestore() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) return;

      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(StorageKeys.prefsFcmTokenRole);
      final userId = prefs.getString(StorageKeys.prefsFcmTokenUserId)?.trim();
      if (userId == null || userId.isEmpty || role == null) return;

      String code = 'ar';
      if (Get.isRegistered<LanguageController>()) {
        code = Get.find<LanguageController>().currentLocale.value.languageCode;
      } else {
        final s = prefs.getString(prefsLocaleCodeKey);
        if (s == 'en' || s == 'ar') code = s!;
      }
      if (code != 'ar' && code != 'en') code = 'ar';

      if (role == 'employee') {
        await FirestoreServices.setEmployeeLanguage(
          employeeId: userId,
          code: code,
        );
      } else if (role == 'client') {
        await FirestoreServices.setClientLanguage(
          clientId: userId,
          code: code,
        );
      }
    } catch (_) {}
  }

  Future<void> changeLanguage(String code, {bool persist = true}) async {
    if (code != 'ar' && code != 'en') return;
    final locale = Locale(code);
    currentLocale.value = locale;
    await Get.updateLocale(locale);
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsLocaleCodeKey, code);
    }
    await syncPersistedLocaleToFirestore();
  }

  bool get isArabic => currentLocale.value.languageCode == 'ar';
}
