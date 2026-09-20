import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// KPI stat tile used across Point OS sub-pages (branches, contracts, expenses…).
class OsKpiCard extends StatelessWidget {
  const OsKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    this.subtitle,
    this.dense = false,
  });

  final String title;
  final String value;
  final Color color;
  final String? subtitle;

  /// Tighter layout for mobile horizontal KPI strips.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final pad = dense ? 10.0 : 14.0;
    final titleSize = dense ? 10.0 : 11.0;
    final valueSize = dense ? 17.0 : 20.0;
    final subtitleSize = dense ? 9.0 : 10.0;

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(dense ? 14 : 16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: dense ? 2 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: titleSize,
              height: dense ? 1.2 : null,
              fontWeight: FontWeight.w700,
              color: theme.mutedText,
            ),
          ),
          SizedBox(height: dense ? 3 : 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            SizedBox(height: dense ? 1 : 2),
            Text(
              subtitle!,
              maxLines: dense ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: subtitleSize, color: theme.mutedText),
            ),
          ],
        ],
      ),
    );
  }
}
