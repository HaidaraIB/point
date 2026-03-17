// تم استبدال تهيئة Firebase بقراءة القيم من .env في main.dart.
// لا تضع مفاتيح حقيقية هنا. استخدم ملف .env (انظر .env.example).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// @deprecated استخدم Firebase options من .env في main.dart (_firebaseOptionsFromEnv).
/// هذا الملف مُبقى للتوافق مع FlutterFire CLI فقط.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase options are loaded from .env in main(). '
      'Do not use DefaultFirebaseOptions.currentPlatform.',
    );
  }
}
