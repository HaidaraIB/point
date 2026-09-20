import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_ai_generate_button.dart';

/// Indigo AI suggestion panel used on OS service cards (point_os parity).
class OsAiSuggestionBlock extends StatelessWidget {
  const OsAiSuggestionBlock({
    super.key,
    required this.description,
    required this.isLoading,
    required this.isDisabled,
    required this.onGenerate,
    this.title,
    this.placeholder,
    this.expandToFill = false,
    this.maxDescriptionLines = 4,
  });

  final String description;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onGenerate;
  final String? title;
  final String? placeholder;
  final bool expandToFill;
  final int maxDescriptionLines;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDescription = description.trim().isNotEmpty;
    final displayText = hasDescription
        ? description
        : (placeholder ?? AppLocaleKeys.osAiSuggestionPlaceholder.tr);
    final aiAccent = OsAiColors.accentForeground(context);

    final descriptionText = Text(
      displayText,
      maxLines: maxDescriptionLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        height: 1.45,
        fontStyle: hasDescription ? FontStyle.italic : FontStyle.normal,
        color: hasDescription ? theme.secondaryText : theme.mutedText,
      ),
    );

    return Container(
      width: double.infinity,
      height: expandToFill ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF).withValues(
          alpha: isDark ? 0.18 : 0.55,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC7D2FE).withValues(
            alpha: isDark ? 0.35 : 0.45,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: expandToFill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: aiAccent,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title ?? AppLocaleKeys.osAiSuggestionTitle.tr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: aiAccent,
                  ),
                ),
              ),
              OsAiGenerateButton(
                compact: true,
                isLoading: isLoading,
                onPressed: isDisabled ? null : onGenerate,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (expandToFill)
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: descriptionText,
              ),
            )
          else
            descriptionText,
        ],
      ),
    );
  }
}
