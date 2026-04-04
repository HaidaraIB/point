import 'package:point/Utils/app_log.dart';

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
        appLog('❌ Firebase Storage: storageBucket غير مُعرّف (تحقق من .env)');
        return false;
      }
      appLog('✅ Firebase Storage: الـ bucket = $bucket');
      return true;
    } catch (e, s) {
      appLog('❌ Firebase Storage خطأ غير متوقع: $e');
      appLog('   $s');
      return false;
    }
  }

  /// الحصول على المرجع الافتراضي (للاستخدام في الرفع/التنزيل لاحقاً).
  static Reference get ref => _storage.ref();
}
