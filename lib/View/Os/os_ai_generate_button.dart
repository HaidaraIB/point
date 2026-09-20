import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';

/// Shared indigo/purple accent for OS AI actions (matches [OsAiSuggestionBlock]).
abstract final class OsAiColors {
  static Color accentForeground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA);
  }

  static Color actionForeground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5);
  }
}

/// Inline “Generate” control for OS AI field actions.
class OsAiGenerateButton extends StatelessWidget {
  const OsAiGenerateButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.compact = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final actionColor = OsAiColors.actionForeground(context);
    final labelStyle = TextStyle(
      fontSize: compact ? 11 : 14,
      fontWeight: FontWeight.w800,
      color: actionColor,
    );

    return TextButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 6)
            : null,
        minimumSize: compact ? Size.zero : null,
        tapTargetSize:
            compact ? MaterialTapTargetSize.shrinkWrap : null,
        foregroundColor: actionColor,
      ),
      icon: isLoading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: actionColor,
              ),
            )
          : Icon(Icons.auto_awesome, size: compact ? 14 : 16, color: actionColor),
      label: Text(
        AppLocaleKeys.osAiGenerate.tr,
        style: labelStyle,
      ),
    );
  }
}
