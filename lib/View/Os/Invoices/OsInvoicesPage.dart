import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/Mobile/OsInvoicesMobileScreen.dart';
import 'package:point/View/Os/Invoices/os_invoice_form_dialog.dart';
import 'package:point/View/Os/Invoices/os_invoice_preview_dialog.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Os/os_stamp_settings_panel.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/responsive.dart';

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
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocaleKeys.osInvoicesStatus.tr),
          content: Text(AppLocaleKeys.osInvoicesUnmarkConfirm.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocaleKeys.osCommonCancel.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocaleKeys.osCommonSave.tr),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        final done = await finance.unmarkInvoicePaid(
          invoice: inv,
          newStatus: status,
        );
        if (done) {
          OsSnackbar.success(
            AppLocaleKeys.osInvoicesTitle.tr,
            AppLocaleKeys.osInvoicesUnmarkSuccess.tr,
          );
        } else {
          OsSnackbar.error(
            AppLocaleKeys.osInvoicesTitle.tr,
            AppLocaleKeys.osCommonSaveFailed.tr,
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocaleKeys.osCommonDelete.tr),
        content: Text(AppLocaleKeys.osInvoicesDeleteConfirm.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocaleKeys.osCommonCancel.tr),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocaleKeys.osCommonDelete.tr),
          ),
        ],
      ),
    );
    if (ok == true && inv.id != null) {
      await finance.deleteInvoice(inv.id!);
    }
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
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  /// Wide enough for all columns + action icons so content scrolls, not clips.
  static const _tableMinWidth = 1280.0;

  static const _headerBtnPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 14);
  static const _headerBtnMinSize = Size(48, 48);
  static const _headerBtnTextStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final invoices = widget.invoices;
    final paid = invoices.where((i) => i.isPaid).length;
    final overdue =
        invoices.where((i) => i.status == OsInvoiceStatus.overdue).length;
    final sent =
        invoices.where((i) => i.status == OsInvoiceStatus.sent).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osInvoicesTitle.tr,
            subtitle: AppLocaleKeys.osInvoicesSubtitle.tr,
            currentRoute: '/os/invoices',
            actions: [
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _showStampSettings = !_showStampSettings),
                style: OutlinedButton.styleFrom(
                  minimumSize: _headerBtnMinSize,
                  padding: _headerBtnPadding,
                  textStyle: _headerBtnTextStyle,
                  visualDensity: VisualDensity.standard,
                  side: BorderSide(color: theme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  Icons.tune,
                  size: 20,
                  color: _showStampSettings
                      ? AppColors.primary
                      : theme.primaryText,
                ),
                label: Text(
                  AppLocaleKeys.osInvoicesCustomizeStamp.tr,
                  style: TextStyle(
                    color: _showStampSettings
                        ? AppColors.primary
                        : theme.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: widget.onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: _headerBtnMinSize,
                  padding: _headerBtnPadding,
                  textStyle: _headerBtnTextStyle,
                  visualDensity: VisualDensity.standard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, size: 22),
                label: Text(AppLocaleKeys.osInvoicesAdd.tr),
              ),
            ],
          ),
          if (_showStampSettings) ...[
            const SizedBox(height: 12),
            const OsStampSettingsPanel(),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final cards = [
                _StatCard(
                  label: AppLocaleKeys.osInvoicesTitle.tr,
                  value: '${invoices.length}',
                ),
                _StatCard(
                  label: AppLocaleKeys.osInvoicesStatusPaid.tr,
                  value: '$paid',
                ),
                _StatCard(
                  label: AppLocaleKeys.osInvoicesStatusOverdue.tr,
                  value: '$overdue',
                ),
                _StatCard(
                  label: AppLocaleKeys.osInvoicesStatusSent.tr,
                  value: '$sent',
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
          const SizedBox(height: 16),
          Expanded(
            child: invoices.isEmpty
                ? Center(
                    child: Text(
                      AppLocaleKeys.osInvoicesEmpty.tr,
                      style: TextStyle(
                        fontSize: 18,
                        color: theme.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = constraints.maxWidth < _tableMinWidth
                          ? _tableMinWidth
                          : constraints.maxWidth;
                      return ClipRect(
                        child: Scrollbar(
                          controller: _hScroll,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: SingleChildScrollView(
                            controller: _hScroll,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              height: constraints.maxHeight,
                              child: Scrollbar(
                                controller: _vScroll,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _vScroll,
                                  child: _InvoicesTable(
                                    invoices: invoices,
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
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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

  Widget _cell(
    BuildContext context,
    Widget child, {
    bool header = false,
  }) {
    final theme = context.appTheme;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: header
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.border),
              ),
            )
          : null,
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: header ? 14 : 15,
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
          color: header ? theme.secondaryText : theme.primaryText,
        ),
        textAlign: TextAlign.center,
        child: child,
      ),
    );
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
    // Fixed widths so the table keeps a real min width and scrolls horizontally
    // instead of crushing the actions column off-screen.
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(120),
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(1.5),
        3: FixedColumnWidth(160),
        4: FixedColumnWidth(130),
        // 7× compact IconButtons (~40px) + padding — keep ≥280 to avoid paint overflow.
        5: FixedColumnWidth(320),
      },
      children: [
        TableRow(
          children: [
            _cell(context, Text(AppLocaleKeys.osInvoicesNumber.tr),
                header: true),
            _cell(context, Text(AppLocaleKeys.osInvoicesClient.tr),
                header: true),
            _cell(
              context,
              Text(AppLocaleKeys.osInvoicesCollectionAccount.tr),
              header: true,
            ),
            _cell(context, Text(AppLocaleKeys.osInvoicesTotal.tr), header: true),
            _cell(context, Text(AppLocaleKeys.osInvoicesStatus.tr),
                header: true),
            _cell(context, Text(AppLocaleKeys.osInvoicesActions.tr),
                header: true),
          ],
        ),
        for (final inv in invoices)
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.border.withValues(alpha: 0.6)),
              ),
            ),
            children: [
              _cell(
                context,
                Text(
                  OsFinanceFormat.invoiceRef(inv),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.accentText,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              _cell(
                context,
                Text(
                  inv.clientName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _cell(
                context,
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
              _cell(
                context,
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      OsFinanceFormat.money(inv.total),
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
              _cell(
                context,
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
              _cell(
                context,
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
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: theme.mutedText,
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
