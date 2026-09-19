import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/Mobile/OsInvoiceFormMobilePage.dart';
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
            for (final inv in invoices) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                OsFinanceFormat.invoiceRef(inv),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: theme.accentText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                inv.clientName,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: theme.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OsFinanceStatusBadge(
                          label: OsFinanceFormat.invoiceStatusLabel(inv.status),
                          color: OsFinanceFormat.invoiceStatusColor(inv.status),
                          fontSize: 12,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      OsFinanceFormat.money(inv.total),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.accentText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      osInvoiceItemsCountLabel(
                        inv.items.isEmpty ? 1 : inv.items.length,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.accentText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocaleKeys.osInvoicesDateRange.trParams({
                        'from': inv.date,
                        'to': inv.dueDate,
                      }),
                      style: TextStyle(fontSize: 13, color: theme.mutedText),
                    ),
                    InkWell(
                      onTap: inv.isPaid ? null : () => onLinkAccount(inv),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${AppLocaleKeys.osInvoicesCollectionAccount.tr}: ${_accountLabel(inv)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.secondaryText,
                            decoration: inv.isPaid
                                ? TextDecoration.none
                                : TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dashed,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        IconButton(
                          tooltip: AppLocaleKeys.osInvoicesPreview.trParams({
                            'ref': OsFinanceFormat.invoiceRef(inv),
                          }),
                          onPressed: () => onPreview(inv),
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                        if (!inv.isPaid)
                          IconButton(
                            tooltip: AppLocaleKeys.osInvoicesPaymentLink.tr,
                            onPressed: () => onPaymentLink(inv),
                            icon: const Icon(Icons.link),
                          ),
                        if (!inv.isPaid)
                          IconButton(
                            tooltip: AppLocaleKeys.osInvoicesWhatsapp.tr,
                            onPressed: () => onWhatsApp(inv),
                            icon: const Icon(Icons.send_outlined),
                          ),
                        IconButton(
                          tooltip: AppLocaleKeys.osInvoicesEmail.tr,
                          onPressed: () => onEmail(inv),
                          icon: const Icon(Icons.mail_outline),
                        ),
                      ],
                    ),
                    if (!inv.isPaid) ...[
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => onMarkPaid(inv),
                            child: Text(
                              AppLocaleKeys.osInvoicesMarkPaid.tr,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _openEdit(context, inv),
                            child: Text(
                              AppLocaleKeys.osInvoicesEdit.tr,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (OsPermissions.canDeleteCurrentOsRecords)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: IconButton(
                          onPressed: () => onDelete(inv),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: OsInvoiceStatus.all.contains(inv.status)
                          ? inv.status
                          : OsInvoiceStatus.sent,
                      selectedItemBuilder: (context) =>
                          osInvoiceStatusSelectedItems(),
                      items: osInvoiceStatusDropdownItems(),
                      onChanged: (v) {
                        if (v != null) onStatusChange(inv, v);
                      },
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
