import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/os_invoice_print.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_invoice_stamp.dart';

Future<void> showOsInvoicePreviewDialog(
  BuildContext context,
  OsInvoiceModel invoice,
) async {
  final narrow = MediaQuery.sizeOf(context).width < 600;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _OsInvoicePreviewDialog(
      invoice: invoice,
      narrow: narrow,
    ),
  );
}

class _OsInvoicePreviewDialog extends StatelessWidget {
  const _OsInvoicePreviewDialog({
    required this.invoice,
    required this.narrow,
  });

  final OsInvoiceModel invoice;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final size = MediaQuery.sizeOf(context);
    final ref = OsFinanceFormat.invoiceRef(invoice);
    final maxH = size.height * (narrow ? 0.92 : 0.88);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 28,
        vertical: narrow ? 16 : 28,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
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
                  Icon(Icons.description_outlined,
                      color: theme.accentText, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleKeys.osInvoicesPreview.trParams({
                            'ref': ref,
                          }),
                          style: TextStyle(
                            fontSize: narrow ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocaleKeys.osInvoicesPreviewSubtitle.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => printOsInvoice(invoice),
                    style: OsButtonStyles.secondaryCompact(theme),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: Text(AppLocaleKeys.osInvoicesPrint.tr),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.primaryText),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _metaGrid(theme),
                    const SizedBox(height: 16),
                    Text(
                      AppLocaleKeys.osInvoicesItems.tr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _itemsTable(theme),
                    const SizedBox(height: 16),
                    _totalsRow(theme),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _actionBtn(
                          label: AppLocaleKeys.osInvoicesEmail.tr,
                          icon: Icons.mail_outline,
                          color: theme.primaryText,
                          fg: theme.pageBackground,
                          onTap: () => sendOsInvoiceEmail(invoice),
                        ),
                        const SizedBox(height: 8),
                        _actionBtn(
                          label: AppLocaleKeys.osInvoicesPaymentLink.tr,
                          icon: Icons.link,
                          color: AppColors.primary,
                          fg: Colors.white,
                          onTap: () =>
                              showOsInvoicePaymentLinkDialog(context, invoice),
                        ),
                        const SizedBox(height: 8),
                        _actionBtn(
                          label: AppLocaleKeys.osInvoicesWhatsapp.tr,
                          icon: Icons.send_outlined,
                          color: const Color(0xFF059669),
                          fg: Colors.white,
                          onTap: () => shareOsInvoiceWhatsApp(invoice),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocaleKeys.osCommonClose.tr),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _actionBtn(
                            label: AppLocaleKeys.osInvoicesEmail.tr,
                            icon: Icons.mail_outline,
                            color: theme.primaryText,
                            fg: theme.pageBackground,
                            onTap: () => sendOsInvoiceEmail(invoice),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionBtn(
                            label: AppLocaleKeys.osInvoicesPaymentLink.tr,
                            icon: Icons.link,
                            color: AppColors.primary,
                            fg: Colors.white,
                            onTap: () => showOsInvoicePaymentLinkDialog(
                              context,
                              invoice,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionBtn(
                            label: AppLocaleKeys.osInvoicesWhatsapp.tr,
                            icon: Icons.send_outlined,
                            color: const Color(0xFF059669),
                            fg: Colors.white,
                            onTap: () => shareOsInvoiceWhatsApp(invoice),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocaleKeys.osCommonClose.tr),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaGrid(AppThemeExtension theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.panelTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _metaCell(
            theme,
            AppLocaleKeys.osInvoicesClient.tr,
            invoice.clientName,
          ),
          _metaCell(
            theme,
            AppLocaleKeys.osInvoicesDate.tr,
            invoice.date,
          ),
          _metaCell(
            theme,
            AppLocaleKeys.osInvoicesDueDate.tr,
            invoice.dueDate,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocaleKeys.osInvoicesStatus.tr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.mutedText,
                ),
              ),
              const SizedBox(height: 4),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  OsFinanceFormat.invoiceStatusLabel(invoice.status),
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: OsFinanceFormat.invoiceStatusColor(
                  invoice.status,
                ).withValues(alpha: 0.15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaCell(AppThemeExtension theme, String label, String value) {
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
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsTable(AppThemeExtension theme) {
    final items = invoice.items;
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
                _td(
                  theme,
                  OsFinanceFormat.money(
                    invoice.amount > 0 ? invoice.amount : invoice.total,
                  ),
                ),
                _td(
                  theme,
                  OsFinanceFormat.money(
                    invoice.amount > 0 ? invoice.amount : invoice.total,
                  ),
                  bold: true,
                ),
              ],
            )
          else
            for (var i = 0; i < items.length; i++)
              TableRow(
                children: [
                  _td(theme, '${i + 1}'),
                  _td(theme, items[i].description),
                  _td(theme, '${items[i].quantity}'),
                  _td(theme, OsFinanceFormat.money(items[i].unitPrice)),
                  _td(
                    theme,
                    OsFinanceFormat.money(items[i].total),
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

  Widget _totalsRow(AppThemeExtension theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.panelTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppLocaleKeys.osInvoicesAmount.tr}: ${OsFinanceFormat.money(invoice.amount)}',
                  style: TextStyle(fontSize: 13, color: theme.secondaryText),
                ),
                if (invoice.vat > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${AppLocaleKeys.osInvoicesVat.tr}: ${OsFinanceFormat.money(invoice.vat)}',
                    style: TextStyle(fontSize: 13, color: theme.secondaryText),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${AppLocaleKeys.osInvoicesTotal.tr}: ${OsFinanceFormat.money(invoice.total)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: theme.accentText,
                  ),
                ),
              ],
            ),
          ),
          const OsInvoiceStamp(),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
