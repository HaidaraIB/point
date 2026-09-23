import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/ContentLanguageController.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// First-time picker for chat translation target language.
Future<String?> showChatTranslationPreferenceDialog(BuildContext context) {
  final dialogWidth = Get.width > 900 ? 420.0 : Get.width * 0.82;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final theme = ctx.appTheme;
      final accent = theme.accentText;
      final muted = theme.mutedText;

      Widget languageButton(String code, String label) {
        return TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: accent,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          onPressed: () => Navigator.of(ctx).pop(code),
          child: Text(label),
        );
      }

      return AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate, color: accent, size: 40),
              const SizedBox(height: 10),
              Text(
                AppLocaleKeys.chatTranslationPickTitle.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleKeys.chatTranslationPickMessage.tr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: muted),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  languageButton(
                    'ar',
                    AppLocaleKeys.chatTranslationArabic.tr,
                  ),
                  Text('|', style: TextStyle(color: theme.border)),
                  languageButton(
                    'en',
                    AppLocaleKeys.chatTranslationEnglish.tr,
                  ),
                  Text('|', style: TextStyle(color: theme.border)),
                  languageButton(
                    'fa',
                    AppLocaleKeys.chatTranslationFarsi.tr,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Ensures a chat translation preference exists; returns the chosen code.
Future<String?> ensureChatTranslationPreference(BuildContext context) async {
  final clc = Get.find<ContentLanguageController>();
  final existing = clc.codeOrNull;
  if (existing != null) return existing;

  final picked = await showChatTranslationPreferenceDialog(context);
  if (picked == null || picked.isEmpty) return null;
  await clc.changeContentLanguage(picked);
  return picked;
}
