import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/SentTranslationController.dart';
import 'package:point/Services/translation_service.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/translation_text.dart';

/// Payload attached to an outgoing message when live translation is active.
class SentTranslationPayload {
  const SentTranslationPayload({
    required this.translation,
    required this.targetLang,
    required this.sourceHash,
  });

  final String translation;
  final String targetLang;
  final String sourceHash;
}

/// Debounced live translation while the user types in the chat composer.
class ChatComposerLiveTranslationController {
  ChatComposerLiveTranslationController({required this.onChanged});

  final VoidCallback onChanged;

  static const _debounceMs = 650;

  Timer? _debounce;
  int _generation = 0;

  String? previewTranslation;
  String? previewSourceText;
  String? previewSourceLang;
  String? previewTargetLang;
  bool isLoading = false;

  bool get hasPreview =>
      previewTranslation != null &&
      previewTranslation!.trim().isNotEmpty &&
      previewSourceText != null &&
      previewSourceText!.trim().isNotEmpty;

  void onTextChanged(String text) {
    _debounce?.cancel();
    final targetLang = Get.find<SentTranslationController>().targetOrNull;
    final trimmed = text.trim();
    if (targetLang == null ||
        trimmed.isEmpty ||
        shouldSkipComposeTranslation(trimmed, targetLang)) {
      _clearPreview();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      unawaited(_fetch(trimmed, targetLang));
    });
  }

  /// Re-translate immediately when the target language changes.
  void onTargetChanged(String text) {
    _debounce?.cancel();
    _generation++;
    final targetLang = Get.find<SentTranslationController>().targetOrNull;
    final trimmed = text.trim();
    if (targetLang == null ||
        trimmed.isEmpty ||
        shouldSkipComposeTranslation(trimmed, targetLang)) {
      _clearPreview();
      return;
    }

    previewTranslation = null;
    previewSourceText = trimmed;
    previewSourceLang = detectLikelySourceLangCode(trimmed);
    previewTargetLang = targetLang;
    unawaited(_fetch(trimmed, targetLang));
  }

  Future<void> _fetch(String text, String targetLang) async {
    final gen = ++_generation;
    isLoading = true;
    onChanged();

    final result = await TranslationService.instance.translateComposeMessage(
      text,
      targetLang,
    );

    if (gen != _generation) return;
    isLoading = false;

    if (result == null || result.skip) {
      _clearPreview();
      return;
    }

    final translated = result.translation?.trim() ?? '';
    if (translated.isEmpty || translated == text.trim()) {
      _clearPreview();
      return;
    }

    previewTranslation = translated;
    previewSourceText = text;
    previewSourceLang = detectLikelySourceLangCode(text);
    previewTargetLang = targetLang;
    onChanged();
  }

  Future<SentTranslationPayload?> resolveForSend(String text) async {
    final targetLang = Get.find<SentTranslationController>().targetOrNull;
    final trimmed = text.trim();
    if (targetLang == null ||
        trimmed.isEmpty ||
        shouldSkipComposeTranslation(trimmed, targetLang)) {
      return null;
    }

    if (hasPreview &&
        previewSourceText == trimmed &&
        previewTargetLang == targetLang) {
      return SentTranslationPayload(
        translation: previewTranslation!.trim(),
        targetLang: targetLang,
        sourceHash: translationTextHash(trimmed),
      );
    }

    final result = await TranslationService.instance.translateComposeMessage(
      trimmed,
      targetLang,
    );
    if (result == null || result.skip) return null;
    final translated = result.translation?.trim() ?? '';
    if (translated.isEmpty || translated == trimmed) return null;
    return SentTranslationPayload(
      translation: translated,
      targetLang: targetLang,
      sourceHash: result.sourceHash,
    );
  }

  void clear() {
    _generation++;
    _debounce?.cancel();
    _clearPreview();
  }

  void dispose() {
    _debounce?.cancel();
  }

  void _clearPreview() {
    final hadState = hasPreview || isLoading;
    previewTranslation = null;
    previewSourceText = null;
    previewSourceLang = null;
    previewTargetLang = null;
    isLoading = false;
    if (hadState) onChanged();
  }
}

class ChatComposerTranslationPreview extends StatelessWidget {
  const ChatComposerTranslationPreview({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.only(bottom: 6),
  });

  final ChatComposerLiveTranslationController controller;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final stc = Get.find<SentTranslationController>();
    return Obx(() {
      stc.targetLanguage.value;
      if (!stc.isEnabled) return const SizedBox.shrink();
      if (!controller.hasPreview && !controller.isLoading) {
        return const SizedBox.shrink();
      }
      return _buildPreview(context);
    });
  }

  Widget _buildPreview(BuildContext context) {
    final theme = context.appTheme;
    final sourceLang = controller.previewSourceLang;
    final targetLang = controller.previewTargetLang;
    final chip = (sourceLang != null && targetLang != null)
        ? '${translationLangChipLabel(sourceLang)} ${translationLangChipLabel(targetLang)}'
        : '';
    final previewDirection = textDirectionForTranslation(
      controller.previewTranslation ?? '',
      langCode: targetLang,
    );

    return Padding(
      padding: padding,
      child: Directionality(
        textDirection: previewDirection,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: controller.isLoading && !controller.hasPreview
                  ? Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: theme.mutedText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocaleKeys.chatSentTranslationPreviewLoading.tr,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.mutedText,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      controller.previewTranslation ?? '',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.primaryText.withValues(alpha: 0.88),
                        height: 1.35,
                      ),
                    ),
            ),
            if (chip.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.mutedText,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

