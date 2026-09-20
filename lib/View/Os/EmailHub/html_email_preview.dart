import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/EmailHub/Mobile/os_email_hub_mobile_layout.dart';
import 'package:point/View/Shared/responsive.dart';

import 'html_email_preview_impl.dart';

/// Full-screen preview dialog (native mobile launcher).
Future<void> showHtmlEmailPreviewDialog(
  BuildContext context, {
  required String html,
}) {
  if (html.trim().isEmpty) return Future.value();
  final size = MediaQuery.sizeOf(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      backgroundColor: ctx.appTheme.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 20,
                    color: ctx.appTheme.accentText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocaleKeys.osEmailHubPreviewTitle.tr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ctx.appTheme.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: ctx.appTheme.primaryText),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: ctx.appTheme.panelTint,
                    child: HtmlEmailPreviewImpl(html: html),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Collapsed preview card with open button (native mobile).
class OsEmailHubPreviewLauncher extends StatelessWidget {
  const OsEmailHubPreviewLauncher({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final ready = html.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleKeys.emailTemplatePreviewMobileHint.tr,
            style: TextStyle(fontSize: 12, color: theme.mutedText, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: ready
                  ? () => showHtmlEmailPreviewDialog(context, html: html)
                  : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(AppLocaleKeys.osEmailHubPreviewOnly.tr),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline preview or collapsed launcher depending on platform/width.
Widget osEmailHubHtmlPreviewWidget(
  BuildContext context,
  String html, {
  Key? key,
}) {
  if (html.trim().isEmpty) return const SizedBox.shrink();
  if (osEmailHubCollapsePreview(context)) {
    return OsEmailHubPreviewLauncher(key: key, html: html);
  }
  return HtmlEmailPreview(key: key, html: html);
}

/// Renders the exact HTML that will be sent via email.
class HtmlEmailPreview extends StatelessWidget {
  const HtmlEmailPreview({
    super.key,
    required this.html,
    this.minHeight = 420,
    this.embedded = false,
  });

  final String html;
  final double minHeight;

  /// When true, renders only the WebView/iframe surface (no duplicate chrome).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    if (html.trim().isEmpty) return const SizedBox.shrink();

    final previewMinHeight =
        Responsive.isMobile(context) && !kIsWeb ? 320.0 : minHeight;

    final surface = LayoutBuilder(
      builder: (context, constraints) {
        double height = previewMinHeight;
        if (embedded &&
            constraints.maxHeight.isFinite &&
            constraints.maxHeight > 0) {
          height = constraints.maxHeight;
        }
        return SizedBox(
          height: height,
          width: double.infinity,
          child: HtmlEmailPreviewImpl(html: html),
        );
      },
    );

    if (embedded) {
      return surface;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
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
            child: ColoredBox(
              color: theme.panelTint,
              child: surface,
            ),
          ),
        ],
      ),
    );
  }
}
