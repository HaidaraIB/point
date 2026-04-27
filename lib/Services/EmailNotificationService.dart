import 'package:point/Utils/app_log.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:point/Utils/EdgeFunctionRateLimiter.dart';

/// إرسال إشعارات البريد عبر Supabase Edge Function (يتجنب CORS على الويب).
/// المفتاح يُخزّن في Supabase فقط: Dashboard → Edge Functions → Secrets → RESEND_API_KEY
const String _functionName = 'send-notification-email';

/// One row for [EmailNotificationService.sendDetailedNotificationBatch] (Edge `messages[]`).
class DetailedEmailBatchItem {
  const DetailedEmailBatchItem({
    required this.toEmail,
    required this.title,
    required this.body,
    this.recipientLabel,
    this.notificationType,
    this.actionText,
    this.referenceId,
    this.details,
    this.sentAt,
  });

  final String toEmail;
  final String title;
  final String body;
  final String? recipientLabel;
  final String? notificationType;
  final String? actionText;
  final String? referenceId;
  final Map<String, String>? details;
  final DateTime? sentAt;
}

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
      final res = await EdgeFunctionRateLimiter.instance.run(() {
        return client.functions.invoke(
          _functionName,
          body: {
            'toEmail': toEmail.trim(),
            'subject': subject,
            'body': body,
            'isHtml': isHtml,
          },
        );
      });

      if (res.status == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>?;
        if (data?['ok'] == true) {
          appLog("✅ Email sent to $toEmail");
          return;
        }
      }
      appLog(
        "❌ Email edge invoke failed for $toEmail. status=${res.status}, data=${res.data}",
      );
    } catch (e, st) {
      appLog("❌ EmailNotificationService error for $toEmail: $e");
      appLog("StackTrace: $st");
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
      appLog("❌ EmailNotificationService sendNotification error: $e");
      appLog("$st");
    }
  }

  /// إرسال إشعار بريد مفصل بصيغة HTML مع تفاصيل ديناميكية.
  static Future<void> sendDetailedNotification({
    required String toEmail,
    required String title,
    required String body,
    bool useSupabaseTemplateWrapper = false,
    String? recipientLabel,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? details,
    DateTime? sentAt,
  }) async {
    try {
      final locale = _resolveLocale(
        '$title\n$body\n${(details ?? const <String, String>{}).entries.map((e) => '${e.key} ${e.value}').join(' ')}',
      );
      final safeDetails = <String, String>{
        if (details != null) ...details,
        if (notificationType != null && notificationType.trim().isNotEmpty)
          locale == 'ar' ? 'نوع الإشعار' : 'Notification type': notificationType.trim(),
        if (referenceId != null && referenceId.trim().isNotEmpty)
          locale == 'ar' ? 'المرجع' : 'Reference': referenceId.trim(),
      };

      final html = _buildHtmlTemplate(
        title: title,
        body: body,
        recipientLabel: recipientLabel,
        actionText: actionText,
        details: safeDetails,
        sentAt: sentAt ?? DateTime.now(),
      );

      if (useSupabaseTemplateWrapper) {
        final wrapperBody = _buildWrapperFriendlyBody(
          body: body,
          details: safeDetails,
          actionText: actionText,
          sentAt: sentAt ?? DateTime.now(),
          locale: locale,
        );
        await send(toEmail: toEmail, subject: title, body: wrapperBody, isHtml: false);
      } else {
        await send(toEmail: toEmail, subject: title, body: html, isHtml: true);
      }
    } catch (e, st) {
      appLog("❌ EmailNotificationService sendDetailedNotification error: $e");
      appLog("$st");
      await sendNotification(toEmail: toEmail, title: title, body: body);
    }
  }

  /// Builds the same HTML as [sendDetailedNotification] for batch or custom sends.
  static String buildDetailedNotificationHtml({
    required String title,
    required String body,
    String? recipientLabel,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? details,
    DateTime? sentAt,
  }) {
    final locale = _resolveLocale(
      '$title\n$body\n${(details ?? const <String, String>{}).entries.map((e) => '${e.key} ${e.value}').join(' ')}',
    );
    final safeDetails = <String, String>{
      if (details != null) ...details,
      if (notificationType != null && notificationType.trim().isNotEmpty)
        locale == 'ar' ? 'نوع الإشعار' : 'Notification type': notificationType.trim(),
      if (referenceId != null && referenceId.trim().isNotEmpty)
        locale == 'ar' ? 'المرجع' : 'Reference': referenceId.trim(),
    };
    return _buildHtmlTemplate(
      title: title,
      body: body,
      recipientLabel: recipientLabel,
      actionText: actionText,
      details: safeDetails,
      sentAt: sentAt ?? DateTime.now(),
    );
  }

  /// Sends many distinct HTML emails in one or few Edge invocations (`messages[]`, max 40 each).
  static Future<void> sendDetailedNotificationBatch(
    List<DetailedEmailBatchItem> items,
  ) async {
    if (items.isEmpty) return;
    const maxChunk = 40;
    for (var i = 0; i < items.length; i += maxChunk) {
      final end = (i + maxChunk > items.length) ? items.length : i + maxChunk;
      final chunk = items.sublist(i, end);
      final messages = <Map<String, dynamic>>[];
      for (final item in chunk) {
        final html = buildDetailedNotificationHtml(
          title: item.title,
          body: item.body,
          recipientLabel: item.recipientLabel,
          notificationType: item.notificationType,
          actionText: item.actionText,
          referenceId: item.referenceId,
          details: item.details,
          sentAt: item.sentAt,
        );
        messages.add(<String, dynamic>{
          'toEmail': item.toEmail.trim(),
          'subject': item.title,
          'body': html,
          'isHtml': true,
        });
      }
      try {
        final client = Supabase.instance.client;
        final res = await EdgeFunctionRateLimiter.instance.run(() {
          return client.functions.invoke(
            _functionName,
            body: <String, dynamic>{'messages': messages},
          );
        });
        if (res.status == 200 && res.data != null) {
          final data = res.data as Map<String, dynamic>?;
          if (data?['ok'] == true) {
            appLog(
              '✅ Email batch sent chunk ${i ~/ maxChunk + 1} (${chunk.length} messages)',
            );
            continue;
          }
        }
        appLog(
          '❌ Email batch invoke failed. status=${res.status}, data=${res.data}',
        );
      } catch (e, st) {
        appLog('❌ EmailNotificationService sendDetailedNotificationBatch: $e');
        appLog('$st');
      }
    }
  }

  /// Same HTML body to many addresses (e.g. topic broadcast); chunks to 40 per request.
  static Future<void> sendPregeneratedHtmlBatch({
    required List<String> toEmails,
    required String subject,
    required String htmlBody,
  }) async {
    final trimmed =
        toEmails
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    if (trimmed.isEmpty) return;
    const maxChunk = 40;
    for (var i = 0; i < trimmed.length; i += maxChunk) {
      final end = (i + maxChunk > trimmed.length) ? trimmed.length : i + maxChunk;
      final chunk = trimmed.sublist(i, end);
      final messages =
          chunk
              .map(
                (e) => <String, dynamic>{
                  'toEmail': e,
                  'subject': subject,
                  'body': htmlBody,
                  'isHtml': true,
                },
              )
              .toList();
      try {
        final client = Supabase.instance.client;
        final res = await EdgeFunctionRateLimiter.instance.run(() {
          return client.functions.invoke(
            _functionName,
            body: <String, dynamic>{'messages': messages},
          );
        });
        if (res.status == 200 && res.data != null) {
          final data = res.data as Map<String, dynamic>?;
          if (data?['ok'] == true) {
            appLog(
              '✅ Email pregenerated batch chunk ${i ~/ maxChunk + 1} (${chunk.length})',
            );
            continue;
          }
        }
        appLog(
          '❌ Email pregenerated batch failed. status=${res.status}, data=${res.data}',
        );
      } catch (e, st) {
        appLog('❌ EmailNotificationService sendPregeneratedHtmlBatch: $e');
        appLog('$st');
      }
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
    final locale = _resolveLocale(
      '$title\n$body\n${(details ?? const <String, String>{}).keys.join(' ')}',
    );
    final isArabic = locale == 'ar';
    final align = isArabic ? 'right' : 'left';
    final dir = isArabic ? 'rtl' : 'ltr';
    final safeTitle = _escapeHtml(title);
    final safeRecipient = _escapeHtml(
      recipientLabel == null || recipientLabel.trim().isEmpty
          ? (isArabic ? 'مستخدم النظام' : 'System user')
          : recipientLabel.trim(),
    );
    final safeAction = _escapeHtml(
      actionText == null || actionText.trim().isEmpty
          ? (isArabic
              ? 'افتح التطبيق للاطلاع على التفاصيل الكاملة.'
              : 'Open the app for full details.')
          : actionText.trim(),
    );
    final sentAtText = _escapeHtml(_formatDateTime(sentAt));
    final conciseSummary = _escapeHtml(
      _composeConciseSummary(body: body, details: details, isArabic: isArabic),
    );

    final detailRows =
        (details ?? const <String, String>{})
            .entries
            .where((e) => e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
            .map(
              (e) =>
                  '<tr><td style="padding:9px 12px;border:1px solid #E6E8EC;background:#FAFAFC;font-weight:600;color:#4b5563;">${_escapeHtml(e.key)}</td><td style="padding:9px 12px;border:1px solid #E6E8EC;color:#111827;">${_escapeHtml(e.value)}</td></tr>',
            )
            .join();

    final detailsSection =
        detailRows.isEmpty
            ? ''
            : '''
      <h3 style="margin:20px 0 10px;color:#111827;font-size:15px;">${isArabic ? 'تفاصيل سريعة' : 'Quick details'}</h3>
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;font-size:14px;color:#1f2937;">
        $detailRows
      </table>
    ''';

    return '''
<!doctype html>
<html lang="$locale" dir="$dir">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$safeTitle</title>
  </head>
  <body style="margin:0;padding:0;background:#F2F3F5;font-family:'Segoe UI',Tahoma,Arial,sans-serif;color:#111827;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="640" cellspacing="0" cellpadding="0" style="max-width:640px;background:#ffffff;border:1px solid #E6E8EC;border-radius:16px;overflow:hidden;box-shadow:0 8px 24px rgba(16,24,40,0.06);">
            <tr>
              <td style="background:linear-gradient(135deg,#6736AE 0%,#552A8E 100%);color:#ffffff;padding:20px 22px;text-align:$align;">
                <p style="margin:0;font-size:20px;font-weight:700;">Point Agency</p>
                <p style="margin:6px 0 0;font-size:13px;opacity:0.92;">${isArabic ? 'إشعار من التطبيق' : 'App notification'}</p>
              </td>
            </tr>
            <tr>
              <td style="padding:22px;text-align:$align;">
                <p style="margin:0 0 12px;font-size:14px;color:#4B5563;">${isArabic ? 'مرحباً' : 'Hello'} $safeRecipient،</p>
                <h2 style="margin:0 0 10px;font-size:20px;line-height:1.35;color:#111827;">$safeTitle</h2>
                <p style="margin:0 0 16px;font-size:15px;line-height:1.7;color:#111827;">$conciseSummary</p>

                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border:1px solid #E6E8EC;border-radius:10px;background:#FAFAFC;">
                  <tr>
                    <td style="padding:12px 14px;font-size:13px;color:#4b5563;text-align:$align;">
                      <strong>${isArabic ? 'وقت الإشعار' : 'Notification time'}:</strong> $sentAtText
                    </td>
                  </tr>
                </table>

                $detailsSection

                <p style="margin:16px 0 0;padding:12px 14px;background:#F8F5FD;border-radius:10px;font-size:14px;color:#111827;line-height:1.7;">
                  <strong>${isArabic ? 'الإجراء' : 'Action'}:</strong> $safeAction
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:14px 20px;background:#FAFAFC;border-top:1px solid #E6E8EC;color:#6b7280;font-size:12px;text-align:$align;">
                ${isArabic ? 'تم إرسال هذا الإشعار تلقائياً من نظام $_systemName.' : 'This notification was sent automatically from $_systemName.'}
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

  static String _composeConciseSummary({
    required String body,
    required Map<String, String>? details,
    required bool isArabic,
  }) {
    final source = details ?? const <String, String>{};
    final task = _findDetailValue(source, const [
      'المهمة',
      'عنوان المهمة',
      'Task',
      'Task title',
    ]);
    final status = _findDetailValue(source, const [
      'الحالة الجديدة',
      'الحالة',
      'New status',
      'Status',
    ]);
    final actor = _findDetailValue(source, const [
      'تم التغيير بواسطة',
      'الموظف',
      'Changed by',
      'Employee',
    ]);

    if (task != null && status != null) {
      if (isArabic) {
        final actorPart = actor == null ? '' : ' من قبل $actor';
        return 'تم تغيير حالة المهمة $task إلى $status$actorPart.';
      }
      final actorPart = actor == null ? '' : ' by $actor';
      return 'Task status changed for $task to $status$actorPart.';
    }

    return body.trim().isEmpty
        ? (isArabic ? 'لديك تحديث جديد.' : 'You have a new update.')
        : body.trim();
  }

  static String? _findDetailValue(Map<String, String> details, List<String> keys) {
    for (final key in keys) {
      final value = details[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _resolveLocale(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? 'ar' : 'en';
  }

  static String _buildWrapperFriendlyBody({
    required String body,
    required Map<String, String> details,
    required DateTime sentAt,
    required String locale,
    String? actionText,
  }) {
    final isArabic = locale == 'ar';
    final lines = <String>[];
    lines.add(
      isArabic ? 'لديك إشعار جديد من النظام.' : 'You have a new notification from the system.',
    );
    final cleanBody = body.trim();
    if (cleanBody.isNotEmpty) {
      lines.add(cleanBody);
    }
    lines.add('');
    if (details.isNotEmpty) {
      for (final e in details.entries) {
        final key = e.key.trim();
        final value = e.value.trim();
        if (key.isEmpty || value.isEmpty) continue;
        lines.add('$key: $value');
      }
      lines.add('');
    }
    lines.add(
      isArabic
          ? 'وقت الإشعار: ${_formatDateTime(sentAt)}'
          : 'Notification time: ${_formatDateTime(sentAt)}',
    );
    final cleanAction = actionText?.trim() ?? '';
    if (cleanAction.isNotEmpty) {
      lines.add(
        isArabic ? 'الإجراء: $cleanAction' : 'Action: $cleanAction',
      );
    }
    return lines.join('\n').trim();
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
