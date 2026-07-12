import 'package:flutter/material.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/Utils/app_theme_extension.dart';

final RegExp _avatarLetter = RegExp(r'[\p{L}]', unicode: true);

/// True when the URL is empty or a generic placeholder (not a real user photo).
bool usesLocalAvatarPlaceholder(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty ||
      trimmed == kDefaultAvatarUrl ||
      trimmed.contains('ui-avatars.com')) {
    return true;
  }
  if (trimmed.endsWith('/Avatar.png') || trimmed.endsWith('Avatar.png')) {
    return true;
  }
  return false;
}

String? _firstLetterGrapheme(String token) {
  for (final c in token.characters) {
    if (_avatarLetter.hasMatch(c)) return c;
  }
  return null;
}

String _letterGraphemes(String value, int max) {
  final out = <String>[];
  for (final c in value.characters) {
    if (_avatarLetter.hasMatch(c)) {
      out.add(c);
      if (out.length >= max) break;
    }
  }
  return out.join();
}

/// Initials from a display name — Arabic-aware (first two graphemes for single
/// names), English two-letter uppercase for Latin multi-word names.
///
/// Parenthetical suffixes like "(Admin)" are ignored so "Point Test (Admin)" → PT.
String avatarInitialsFromName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return 'U';

  // Drop parenthetical role suffixes before splitting words.
  var cleaned = name.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
  if (cleaned.isEmpty) cleaned = name;

  final tokens =
      cleaned.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();

  final letters = <String>[];
  for (final token in tokens) {
    final letter = _firstLetterGrapheme(token);
    if (letter != null) letters.add(letter);
  }

  if (letters.length >= 2) {
    final initials = '${letters.first}${letters.last}';
    if (RegExp(r'^[A-Za-z]+$').hasMatch(initials)) {
      return initials.toUpperCase();
    }
    return initials;
  }

  if (letters.length == 1) {
    final fromToken = _letterGraphemes(cleaned, 2);
    if (fromToken.isNotEmpty) {
      if (RegExp(r'^[A-Za-z]+$').hasMatch(fromToken)) {
        return fromToken.toUpperCase();
      }
      return fromToken;
    }
    return letters.first;
  }

  final fallback = _letterGraphemes(name, 2);
  return fallback.isEmpty ? 'U' : fallback;
}

/// Latin initials stay LTR inside Arabic RTL screens (prevents "PT" → flipped order).
Widget _avatarInitialsLabel(String initials, TextStyle style) {
  final label = Text(initials, style: style);
  if (RegExp(r'^[A-Za-z]+$').hasMatch(initials)) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: label,
    );
  }
  return label;
}

/// Profile avatar matching the navbar: themed placeholder + initials fallback.
class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    super.key,
    required this.url,
    required this.radius,
    this.displayName,
  });

  final String url;
  final double radius;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final trimmedUrl = url.trim();

    if (usesLocalAvatarPlaceholder(trimmedUrl)) {
      final initials = avatarInitialsFromName(displayName ?? '');
      return CircleAvatar(
        radius: radius,
        backgroundColor: theme.unselected,
        child: _avatarInitialsLabel(
          initials,
          TextStyle(
            color: theme.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.9,
            height: 1,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.unselected,
      child: ClipOval(
        child: Image.network(
          trimmedUrl,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (_, __, ___) {
            final initials = avatarInitialsFromName(displayName ?? '');
            if (initials != 'U') {
              return ColoredBox(
                color: theme.unselected,
                child: Center(
                  child: _avatarInitialsLabel(
                    initials,
                    TextStyle(
                      color: theme.primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: radius * 0.9,
                      height: 1,
                    ),
                  ),
                ),
              );
            }
            return Icon(Icons.person, color: theme.mutedText, size: radius);
          },
        ),
      ),
    );
  }
}
