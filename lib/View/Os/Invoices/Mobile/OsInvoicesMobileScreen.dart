import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/Mobile/OsInvoiceFormMobilePage.dart';
import 'package:point/View/Os/Invoices/os_invoice_pdf_download_action.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_finance_status_widgets.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/responsive.dart';

class OsInvoicesMobileScreen extends StatelessWidget {
  const OsInvoicesMobileScreen({
    super.key,
    required this.invoices,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkPaid,
    required this.onStatusChange,
    required this.onPreview,
    required this.onPaymentLink,
    required this.onWhatsApp,
    required this.onEmail,
    required this.onLinkAccount,
  });

  final List<OsInvoiceModel> invoices;
  final VoidCallback onAdd;
  final ValueChanged<OsInvoiceModel> onEdit;
  final ValueChanged<OsInvoiceModel> onDelete;
  final ValueChanged<OsInvoiceModel> onMarkPaid;
  final void Function(OsInvoiceModel, String) onStatusChange;
  final ValueChanged<OsInvoiceModel> onPreview;
  final ValueChanged<OsInvoiceModel> onPaymentLink;
  final ValueChanged<OsInvoiceModel> onWhatsApp;
  final ValueChanged<OsInvoiceModel> onEmail;
  final ValueChanged<OsInvoiceModel> onLinkAccount;

  Future<void> _openAdd(BuildContext context) async {
    if (Responsive.isDesktop(context)) {
      onAdd();
      return;
    }
    await Get.to(() => const OsInvoiceFormMobilePage());
  }

  Future<void> _openEdit(BuildContext context, OsInvoiceModel inv) async {
    if (Responsive.isDesktop(context)) {
      onEdit(inv);
      return;
    }
    await Get.to(() => OsInvoiceFormMobilePage(existing: inv));
  }

  String _accountLabel(OsInvoiceModel inv) {
    final finance = Get.find<OsFinanceController>();
    final acc = finance.accountById(inv.bankAccountId);
    if (acc != null) return acc.name;
    return AppLocaleKeys.osInvoicesAccountUnset.tr;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return RefreshIndicator(
      onRefresh: () async =>
          Future<void>.delayed(const Duration(milliseconds: 400)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osInvoicesTitle.tr,
            currentRoute: '/os/invoices',
            actions: [
              FilledButton.icon(
                onPressed: () => _openAdd(context),
                style: OsButtonStyles.primaryCompact(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocaleKeys.osInvoicesAdd.tr),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  AppLocaleKeys.osInvoicesEmpty.tr,
                  style: TextStyle(fontSize: 17, color: theme.mutedText),
                ),
              ),
            )
          else
            for (final inv in invoices)
              _OsInvoiceMobileCard(
                inv: inv,
                theme: theme,
                accountLabel: _accountLabel(inv),
                onPreview: () => onPreview(inv),
                onPaymentLink: () => onPaymentLink(inv),
                onWhatsApp: () => onWhatsApp(inv),
                onEmail: () => onEmail(inv),
                onLinkAccount: () => onLinkAccount(inv),
                onMarkPaid: () => onMarkPaid(inv),
                onEdit: () => _openEdit(context, inv),
                onDelete: () => onDelete(inv),
                onStatusChange: (s) => onStatusChange(inv, s),
              ),
        ],
      ),
    );
  }
}

class _OsInvoiceMobileCard extends StatelessWidget {
  const _OsInvoiceMobileCard({
    required this.inv,
    required this.theme,
    required this.accountLabel,
    required this.onPreview,
    required this.onPaymentLink,
    required this.onWhatsApp,
    required this.onEmail,
    required this.onLinkAccount,
    required this.onMarkPaid,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  final OsInvoiceModel inv;
  final AppThemeExtension theme;
  final String accountLabel;
  final VoidCallback onPreview;
  final VoidCallback onPaymentLink;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;
  final VoidCallback onLinkAccount;
  final VoidCallback onMarkPaid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChange;

  @override
  Widget build(BuildContext context) {
    final statusColor = OsFinanceFormat.invoiceStatusColor(inv.status);
    final itemCount = inv.items.isEmpty ? 1 : inv.items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  OsFinanceFormat.invoiceRef(inv),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.accentText,
                  ),
                ),
              ),
              OsFinanceStatusBadge(
                label: OsFinanceFormat.invoiceStatusLabel(inv.status),
                color: statusColor,
                fontSize: 12,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inv.clientName,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            OsFinanceFormat.money(inv.total),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: theme.accentText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${osInvoiceItemsCountLabel(itemCount)} · '
            '${AppLocaleKeys.osInvoicesDateRange.trParams({
              'from': inv.date,
              'to': inv.dueDate,
            })}',
            style: TextStyle(fontSize: 12, color: theme.mutedText),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: inv.isPaid ? null : onLinkAccount,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${AppLocaleKeys.osInvoicesCollectionAccount.tr}: $accountLabel',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.secondaryText,
                  decoration: inv.isPaid ? null : TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dashed,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _InvoiceIconAction(
                tooltip: AppLocaleKeys.osInvoicesPreview.trParams({
                  'ref': OsFinanceFormat.invoiceRef(inv),
                }),
                icon: Icons.visibility_outlined,
                onPressed: onPreview,
              ),
              _InvoiceIconAction(
                tooltip: AppLocaleKeys.osInvoicesEmail.tr,
                icon: Icons.mail_outline,
                onPressed: onEmail,
              ),
              OsInvoicePdfDownloadIconButton(
                invoice: inv,
                iconSize: 22,
                constraints: const BoxConstraints(),
              ),
              if (!inv.isPaid) ...[
                _InvoiceIconAction(
                  tooltip: AppLocaleKeys.osInvoicesWhatsapp.tr,
                  icon: Icons.send_outlined,
                  onPressed: onWhatsApp,
                ),
                _InvoiceIconAction(
                  tooltip: AppLocaleKeys.osInvoicesPaymentLink.tr,
                  icon: Icons.link,
                  onPressed: onPaymentLink,
                ),
              ],
            ],
          ),
          if (!inv.isPaid) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onMarkPaid,
                    child: Text(
                      AppLocaleKeys.osInvoicesMarkPaid.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onEdit,
                    style: OsButtonStyles.primaryCompact(),
                    child: Text(
                      AppLocaleKeys.osInvoicesEdit.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: OsInvoiceStatus.all.contains(inv.status)
                      ? inv.status
                      : OsInvoiceStatus.sent,
                  selectedItemBuilder: (context) =>
                      osInvoiceStatusSelectedItems(),
                  items: osInvoiceStatusDropdownItems(),
                  onChanged: (v) {
                    if (v != null) onStatusChange(v);
                  },
                ),
              ),
              if (OsPermissions.canDeleteCurrentOsRecords) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: AppLocaleKeys.osCommonDelete.tr,
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceIconAction extends StatelessWidget {
  const _InvoiceIconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 22),
    );
  }
}
