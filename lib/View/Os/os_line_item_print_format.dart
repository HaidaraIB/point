import 'package:flutter/material.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_print_a4.dart';

/// Shared formatting for line-item description + optional service marketing copy.
class OsLineItemPrintFormat {
  OsLineItemPrintFormat._();

  static String? marketingText(OsLineItem item) =>
      item.effectiveMarketingDescription;

  static String plainDescription(OsLineItem item) {
    final marketing = marketingText(item);
    if (marketing == null) return item.description;
    return '${item.description}\n$marketing';
  }

  static String descHtml(OsLineItem item) {
    final title = escapeHtml(item.description);
    final marketing = marketingText(item);
    if (marketing == null || marketing.isEmpty) {
      return '<td class="desc">$title</td>';
    }
    return '<td class="desc">'
        '<div class="item-title">$title</div>'
        '<div class="item-marketing">${escapeHtml(marketing)}</div>'
        '</td>';
  }

  static String itemMarketingCss() => '''
table.items td.desc {
  text-align: right;
  vertical-align: top;
}
table.items .item-title {
  font-weight: 700;
  line-height: 1.35;
}
table.items .item-marketing {
  margin-top: 3px;
  font-size: 8.5px;
  font-weight: 500;
  font-style: italic;
  line-height: 1.4;
  color: var(--muted);
}
''';

  static Widget descriptionCell(
    AppThemeExtension theme,
    OsLineItem item, {
    bool bold = false,
  }) {
    final marketing = marketingText(item);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.description,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
          if (marketing != null) ...[
            const SizedBox(height: 4),
            Text(
              marketing,
              style: TextStyle(
                fontSize: 10,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: theme.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
