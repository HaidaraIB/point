import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:point/Utils/chat_message_bidi.dart';

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

/// Likely source language for compose-time translation chip (`ar` or `en`).
String detectLikelySourceLangCode(String text) {
  final arCount = RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
  final latinCount = RegExp(r'[A-Za-z]').allMatches(text).length;
  return arCount >= latinCount ? 'ar' : 'en';
}

/// Paragraph direction for a known translation language code.
TextDirection textDirectionForLangCode(String code) {
  switch (code) {
    case 'ar':
    case 'fa':
      return TextDirection.rtl;
    case 'en':
      return TextDirection.ltr;
    default:
      return TextDirection.ltr;
  }
}

/// Prefer [langCode] when set; otherwise infer from [text].
TextDirection textDirectionForTranslation(
  String text, {
  String? langCode,
}) {
  if (langCode != null && langCode.isNotEmpty) {
    return textDirectionForLangCode(langCode);
  }
  return chatMessageTextDirectionFromFirstWord(text) ?? TextDirection.ltr;
}

/// Uppercase chip label for a language code.
String translationLangChipLabel(String code) {
  switch (code) {
    case 'en':
      return 'EN';
    case 'fa':
      return 'FA';
    case 'ar':
      return 'AR';
    default:
      return code.toUpperCase();
  }
}

/// Skip live compose translation when text is already in the target language.
bool shouldSkipComposeTranslation(String text, String targetLang) {
  if (shouldSkipTranslation(text)) return true;
  final source = detectLikelySourceLangCode(text);
  if (targetLang == 'en' && source == 'en') return true;
  if (targetLang == 'ar' && source == 'ar') return true;
  return false;
}

/// Whether [msg] has a valid stored outgoing bilingual translation.
bool messageHasSentTranslation(Map<String, dynamic> msg) {
  final text = (msg['text'] ?? '').toString().trim();
  if (text.isEmpty) return false;
  final translated = (msg['sentTranslation'] as String?)?.trim() ?? '';
  if (translated.isEmpty) return false;
  final lang = (msg['sentTranslationLang'] as String?)?.trim() ?? '';
  if (lang != 'ar' && lang != 'en' && lang != 'fa') return false;
  final storedHash = (msg['sentTranslationSourceHash'] as String?)?.trim() ?? '';
  if (storedHash.isEmpty) return false;
  return storedHash == translationTextHash(text);
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
