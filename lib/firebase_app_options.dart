import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';
import 'package:point/firebase_options.dart' as firebase_prod;
import 'package:point/firebase_options_test.dart' as firebase_test;

/// اختيار مشروع Firebase بين التطوير والإنتاج.
///
/// **السلوك الافتراضي (بدون تعريفات إضافية):**
/// - [kDebugMode] → ملف [firebase_test] (مشروع الاختبار، مناسب لـ `flutter run` محلياً).
/// - إصدار / profile → [firebase_prod] (`flutter build web/apk/ipa --release`، Codemagic، السيرفر).
///
/// **تجاوز صريح (اختياري):**
/// - `--dart-define=USE_FIREBASE_PROD=true` — إجبار الإنتاج حتى في debug (مثلاً تصحيح ضد prod).
/// - `--dart-define=USE_FIREBASE_TEST=true` — إجبار الاختبار حتى في release (نادر).
///
/// في CI يُنصح بـ `USE_FIREBASE_PROD=true` مع البناء النهائي لضمان عدم الخلط.
class FirebaseAppOptions {
  FirebaseAppOptions._();

  static const bool _forceTest = bool.fromEnvironment(
    'USE_FIREBASE_TEST',
    defaultValue: false,
  );
  static const bool _forceProd = bool.fromEnvironment(
    'USE_FIREBASE_PROD',
    defaultValue: false,
  );

  /// يطابق اختيار [currentPlatform]: مشروع الاختبار (`firebase_options_test`) وليس الإنتاج.
  /// يُستخدم لإخفاء أدوات التطوير (مثل زر اختبار الإشعارات) في بناءات الإنتاج.
  static bool get isUsingTestFirebaseProject {
    if (_forceProd && _forceTest) {
      throw StateError(
        'تعيين USE_FIREBASE_PROD و USE_FIREBASE_TEST معاً غير مسموح.',
      );
    }
    if (_forceProd) return false;
    if (_forceTest) return true;
    if (kDebugMode) return true;
    return false;
  }

  static FirebaseOptions get currentPlatform {
    if (_forceProd && _forceTest) {
      throw StateError(
        'تعيين USE_FIREBASE_PROD و USE_FIREBASE_TEST معاً غير مسموح.',
      );
    }
    if (_forceProd) {
      return firebase_prod.DefaultFirebaseOptions.currentPlatform;
    }
    if (_forceTest) {
      return firebase_test.DefaultFirebaseOptions.currentPlatform;
    }
    if (kDebugMode) {
      return firebase_test.DefaultFirebaseOptions.currentPlatform;
    }
    return firebase_prod.DefaultFirebaseOptions.currentPlatform;
  }
}
