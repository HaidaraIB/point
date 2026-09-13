import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/Mobile/OsInvoicesMobileScreen.dart';
import 'package:point/View/Os/Invoices/os_invoice_form_dialog.dart';
import 'package:point/View/Os/Invoices/os_invoice_preview_dialog.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_list_filters.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Os/os_stamp_settings_panel.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/app_data_table.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Os/os_form_dialog.dart';

class OsInvoicesPage extends StatelessWidget {
  const OsInvoicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessOsSection(emp)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    final finance = Get.find<OsFinanceController>();

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Obx(() {
        final list = finance.invoices.toList();
        return Responsive(
          mobile: OsInvoicesMobileScreen(
            invoices: list,
            onAdd: () => showOsInvoiceFormDialog(context),
            onEdit: (inv) {
              if (inv.isPaid) return;
              showOsInvoiceFormDialog(context, existing: inv);
            },
            onDelete: (inv) => _confirmDelete(context, finance, inv),
            onMarkPaid: (inv) => showOsMarkPaidDialog(context, inv),
            onStatusChange: (inv, status) =>
                _changeStatus(context, finance, inv, status),
            onPreview: (inv) => showOsInvoicePreviewDialog(context, inv),
            onPaymentLink: (inv) =>
                showOsInvoicePaymentLinkDialog(context, inv),
            onWhatsApp: shareOsInvoiceWhatsApp,
            onEmail: sendOsInvoiceEmail,
            onLinkAccount: (inv) {
              if (inv.isPaid) return;
              showOsInvoiceLinkAccountDialog(context, inv);
            },
          ),
          desktop: _DesktopInvoicesBody(
            invoices: list,
            onAdd: () => showOsInvoiceFormDialog(context),
            onEdit: (inv) {
              if (inv.isPaid) return;
              showOsInvoiceFormDialog(context, existing: inv);
            },
            onDelete: (inv) => _confirmDelete(context, finance, inv),
            onMarkPaid: (inv) => showOsMarkPaidDialog(context, inv),
            onStatusChange: (inv, status) =>
                _changeStatus(context, finance, inv, status),
            onPreview: (inv) => showOsInvoicePreviewDialog(context, inv),
            onPaymentLink: (inv) =>
                showOsInvoicePaymentLinkDialog(context, inv),
            onWhatsApp: shareOsInvoiceWhatsApp,
            onEmail: sendOsInvoiceEmail,
            onLinkAccount: (inv) {
              if (inv.isPaid) return;
              showOsInvoiceLinkAccountDialog(context, inv);
            },
          ),
        );
      }),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    OsFinanceController finance,
    OsInvoiceModel inv,
    String status,
  ) async {
    if (status == inv.status) return;

    // Selecting PAID → same mark-paid flow as the payments button (point_os).
    if (status == OsInvoiceStatus.paid) {
      if (inv.isPaid) return;
      await showOsMarkPaidDialog(context, inv);
      return;
    }

    if (!OsInvoiceStatus.editable.contains(status)) return;

    // Leaving PAID → debit collection account; keep receipt voucher (point_os).
    if (inv.isPaid) {
      try {
        final ok = await FunHelper.showConfirmDailog(
          context,
          title: AppLocaleKeys.osInvoicesStatus.tr,
          message: AppLocaleKeys.osInvoicesUnmarkConfirm.tr,
          confirmText: AppLocaleKeys.osCommonSave.tr,
          onTap: () async {
            try {
              final done = await finance.unmarkInvoicePaid(
                invoice: inv,
                newStatus: status,
              );
              if (!done) {
                OsSnackbar.error(
                  AppLocaleKeys.osInvoicesTitle.tr,
                  AppLocaleKeys.osCommonSaveFailed.tr,
                );
                throw Exception('unmark failed');
              }
            } on OsFinanceException catch (e) {
              OsSnackbar.error(
                AppLocaleKeys.osInvoicesTitle.tr,
                e.messageKey.tr,
              );
              rethrow;
            }
          },
        );
        if (ok == true) {
          OsSnackbar.success(
            AppLocaleKeys.osInvoicesTitle.tr,
            AppLocaleKeys.osInvoicesUnmarkSuccess.tr,
          );
        }
      } on OsFinanceException catch (e) {
        OsSnackbar.error(AppLocaleKeys.osInvoicesTitle.tr, e.messageKey.tr);
      }
      return;
    }

    await finance.saveInvoice(inv.copyWith(status: status));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OsFinanceController finance,
    OsInvoiceModel inv,
  ) async {
    if (inv.isPaid) return;
    await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: AppLocaleKeys.osInvoicesDeleteConfirm.tr,
      onTap: () async {
        if (inv.id != null) await finance.deleteInvoice(inv.id!);
      },
    );
  }
}

class _DesktopInvoicesBody extends StatefulWidget {
  const _DesktopInvoicesBody({
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

  @override
  State<_DesktopInvoicesBody> createState() => _DesktopInvoicesBodyState();
}

class _DesktopInvoicesBodyState extends State<_DesktopInvoicesBody> {
  var _showStampSettings = false;
  final _search = TextEditingController();
  var _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<OsInvoiceModel> _filtered(List<OsInvoiceModel> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((inv) {
      if (_status != 'ALL' && inv.status != _status) return false;
      if (q.isEmpty) return true;
      final ref = OsFinanceFormat.invoiceRef(inv).toLowerCase();
      return ref.contains(q) || inv.clientName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final invoices = widget.invoices;
    final filtered = _filtered(invoices);
    final paid = invoices.where((i) => i.isPaid).length;
    final overdue =
        invoices.where((i) => i.status == OsInvoiceStatus.overdue).length;
    final sent =
        invoices.where((i) => i.status == OsInvoiceStatus.sent).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OsPageHeader(
          title: AppLocaleKeys.osInvoicesTitle.tr,
          subtitle: AppLocaleKeys.osInvoicesSubtitle.tr,
          currentRoute: '/os/invoices',
          actions: [
            FilledButton.icon(
              onPressed: () =>
                  setState(() => _showStampSettings = !_showStampSettings),
              style: OsButtonStyles.secondaryCompact(
                theme,
                active: _showStampSettings,
              ),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(AppLocaleKeys.osInvoicesCustomizeStamp.tr),
            ),
            FilledButton.icon(
              onPressed: widget.onAdd,
              style: OsButtonStyles.primaryCompact(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppLocaleKeys.osInvoicesAdd.tr),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_showStampSettings) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.34,
                    ),
                    child: const SingleChildScrollView(
                      child: OsStampSettingsPanel(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    final cards = [
                      _StatCard(
                        label: AppLocaleKeys.osInvoicesTitle.tr,
                        value: '${invoices.length}',
                        selected: _status == 'ALL',
                        onTap: () => setState(() => _status = 'ALL'),
                      ),
                      _StatCard(
                        label: AppLocaleKeys.osInvoicesStatusPaid.tr,
                        value: '$paid',
                        selected: _status == OsInvoiceStatus.paid,
                        onTap: () =>
                            setState(() => _status = OsInvoiceStatus.paid),
                      ),
                      _StatCard(
                        label: AppLocaleKeys.osInvoicesStatusOverdue.tr,
                        value: '$overdue',
                        selected: _status == OsInvoiceStatus.overdue,
                        onTap: () => setState(
                          () => _status = OsInvoiceStatus.overdue,
                        ),
                      ),
                      _StatCard(
                        label: AppLocaleKeys.osInvoicesStatusSent.tr,
                        value: '$sent',
                        selected: _status == OsInvoiceStatus.sent,
                        onTap: () =>
                            setState(() => _status = OsInvoiceStatus.sent),
                      ),
                    ];
                    if (wide) {
                      return Row(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final c in cards)
                          SizedBox(
                            width: (constraints.maxWidth - 12) / 2,
                            child: c,
                          ),
                      ],
                    );
                  },
                ),
                OsListFilterBar(
                  chips: OsFilterChips(
                    value: _status,
                    onChanged: (v) => setState(() => _status = v),
                    options: [
                      OsFilterChipOption(
                        value: 'ALL',
                        label: AppLocaleKeys.osCommonFilterAll.tr,
                      ),
                      for (final s in OsInvoiceStatus.all)
                        OsFilterChipOption(
                          value: s,
                          label: OsFinanceFormat.invoiceStatusLabel(s),
                        ),
                    ],
                  ),
                  search: OsSearchField(
                    controller: _search,
                    hint: AppLocaleKeys.osInvoicesSearch.tr,
                    onChanged: (_) => setState(() {}),
                  ),
                  matchCount: invoices.isEmpty ? null : filtered.length,
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? OsEmptyState(
                          message: invoices.isEmpty
                              ? AppLocaleKeys.osInvoicesEmpty.tr
                              : AppLocaleKeys.osInvoicesEmptyFilter.tr,
                        )
                      : _InvoicesTable(
                          invoices: filtered,
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                          onMarkPaid: widget.onMarkPaid,
                          onStatusChange: widget.onStatusChange,
                          onPreview: widget.onPreview,
                          onPaymentLink: widget.onPaymentLink,
                          onWhatsApp: widget.onWhatsApp,
                          onEmail: widget.onEmail,
                          onLinkAccount: widget.onLinkAccount,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InvoicesTable extends StatelessWidget {
  const _InvoicesTable({
    required this.invoices,
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
  final ValueChanged<OsInvoiceModel> onEdit;
  final ValueChanged<OsInvoiceModel> onDelete;
  final ValueChanged<OsInvoiceModel> onMarkPaid;
  final void Function(OsInvoiceModel, String) onStatusChange;
  final ValueChanged<OsInvoiceModel> onPreview;
  final ValueChanged<OsInvoiceModel> onPaymentLink;
  final ValueChanged<OsInvoiceModel> onWhatsApp;
  final ValueChanged<OsInvoiceModel> onEmail;
  final ValueChanged<OsInvoiceModel> onLinkAccount;

  String _accountLabel(OsInvoiceModel inv) {
    final finance = Get.find<OsFinanceController>();
    final acc = finance.accountById(inv.bankAccountId);
    if (acc != null) return acc.name;
    return AppLocaleKeys.osInvoicesAccountUnset.tr;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return AppDataTable(
      minWidth: 1280,
      dataRowMinHeight: 72,
      dataRowMaxHeight: 88,
      columns: [
        appDataColumn(context, AppLocaleKeys.osInvoicesNumber.tr),
        appDataColumn(context, AppLocaleKeys.osInvoicesClient.tr),
        appDataColumn(context, AppLocaleKeys.osInvoicesCollectionAccount.tr),
        appDataColumn(context, AppLocaleKeys.osInvoicesTotal.tr),
        appDataColumn(context, AppLocaleKeys.osInvoicesStatus.tr),
        appDataColumn(
          context,
          AppLocaleKeys.osInvoicesActions.tr,
          width: 320,
        ),
      ],
      rows: [
        for (final inv in invoices)
          DataRow(
            cells: [
              appDataCell(
                Text(
                  OsFinanceFormat.invoiceRef(inv),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.accentText,
                  ),
                ),
              ),
              appDataCell(
                Text(
                  inv.clientName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.secondaryText,
                  ),
                ),
              ),
              appDataCell(
                InkWell(
                  onTap: inv.isPaid ? null : () => onLinkAccount(inv),
                  child: Text(
                    _accountLabel(inv),
                    style: TextStyle(
                      color: theme.secondaryText,
                      decoration: inv.isPaid
                          ? TextDecoration.none
                          : TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dashed,
                    ),
                  ),
                ),
              ),
              appDataCell(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      OsFinanceFormat.money(inv.total),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.accentText.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        osInvoiceItemsCountLabel(
                          inv.items.isEmpty ? 1 : inv.items.length,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.accentText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              appDataCell(
                DropdownButton<String>(
                  value: OsInvoiceStatus.all.contains(inv.status)
                      ? inv.status
                      : OsInvoiceStatus.sent,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.primaryText,
                  ),
                  items: [
                    for (final s in OsInvoiceStatus.all)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          OsFinanceFormat.invoiceStatusLabel(s),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) onStatusChange(inv, v);
                  },
                ),
              ),
              appDataCell(
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionIcon(
                      tooltip: AppLocaleKeys.osInvoicesPreview.trParams({
                        'ref': OsFinanceFormat.invoiceRef(inv),
                      }),
                      icon: Icons.visibility_outlined,
                      onPressed: () => onPreview(inv),
                    ),
                    if (!inv.isPaid)
                      _ActionIcon(
                        tooltip: AppLocaleKeys.osInvoicesMarkPaid.tr,
                        icon: Icons.payments_outlined,
                        onPressed: () => onMarkPaid(inv),
                      ),
                    _ActionIcon(
                      tooltip: AppLocaleKeys.osInvoicesPaymentLink.tr,
                      icon: Icons.link,
                      onPressed: () => onPaymentLink(inv),
                    ),
                    _ActionIcon(
                      tooltip: AppLocaleKeys.osInvoicesWhatsapp.tr,
                      icon: Icons.send_outlined,
                      onPressed: () => onWhatsApp(inv),
                    ),
                    _ActionIcon(
                      tooltip: AppLocaleKeys.osInvoicesEmail.tr,
                      icon: Icons.mail_outline,
                      onPressed: () => onEmail(inv),
                    ),
                    if (!inv.isPaid) ...[
                      _ActionIcon(
                        tooltip: AppLocaleKeys.osInvoicesEdit.tr,
                        icon: Icons.edit_outlined,
                        onPressed: () => onEdit(inv),
                      ),
                      _ActionIcon(
                        tooltip: AppLocaleKeys.osCommonDelete.tr,
                        icon: Icons.delete_outline,
                        color: Colors.redAccent,
                        onPressed: () => onDelete(inv),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Material(
      color: theme.cardSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? theme.accentBorder : theme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? theme.accentText : theme.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color),
    );
  }
}
