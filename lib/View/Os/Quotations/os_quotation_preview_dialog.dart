import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Services/os_quote_template_settings.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Quotations/os_quotation_print.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_line_items_table.dart';

Future<void> showOsQuotationPreviewDialog(
  BuildContext context,
  OsQuotationModel quote, {
  VoidCallback? onApprove,
  VoidCallback? onReject,
}) async {
  final narrow = MediaQuery.sizeOf(context).width < 600;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _OsQuotationPreviewDialog(
      quote: quote,
      narrow: narrow,
      onApprove: onApprove,
      onReject: onReject,
    ),
  );
}

class _OsQuotationPreviewDialog extends StatelessWidget {
  const _OsQuotationPreviewDialog({
    required this.quote,
    required this.narrow,
    this.onApprove,
    this.onReject,
  });

  final OsQuotationModel quote;
  final bool narrow;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final size = MediaQuery.sizeOf(context);
    final ref = OsFinanceFormat.quotationRef(quote);
    final maxH = size.height * (narrow ? 0.92 : 0.88);
    final template = Get.isRegistered<OsQuoteTemplateController>()
        ? Get.find<OsQuoteTemplateController>()
        : null;
    final header = template?.headerText.value.trim().isNotEmpty == true
        ? template!.headerText.value
        : AppLocaleKeys.osQuotationsTemplateHeaderDefault.tr;
    final footer = template?.footerText.value.trim().isNotEmpty == true
        ? template!.footerText.value
        : AppLocaleKeys.osQuotationsTemplateFooterDefault.tr;
    final statusColor = OsFinanceFormat.quotationStatusColor(quote.status);
    final statusLabel = OsFinanceFormat.quotationStatusLabel(quote.status);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 28,
        vertical: narrow ? 16 : 28,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: maxH.clamp(280, size.height),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.request_quote_outlined,
                    color: theme.accentText,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocaleKeys.osQuotationsPreviewTitle.trParams({
                        'ref': ref,
                      }),
                      style: TextStyle(
                        fontSize: narrow ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => printOsQuotation(quote),
                    style: OsButtonStyles.secondaryCompact(theme),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: Text(AppLocaleKeys.osQuotationsPrint.tr),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.primaryText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand band
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.82),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'ن',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    AppLocaleKeys.osInvoicesAgencyHeader.tr,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: OsFinanceFormat
                                          .quotationStatusOnLight(quote.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              header,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              quote.clientName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocaleKeys.osQuotationsClient.tr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.panelTint,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: theme.border),
                              ),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 14,
                                children: [
                                  _metaTile(
                                    theme,
                                    AppLocaleKeys.osQuotationsNumber.tr,
                                    ref,
                                  ),
                                  _metaTile(
                                    theme,
                                    AppLocaleKeys.osQuotationsIssueDate.tr,
                                    quote.date,
                                  ),
                                  _metaTile(
                                    theme,
                                    AppLocaleKeys.osQuotationsExpires.tr,
                                    quote.expiryDate,
                                  ),
                                  _metaTile(
                                    theme,
                                    AppLocaleKeys.osQuotationsApprovalStatus.tr,
                                    statusLabel,
                                    valueColor: statusColor,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocaleKeys.osQuotationsItems.tr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OsLineItemsTable(
                              items: quote.items,
                              fallbackAmount: quote.amount > 0
                                  ? quote.amount
                                  : quote.total,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.panelTint,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: theme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${AppLocaleKeys.osInvoicesAmount.tr}: ${OsFinanceFormat.money(quote.amount > 0 ? quote.amount : quote.total)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.secondaryText,
                                    ),
                                  ),
                                  if (quote.discount > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${AppLocaleKeys.osInvoicesDiscount.tr}: ${OsFinanceFormat.money(quote.discount)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                  ],
                                  if (quote.vat > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${AppLocaleKeys.osInvoicesVat.tr}: ${OsFinanceFormat.money(quote.vat)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                  ],
                                  if ((quote.notes ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '${AppLocaleKeys.osInvoicesNotes.tr}: ${quote.notes!.trim()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.mutedText,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          AppLocaleKeys.osQuotationsTotal.tr,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: theme.secondaryText,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        OsFinanceFormat.money(quote.total),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: theme.accentText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.inputFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: theme.accentText,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      footer,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.55,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onApprove != null || onReject != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    if (onReject != null)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onReject!();
                          },
                          style: OsButtonStyles.inlineCaution(),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: Text(AppLocaleKeys.osQuotationsReject.tr),
                        ),
                      ),
                    if (onReject != null && onApprove != null)
                      const SizedBox(width: 10),
                    if (onApprove != null)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onApprove!();
                          },
                          style: OsButtonStyles.inlinePrimary(),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: Text(AppLocaleKeys.osQuotationsApprove.tr),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metaTile(
    AppThemeExtension theme,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.mutedText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: valueColor ?? theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
