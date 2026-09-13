import 'package:point/Localization/AppTranslations.dart';

/// Locale-aware lookup for notification (and related) translation keys.
///
/// Use this when composing push/email/inbox copy for a **recipient** whose
/// preferred language may differ from the sender's active GetX locale.
class NotifyLocale {
  NotifyLocale._();

  /// Normalizes Firestore / prefs language to `ar` or `en`. Defaults to `ar`.
  static String normalize(Object? raw) {
    final v = raw?.toString().trim().toLowerCase() ?? '';
    if (v.isEmpty) return 'ar';
    if (v == 'en' || v.startsWith('en-')) return 'en';
    if (v == 'ar' || v.startsWith('ar-')) return 'ar';
    return 'ar';
  }

  /// Translates [key] for [localeCode] (`ar`|`en`), with ar→en fallback.
  /// Substitutes `@param` placeholders from [params] (GetX `.trParams` style).
  static String tr(
    String localeCode,
    String key, [
    Map<String, String>? params,
  ]) {
    final locale = normalize(localeCode);
    final maps = AppTranslations().keys;
    var template = maps[locale]?[key];
    if (template == null || template.isEmpty) {
      template = maps['ar']?[key] ?? maps['en']?[key] ?? key;
    }
    if (params == null || params.isEmpty) return template;
    var out = template;
    for (final e in params.entries) {
      out = out.replaceAll('@${e.key}', e.value);
    }
    return out;
  }
}

/// Resolved push / inbox / email strings for one recipient locale.
class ResolvedNotificationCopy {
  const ResolvedNotificationCopy({
    required this.title,
    required this.body,
    this.actionText,
    this.emailDetails,
  });

  final String title;
  final String body;
  final String? actionText;
  final Map<String, String>? emailDetails;
}

/// Builds [ResolvedNotificationCopy] for a recipient's normalized locale code.
typedef NotificationCopyForLocale =
    ResolvedNotificationCopy Function(String localeCode);
