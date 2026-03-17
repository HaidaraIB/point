import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

/// إرسال إشعارات البريد عبر Supabase Edge Function (يتجنب CORS على الويب).
/// المفتاح يُخزّن في Supabase فقط: Dashboard → Edge Functions → Secrets → RESEND_API_KEY
const String _functionName = 'send-notification-email';

class EmailNotificationService {
  EmailNotificationService._();
  static final EmailNotificationService instance = EmailNotificationService._();

  /// لم يعد مستخدماً؛ المفتاح يُضبط في Supabase Secrets (RESEND_API_KEY).
  @Deprecated('Use Supabase Edge Function; set RESEND_API_KEY in Supabase secrets')
  static String? apiKey;

  /// يرسل إيميل إشعار عبر Edge Function. لا يرمي استثناءً أبداً؛ يسجّل الخطأ فقط ولا يوقف التطبيق.
  static Future<void> send({
    required String toEmail,
    required String subject,
    required String body,
    bool isHtml = false,
  }) async {
    if (toEmail.trim().isEmpty) return;

    try {
      final client = Supabase.instance.client;
      final res = await client.functions.invoke(
        _functionName,
        body: {
          'toEmail': toEmail.trim(),
          'subject': subject,
          'body': body,
        },
      );

      if (res.status == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>?;
        if (data?['ok'] == true) {
          log("✅ Email sent to $toEmail");
          return;
        }
      }
      log("❌ Email error ${res.status}: ${res.data}");
    } catch (e, st) {
      log("❌ EmailNotificationService error: $e");
      log("$st");
    }
  }

  /// إشعار بعنوان ونص (مثل push notification). لا يرمي استثناءً أبداً.
  static Future<void> sendNotification({
    required String toEmail,
    required String title,
    required String body,
  }) async {
    try {
      await send(
        toEmail: toEmail,
        subject: title,
        body: body,
        isHtml: false,
      );
    } catch (e, st) {
      log("❌ EmailNotificationService sendNotification error: $e");
      log("$st");
    }
  }
}
