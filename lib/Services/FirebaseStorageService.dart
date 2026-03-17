import 'dart:developer';

import 'package:firebase_storage/firebase_storage.dart';

/// خدمة للتعامل مع Firebase Storage والتحقق من الاتصال.
class FirebaseStorageService {
  static FirebaseStorage get _storage => FirebaseStorage.instance;

  /// التحقق من أن Firebase Storage مُهيأ (الـ bucket معرّف).
  /// يرجع [true] إذا كان الـ bucket غير فارغ.
  /// لا نستدعي listAll على أي منصة لتجنّب: على الويب CORS، وعلى المحمول
  /// أخطاء توكن المصادقة (التطبيق يستخدم Supabase) و404 عند جذر الـ bucket.
  static Future<bool> checkConnection() async {
    try {
      final bucket = _storage.bucket;
      if (bucket.isEmpty) {
        log('❌ Firebase Storage: storageBucket غير مُعرّف (تحقق من .env)');
        return false;
      }
      log('✅ Firebase Storage: الـ bucket = $bucket');
      return true;
    } catch (e, s) {
      log('❌ Firebase Storage خطأ غير متوقع: $e');
      log('   $s');
      return false;
    }
  }

  /// الحصول على المرجع الافتراضي (للاستخدام في الرفع/التنزيل لاحقاً).
  static Reference get ref => _storage.ref();
}
