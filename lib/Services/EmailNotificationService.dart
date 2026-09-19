import 'package:point/Services/email/app_email_html_composer.dart';
import 'package:point/Utils/app_log.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:point/config/app_config.dart';
import 'package:point/Utils/EdgeFunctionRateLimiter.dart';

/// إرسال إشعارات البريد عبر Supabase Edge Function (يتجنب CORS على الويب).
/// المفتاح يُخزّن في Supabase فقط: Dashboard → Edge Functions → Secrets → RESEND_API_KEY
const String _functionName = 'send-notification-email';

/// One row for [EmailNotificationService.sendDetailedNotificationBatch] (Edge `messages[]`).
/// The same item can be rendered through Supabase wrapper (`isHtml: false`) or
/// local HTML template (`isHtml: true`) based on call configuration.
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
    this.languageCode,
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
  final String? languageCode;
}

class EmailNotificationService {
  EmailNotificationService._();
  static final EmailNotificationService instance = EmailNotificationService._();

  /// لم يعد مستخدماً؛ المفتاح يُضبط في Supabase Secrets (RESEND_API_KEY).
  @Deprecated(
    'Use Supabase Edge Function; set RESEND_API_KEY in Supabase secrets',
  )
  static String? apiKey;

  /// Sends one email via Supabase Edge Function.
  /// - `isHtml: false` => Supabase wrapper template (`email-template.ts`)
  /// - `isHtml: true`  => use provided HTML as-is
  /// Never throws; logs failures only.
  static Future<void> send({
    required String toEmail,
    required String subject,
    required String body,
    bool isHtml = false,
    String? languageCode,
  }) async {
    await sendWithResult(
      toEmail: toEmail,
      subject: subject,
      body: body,
      isHtml: isHtml,
      languageCode: languageCode,
    );
  }

  /// Same as [send] but returns whether delivery succeeded.
  static Future<bool> sendWithResult({
    required String toEmail,
    required String subject,
    required String body,
    bool isHtml = false,
    String? languageCode,
  }) async {
    final trimmedEmail = toEmail.trim();
    if (trimmedEmail.isEmpty) return false;

    try {
      if (AppConfig.isMockEmailMode) {
        _logMockEmail(
          toEmail: trimmedEmail,
          subject: subject,
          body: body,
          isHtml: isHtml,
          languageCode: languageCode,
        );
        return true;
      }

      final client = Supabase.instance.client;
      final res = await EdgeFunctionRateLimiter.instance.run(() {
        return client.functions.invoke(
          _functionName,
          body: {
            'toEmail': trimmedEmail,
            'subject': subject,
            'body': body,
            'isHtml': isHtml,
            if (languageCode != null) 'language': languageCode,
          },
        );
      });

      if (res.status == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>?;
        if (data?['ok'] == true) {
          appLog("✅ Email sent to $trimmedEmail");
          return true;
        }
      }
      appLog(
        "❌ Email edge invoke failed for $trimmedEmail. status=${res.status}, data=${res.data}",
      );
      return false;
    } catch (e, st) {
      appLog("❌ EmailNotificationService error for $trimmedEmail: $e");
      appLog("StackTrace: $st");
      return false;
    }
  }

  /// Simple title/body notification via Supabase wrapper (`isHtml: false`).
  static Future<void> sendNotification({
    required String toEmail,
    required String title,
    required String body,
  }) async {
    try {
      await send(toEmail: toEmail, subject: title, body: body, isHtml: false);
    } catch (e, st) {
      appLog("❌ EmailNotificationService sendNotification error: $e");
      appLog("$st");
    }
  }

  /// Detailed notification email with dynamic fields.
  /// - `useSupabaseTemplateWrapper: true` uses wrapper template (`isHtml: false`)
  /// - otherwise uses local generated HTML (`isHtml: true`)
  static Future<void> sendDetailedNotification({
    required String toEmail,
    required String title,
    required String body,
    bool useSupabaseTemplateWrapper = false,
    String? languageCode,
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
        preferredLanguageCode: languageCode,
      );
      final safeDetails = _dedupeDetails(
        title: title,
        body: body,
        details: details,
      );

      final html = AppEmailHtmlComposer.notification(
        title: title,
        body: body,
        recipientLabel: recipientLabel,
        actionText: actionText,
        details: safeDetails,
        sentAt: sentAt ?? DateTime.now(),
        languageCode: locale,
      );

      if (useSupabaseTemplateWrapper) {
        final wrapperBody = _buildWrapperFriendlyBody(
          body: body,
          details: safeDetails,
          actionText: actionText,
          sentAt: sentAt ?? DateTime.now(),
          locale: locale,
        );
        await send(
          toEmail: toEmail,
          subject: title,
          body: wrapperBody,
          isHtml: false,
          languageCode: locale,
        );
      } else {
        await send(
          toEmail: toEmail,
          subject: title,
          body: html,
          isHtml: true,
          languageCode: locale,
        );
      }
    } catch (e, st) {
      appLog("❌ EmailNotificationService sendDetailedNotification error: $e");
      appLog("$st");
      await sendNotification(toEmail: toEmail, title: title, body: body);
    }
  }

  /// Sends many distinct emails in one/few Edge invocations (`messages[]`, max 40 each).
  /// Default is wrapper-first when `useSupabaseTemplateWrapper` is true.
  static Future<void> sendDetailedNotificationBatch(
    List<DetailedEmailBatchItem> items, {
    bool useSupabaseTemplateWrapper = false,
  }) async {
    if (items.isEmpty) return;
    if (AppConfig.isMockEmailMode) {
      _logMockBatch(
        kind: 'detailed',
        count: items.length,
        firstToEmail: items.first.toEmail.trim(),
        firstSubject: items.first.title,
        isHtml: !useSupabaseTemplateWrapper,
        languageCode: items.first.languageCode,
      );
      return;
    }

    const maxChunk = 40;
    for (var i = 0; i < items.length; i += maxChunk) {
      final end = (i + maxChunk > items.length) ? items.length : i + maxChunk;
      final chunk = items.sublist(i, end);
      final messages = <Map<String, dynamic>>[];
      for (final item in chunk) {
        final locale = _resolveLocale(
          '${item.title}\n${item.body}\n${(item.details ?? const <String, String>{}).entries.map((e) => '${e.key} ${e.value}').join(' ')}',
          preferredLanguageCode: item.languageCode,
        );
        final safeDetails = _dedupeDetails(
          title: item.title,
          body: item.body,
          details: item.details,
        );
        final html = AppEmailHtmlComposer.notification(
          title: item.title,
          body: item.body,
          recipientLabel: item.recipientLabel,
          actionText: item.actionText,
          details: safeDetails,
          sentAt: item.sentAt ?? DateTime.now(),
          languageCode: locale,
        );
        final wrapperBody = _buildWrapperFriendlyBody(
          body: item.body,
          details: safeDetails,
          actionText: item.actionText,
          sentAt: item.sentAt ?? DateTime.now(),
          locale: locale,
        );
        messages.add(<String, dynamic>{
          'toEmail': item.toEmail.trim(),
          'subject': item.title,
          'body': useSupabaseTemplateWrapper ? wrapperBody : html,
          'isHtml': !useSupabaseTemplateWrapper,
          'language': locale,
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

  /// Same plain body to many addresses, rendered via Supabase wrapper (`isHtml: false`).
  static Future<void> sendPlainNotificationBatch({
    required List<String> toEmails,
    required String subject,
    required String body,
    String? languageCode,
  }) async {
    final trimmed = toEmails
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (trimmed.isEmpty) return;
    final locale = _resolveLocale(body, preferredLanguageCode: languageCode);
    if (AppConfig.isMockEmailMode) {
      _logMockBatch(
        kind: 'plain',
        count: trimmed.length,
        firstToEmail: trimmed.first,
        firstSubject: subject,
        isHtml: false,
        languageCode: locale,
      );
      return;
    }

    const maxChunk = 40;
    for (var i = 0; i < trimmed.length; i += maxChunk) {
      final end = (i + maxChunk > trimmed.length)
          ? trimmed.length
          : i + maxChunk;
      final chunk = trimmed.sublist(i, end);
      final messages = chunk
          .map(
            (e) => <String, dynamic>{
              'toEmail': e,
              'subject': subject,
              'body': body,
              'isHtml': false,
              'language': locale,
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
          if (data?['ok'] == true) continue;
        }
        appLog(
          '❌ Email plain batch failed. status=${res.status}, data=${res.data}',
        );
      } catch (e, st) {
        appLog('❌ EmailNotificationService sendPlainNotificationBatch: $e');
        appLog('$st');
      }
    }
  }

  static void _logMockEmail({
    required String toEmail,
    required String subject,
    required String body,
    required bool isHtml,
    String? languageCode,
  }) {
    final language = languageCode ?? 'auto';
    appLog(
      'Mock email skipped Edge Function. to=$toEmail, subject="$subject", '
      'isHtml=$isHtml, language=$language, bodyLength=${body.length}',
    );
  }

  static void _logMockBatch({
    required String kind,
    required int count,
    required String firstToEmail,
    required String firstSubject,
    required bool isHtml,
    String? languageCode,
  }) {
    final language = languageCode ?? 'auto';
    appLog(
      'Mock $kind email batch skipped Edge Function. count=$count, '
      'firstTo=$firstToEmail, firstSubject="$firstSubject", '
      'isHtml=$isHtml, language=$language',
    );
  }

  /// Drops detail rows that duplicate title/body or each other.
  static Map<String, String> _dedupeDetails({
    required String title,
    required String body,
    Map<String, String>? details,
  }) {
    if (details == null || details.isEmpty) return const {};
    final seenValues = <String>{_normCompareKey(title), _normCompareKey(body)};
    final out = <String, String>{};
    for (final e in details.entries) {
      final key = e.key.trim();
      final value = e.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      final valueKey = _normCompareKey(value);
      if (seenValues.contains(valueKey)) continue;
      seenValues.add(valueKey);
      out[key] = value;
    }
    return out;
  }

  static String _normCompareKey(String s) => s.trim().toLowerCase();

  static String _resolveLocale(String text, {String? preferredLanguageCode}) {
    final normalized = _normalizeLanguageCode(preferredLanguageCode);
    if (normalized != null) return normalized;
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? 'ar' : 'en';
  }

  static String? _normalizeLanguageCode(String? code) {
    final v = (code ?? '').trim().toLowerCase();
    if (v == 'ar' || v.startsWith('ar-')) return 'ar';
    if (v == 'en' || v.startsWith('en-')) return 'en';
    return null;
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
      isArabic
          ? 'لديك إشعار جديد من النظام.'
          : 'You have a new notification from the system.',
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
      lines.add(isArabic ? 'الإجراء: $cleanAction' : 'Action: $cleanAction');
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

}
