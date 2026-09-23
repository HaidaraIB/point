import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in target language for live outgoing chat translation (`ar`, `en`, `fa`).
///
/// `null` means off. Separate from [ContentLanguageController] (post-send translate button).
class SentTranslationController extends GetxController {
  static const prefsSentTranslationKey = 'sent_translation_target';

  final RxnString targetLanguage = RxnString();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefsSentTranslationKey);
    if (_isValid(saved)) {
      targetLanguage.value = saved;
    }
  }

  bool get isEnabled => _isValid(targetLanguage.value);

  String? get targetOrNull {
    final v = targetLanguage.value;
    return _isValid(v) ? v : null;
  }

  static bool _isValid(String? code) =>
      code == 'ar' || code == 'en' || code == 'fa';

  Future<void> changeTarget(String? code, {bool persist = true}) async {
    if (code != null && !_isValid(code)) return;
    targetLanguage.value = code;
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      if (code == null) {
        await prefs.remove(prefsSentTranslationKey);
      } else {
        await prefs.setString(prefsSentTranslationKey, code);
      }
    }
    await syncPersistedSentTranslationToFirestore();
  }

  static Future<void> syncPersistedSentTranslationToFirestore() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) return;
      if (!Get.isRegistered<SentTranslationController>()) return;

      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(StorageKeys.prefsFcmTokenRole);
      final userId = prefs.getString(StorageKeys.prefsFcmTokenUserId)?.trim();
      if (userId == null || userId.isEmpty || role == null) return;

      final code = Get.find<SentTranslationController>().targetOrNull;

      if (role == 'employee') {
        await FirestoreServices.setEmployeeSentTranslationTarget(
          employeeId: userId,
          code: code,
        );
      } else if (role == 'client') {
        await FirestoreServices.setClientSentTranslationTarget(
          clientId: userId,
          code: code,
        );
      }
    } catch (_) {}
  }
}
