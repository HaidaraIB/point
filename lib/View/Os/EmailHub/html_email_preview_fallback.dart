import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Bounded fallback when WebView cannot start (plugin/channel or first launch).
class HtmlEmailPreviewFallback extends StatelessWidget {
  const HtmlEmailPreviewFallback({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Text(
            AppLocaleKeys.emailTemplatePreviewMobileHint.tr,
            style: TextStyle(fontSize: 12, color: theme.mutedText, height: 1.35),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              html,
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: theme.secondaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
