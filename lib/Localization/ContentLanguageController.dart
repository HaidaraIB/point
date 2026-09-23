import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chat-only translation target language (`ar`, `en`, or `fa`).
///
/// Separate from [LanguageController] / app UI locale.
class ContentLanguageController extends GetxController {
  static const prefsContentLanguageKey = 'content_language_code';

  final RxnString contentLanguage = RxnString();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefsContentLanguageKey);
    if (_isValid(saved)) {
      contentLanguage.value = saved;
    }
  }

  bool get hasPreference => _isValid(contentLanguage.value);

  String? get codeOrNull {
    final v = contentLanguage.value;
    return _isValid(v) ? v : null;
  }

  static bool _isValid(String? code) =>
      code == 'ar' || code == 'en' || code == 'fa';

  Future<void> changeContentLanguage(String code, {bool persist = true}) async {
    if (!_isValid(code)) return;
    contentLanguage.value = code;
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsContentLanguageKey, code);
    }
    await syncPersistedContentLanguageToFirestore();
  }

  static Future<void> syncPersistedContentLanguageToFirestore() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) return;
      if (!Get.isRegistered<ContentLanguageController>()) return;

      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(StorageKeys.prefsFcmTokenRole);
      final userId = prefs.getString(StorageKeys.prefsFcmTokenUserId)?.trim();
      if (userId == null || userId.isEmpty || role == null) return;

      final code = Get.find<ContentLanguageController>().codeOrNull;
      if (code == null) return;

      if (role == 'employee') {
        await FirestoreServices.setEmployeeContentLanguage(
          employeeId: userId,
          code: code,
        );
      } else if (role == 'client') {
        await FirestoreServices.setClientContentLanguage(
          clientId: userId,
          code: code,
        );
      }
    } catch (_) {}
  }
}
