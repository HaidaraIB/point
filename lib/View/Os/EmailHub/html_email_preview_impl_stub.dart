import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Non-web fallback: scrollable raw HTML source (same payload as sent mail).
class HtmlEmailPreviewImpl extends StatelessWidget {
  const HtmlEmailPreviewImpl({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        html,
        style: TextStyle(
          fontSize: 11,
          height: 1.45,
          color: theme.secondaryText,
        ),
      ),
    );
  }
}
