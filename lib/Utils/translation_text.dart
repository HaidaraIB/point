import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable cache key for translation lookups (matches Edge Function).
String translationTextHash(String text) {
  final normalized = text.trim();
  final bytes = utf8.encode(normalized);
  return sha256.convert(bytes).toString();
}

final _urlOnlyRegex = RegExp(
  r'^\s*(https?:\/\/|www\.)[^\s]+\s*$',
  caseSensitive: false,
);

final _emojiOnlyRegex = RegExp(
  r'^[\s\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{200D}\u{20E3}]+$',
  unicode: true,
);

bool shouldSkipTranslation(String text) {
  final t = text.trim();
  if (t.isEmpty) return true;
  if (_urlOnlyRegex.hasMatch(t)) return true;
  if (_emojiOnlyRegex.hasMatch(t)) return true;
  return false;
}

Map<String, String> parseTranslationMap(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  for (final e in raw.entries) {
    final k = e.key.toString().trim();
    final v = e.value?.toString().trim() ?? '';
    if (k.isEmpty || v.isEmpty) continue;
    out[k] = v;
  }
  return out;
}

String localizedTaskField({
  required String original,
  required Map<String, String> translations,
  required String localeCode,
}) {
  final locale = localeCode == 'en' ? 'en' : 'ar';
  final translated = translations[locale]?.trim();
  if (translated != null && translated.isNotEmpty) return translated;
  return original;
}
