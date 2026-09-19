import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';

import 'html_email_preview_impl.dart';

/// Renders the exact HTML that will be sent via email.
class HtmlEmailPreview extends StatelessWidget {
  const HtmlEmailPreview({
    super.key,
    required this.html,
    this.minHeight = 420,
  });

  final String html;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    if (html.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: theme.accentText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleKeys.osEmailHubPreviewTitle.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.panelTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  AppLocaleKeys.osEmailHubPreviewBadge.tr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.mutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight),
              decoration: BoxDecoration(
                color: theme.panelTint,
                border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: HtmlEmailPreviewImpl(html: html),
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 8),
            Text(
              AppLocaleKeys.emailTemplatePreviewMobileHint.tr,
              style: TextStyle(fontSize: 11, color: theme.mutedText),
            ),
          ],
        ],
      ),
    );
  }
}
