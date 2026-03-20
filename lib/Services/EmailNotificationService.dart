import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

/// إرسال إشعارات البريد عبر Supabase Edge Function (يتجنب CORS على الويب).
/// المفتاح يُخزّن في Supabase فقط: Dashboard → Edge Functions → Secrets → RESEND_API_KEY
const String _functionName = 'send-notification-email';

class EmailNotificationService {
  EmailNotificationService._();
  static final EmailNotificationService instance = EmailNotificationService._();

  static const String _systemName = 'Point Agency';

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
          'isHtml': isHtml,
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

  /// إرسال إشعار بريد مفصل بصيغة HTML مع تفاصيل ديناميكية.
  static Future<void> sendDetailedNotification({
    required String toEmail,
    required String title,
    required String body,
    String? recipientLabel,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? details,
    DateTime? sentAt,
  }) async {
    try {
      final safeDetails = <String, String>{
        if (details != null) ...details,
        if (notificationType != null && notificationType.trim().isNotEmpty)
          'نوع الإشعار': notificationType.trim(),
        if (referenceId != null && referenceId.trim().isNotEmpty)
          'المرجع': referenceId.trim(),
      };

      final html = _buildHtmlTemplate(
        title: title,
        body: body,
        recipientLabel: recipientLabel,
        actionText: actionText,
        details: safeDetails,
        sentAt: sentAt ?? DateTime.now(),
      );

      await send(toEmail: toEmail, subject: title, body: html, isHtml: true);
    } catch (e, st) {
      log("❌ EmailNotificationService sendDetailedNotification error: $e");
      log("$st");
      await sendNotification(toEmail: toEmail, title: title, body: body);
    }
  }

  static String _buildHtmlTemplate({
    required String title,
    required String body,
    required DateTime sentAt,
    String? recipientLabel,
    String? actionText,
    Map<String, String>? details,
  }) {
    final summary = _escapeHtml(body);
    final safeTitle = _escapeHtml(title);
    final safeRecipient = _escapeHtml(
      recipientLabel == null || recipientLabel.trim().isEmpty
          ? 'مستخدم النظام'
          : recipientLabel.trim(),
    );
    final safeAction = _escapeHtml(
      actionText == null || actionText.trim().isEmpty
          ? 'يرجى مراجعة النظام للاطلاع على التفاصيل الكاملة.'
          : actionText.trim(),
    );
    final sentAtText = _escapeHtml(_formatDateTime(sentAt));

    final detailRows =
        (details ?? const <String, String>{})
            .entries
            .where((e) => e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
            .map(
              (e) =>
                  '<tr><td style="padding:8px 10px;border:1px solid #e5e7eb;background:#f9fafb;font-weight:600;">${_escapeHtml(e.key)}</td><td style="padding:8px 10px;border:1px solid #e5e7eb;">${_escapeHtml(e.value)}</td></tr>',
            )
            .join();

    final detailsSection =
        detailRows.isEmpty
            ? ''
            : '''
      <h3 style="margin:20px 0 8px;color:#111827;font-size:16px;">تفاصيل الإشعار</h3>
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;font-size:14px;color:#1f2937;">
        $detailRows
      </table>
    ''';

    return '''
<!doctype html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$safeTitle</title>
  </head>
  <body style="margin:0;padding:0;background:#f3f4f6;font-family:Tahoma,Arial,sans-serif;color:#111827;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="640" cellspacing="0" cellpadding="0" style="max-width:640px;background:#ffffff;border:1px solid #e5e7eb;border-radius:12px;overflow:hidden;">
            <tr>
              <td style="background:#111827;color:#ffffff;padding:18px 20px;font-size:20px;font-weight:700;">
                $safeTitle
              </td>
            </tr>
            <tr>
              <td style="padding:20px;">
                <p style="margin:0 0 10px;font-size:14px;color:#374151;">مرحباً $safeRecipient،</p>
                <p style="margin:0 0 16px;font-size:15px;line-height:1.7;color:#111827;">$summary</p>

                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border:1px solid #e5e7eb;border-radius:8px;background:#f9fafb;">
                  <tr>
                    <td style="padding:12px 14px;font-size:13px;color:#4b5563;">
                      <strong>وقت الإشعار:</strong> $sentAtText
                    </td>
                  </tr>
                </table>

                $detailsSection

                <p style="margin:18px 0 0;font-size:14px;color:#111827;line-height:1.7;">
                  <strong>الإجراء المقترح:</strong> $safeAction
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:14px 20px;background:#f9fafb;border-top:1px solid #e5e7eb;color:#6b7280;font-size:12px;">
                تم إرسال هذا الإشعار تلقائياً من نظام $_systemName.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
''';
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
