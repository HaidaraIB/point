import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;

/// Paragraph direction per message/content: derive from **first word** script.
/// Matches chat bubble + tile preview behavior on all platforms (web, mobile).
///
/// - First word `"ar"` (case-insensitive) => RTL for legacy payloads.
/// - Otherwise first-strong character in word, then fallback to whole string.
TextDirection? chatMessageTextDirectionFromFirstWord(String rawText) {
  final text = rawText.trimLeft();
  if (text.isEmpty) return null;
  final firstWord = text.split(RegExp(r'\s+')).first.trim().toLowerCase();
  if (firstWord.isEmpty) return null;
  if (firstWord == 'ar') return TextDirection.rtl;
  if (Bidi.startsWithRtl(firstWord)) return TextDirection.rtl;
  if (Bidi.startsWithLtr(firstWord)) return TextDirection.ltr;
  return Bidi.startsWithRtl(text) ? TextDirection.rtl : TextDirection.ltr;
}

/// List row subtitle sits beside the avatar: align text toward that visual edge while
/// [textDirection] still controls line order inside mixed strings.
TextAlign chatListSubtitleAlignToAmbientAvatarSide(TextDirection ambient) {
  return ambient == TextDirection.rtl ? TextAlign.right : TextAlign.left;
}
