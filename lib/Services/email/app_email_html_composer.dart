import 'package:intl/intl.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/notify_locale.dart';
import 'package:point/Services/email/email_html_builders.dart';
import 'package:point/Services/email/email_html_shell.dart';

/// Composes app notification emails using the shared HTML kit.
class AppEmailHtmlComposer {
  AppEmailHtmlComposer._();

  static String chatDigest({
    required String intro,
    required List<EmailChatDigestRow> rows,
    String? languageCode,
  }) {
    final locale = _resolveLocale(intro, preferredLanguageCode: languageCode);
    return EmailHtmlBuilders.chatDigest(
      locale: locale,
      subtitle: _tr(locale, AppLocaleKeys.emailTemplateChatDigestSubtitle),
      heading: _tr(locale, AppLocaleKeys.emailTemplateChatDigestHeading),
      intro: intro,
      rows: rows,
      preheader: intro,
    );
  }

  static String plainWrapper({
    required String body,
    String? languageCode,
  }) {
    final locale = _resolveLocale(body, preferredLanguageCode: languageCode);
    final align = locale == 'ar' ? 'right' : 'left';
    final paragraphs = body
        .split(RegExp(r'\n+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => EmailHtmlShell.paragraph(line, align: align))
        .join();
    final bodyHtml = paragraphs.isNotEmpty
        ? paragraphs
        : EmailHtmlShell.paragraph(body.trim(), align: align);
    return EmailHtmlShell.render(
      locale: locale,
      subtitle: _tr(locale, AppLocaleKeys.emailTemplatePlainSubtitle),
      heading: _tr(locale, AppLocaleKeys.emailTemplatePlainHeading),
      bodyHtml: bodyHtml,
      preheader: body.trim(),
    );
  }

  static String notification({
    required String title,
    required String body,
    String? recipientLabel,
    String? actionText,
    Map<String, String>? details,
    DateTime? sentAt,
    String? languageCode,
  }) {
    final locale = _resolveLocale(
      '$title\n$body\n${(details ?? const {}).values.join(' ')}',
      preferredLanguageCode: languageCode,
    );
    final recipient = recipientLabel?.trim().isNotEmpty == true
        ? recipientLabel!.trim()
        : _tr(locale, AppLocaleKeys.emailTemplateNotificationDefaultUser);
    final action = actionText?.trim().isNotEmpty == true
        ? actionText!.trim()
        : _tr(locale, AppLocaleKeys.emailTemplateNotificationDefaultAction);
    final sent = sentAt ?? DateTime.now();
    final sentText = DateFormat('yyyy-MM-dd HH:mm').format(sent);

    return EmailHtmlBuilders.notification(
      locale: locale,
      subtitle: _tr(locale, AppLocaleKeys.emailTemplateNotificationSubtitle),
      title: title,
      greeting: _tr(
        locale,
        AppLocaleKeys.emailTemplateGreeting,
        {'name': recipient},
      ),
      summary: _composeSummary(
        locale: locale,
        body: body,
      ),
      notificationTimeLabel:
          _tr(locale, AppLocaleKeys.emailTemplateNotificationTime),
      notificationTime: sentText,
      actionLabel: _tr(locale, AppLocaleKeys.emailTemplateNotificationAction),
      actionText: action,
      autoFooter:
          _tr(locale, AppLocaleKeys.emailTemplateNotificationAutoFooter),
      details: _dedupeDetails(title: title, body: body, details: details),
      quickDetailsTitle:
          _tr(locale, AppLocaleKeys.emailTemplateNotificationQuickDetails),
      preheader: body.trim().isNotEmpty ? body.trim() : title,
    );
  }

  static String _tr(
    String locale,
    String key, [
    Map<String, String>? params,
  ]) =>
      NotifyLocale.tr(locale, key, params);

  static String _resolveLocale(String text, {String? preferredLanguageCode}) {
    final preferred = preferredLanguageCode?.trim().toLowerCase();
    if (preferred == 'ar' || preferred == 'en') return preferred!;
    return EmailHtmlShell.detectLocale(text);
  }

  static String _composeSummary({
    required String locale,
    required String body,
  }) {
    final cleanBody = body.trim();
    if (cleanBody.isNotEmpty) return cleanBody;
    return _tr(locale, AppLocaleKeys.emailTemplateNotificationEmptySummary);
  }

  static Map<String, String> _dedupeDetails({
    required String title,
    required String body,
    Map<String, String>? details,
  }) {
    final source = details ?? const <String, String>{};
    final out = <String, String>{};
    final titleNorm = _norm(title);
    final bodyNorm = _norm(body);
    for (final entry in source.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      final valueNorm = _norm(value);
      if (valueNorm == titleNorm || valueNorm == bodyNorm) continue;
      out[key] = value;
    }
    return out;
  }

  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
