import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Models/Os/OsServiceModel.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_line_item_print_format.dart';

/// Shared preview table for invoice / quotation line items.
class OsLineItemsTable extends StatelessWidget {
  const OsLineItemsTable({
    super.key,
    required this.items,
    required this.fallbackAmount,
  });

  final List<OsLineItem> items;

  /// Used when [items] is empty (legacy lump-sum docs).
  final double fallbackAmount;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final List<OsServiceModel> catalog = Get.isRegistered<OsFinanceController>()
        ? Get.find<OsFinanceController>().services
        : const <OsServiceModel>[];
    final resolvedItems = OsLineItem.withResolvedMarketing(items, catalog);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(40),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1.4),
          4: FlexColumnWidth(1.4),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: theme.panelTint),
            children: [
              _th(theme, '#'),
              _th(theme, AppLocaleKeys.osInvoicesItemDesc.tr),
              _th(theme, AppLocaleKeys.osInvoicesQty.tr),
              _th(theme, AppLocaleKeys.osInvoicesUnitPrice.tr),
              _th(theme, AppLocaleKeys.osInvoicesLineTotal.tr),
            ],
          ),
          if (items.isEmpty)
            TableRow(
              children: [
                _td(theme, '1'),
                _td(theme, AppLocaleKeys.osInvoicesItemsFallback.tr),
                _td(theme, '1'),
                _td(theme, OsFinanceFormat.money(fallbackAmount)),
                _td(
                  theme,
                  OsFinanceFormat.money(fallbackAmount),
                  bold: true,
                ),
              ],
            )
          else
            for (var i = 0; i < resolvedItems.length; i++)
              TableRow(
                children: [
                  _td(theme, '${i + 1}'),
                  OsLineItemPrintFormat.descriptionCell(
                    theme,
                    resolvedItems[i],
                  ),
                  _td(theme, '${resolvedItems[i].quantity}'),
                  _td(
                    theme,
                    OsFinanceFormat.money(resolvedItems[i].unitPrice),
                  ),
                  _td(
                    theme,
                    OsFinanceFormat.money(resolvedItems[i].total),
                    bold: true,
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _th(AppThemeExtension theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: theme.secondaryText,
        ),
      ),
    );
  }

  Widget _td(AppThemeExtension theme, String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: theme.primaryText,
        ),
      ),
    );
  }
}
