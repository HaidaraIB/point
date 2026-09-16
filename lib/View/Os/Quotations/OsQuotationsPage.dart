import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/os_quote_template_settings.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/os_invoice_form_dialog.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/Quotations/os_quotation_form_dialog.dart';
import 'package:point/View/Os/Quotations/os_quotation_preview_dialog.dart';
import 'package:point/View/Os/Quotations/os_quotation_share.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

class OsQuotationsPage extends StatefulWidget {
  const OsQuotationsPage({super.key});

  @override
  State<OsQuotationsPage> createState() => _OsQuotationsPageState();
}

class _OsQuotationsPageState extends State<OsQuotationsPage> {
  var _customizingTemplate = false;
  String? _copiedId;

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessOsSection(emp)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    final finance = Get.find<OsFinanceController>();
    final theme = context.appTheme;

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osQuotationsTitle.tr,
            subtitle: AppLocaleKeys.osQuotationsSubtitle.tr,
            currentRoute: '/os/quotations',
            actions: [
              FilledButton.icon(
                onPressed: () => setState(
                  () => _customizingTemplate = !_customizingTemplate,
                ),
                style: OsButtonStyles.secondaryCompact(
                  theme,
                  active: _customizingTemplate,
                ),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(AppLocaleKeys.osQuotationsCustomizeTemplate.tr),
              ),
              FilledButton.icon(
                onPressed: () => showOsQuotationFormDialog(context),
                style: OsButtonStyles.primaryCompact(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocaleKeys.osQuotationsAdd.tr),
              ),
            ],
          ),
          Expanded(
            child: Obx(() {
              final list = finance.quotations.toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_customizingTemplate) ...[
                    _TemplatePanel(
                      onClose: () =>
                          setState(() => _customizingTemplate = false),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Text(
                            AppLocaleKeys.osQuotationsEmpty.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.mutedText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                showOsQuotationFormDialog(context),
                            style: OsButtonStyles.primaryCompact(),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(AppLocaleKeys.osQuotationsAdd.tr),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final quote in list) ...[
                      _QuoteCard(
                        quote: quote,
                        copied: _copiedId == quote.id,
                        onApprove: () => _confirmApprove(
                          context,
                          finance,
                          quote,
                        ),
                        onReject: () => _confirmReject(
                          context,
                          finance,
                          quote,
                        ),
                        onReopen: () => _confirmReopen(
                          context,
                          finance,
                          quote,
                        ),
                        onCopyLink: () => _copyLink(quote),
                        onPreview: () => showOsQuotationPreviewDialog(
                          context,
                          quote,
                          onApprove: quote.status == OsQuotationStatus.sent
                              ? () => _confirmApprove(
                                    context,
                                    finance,
                                    quote,
                                  )
                              : null,
                          onReject: quote.status == OsQuotationStatus.sent
                              ? () => _confirmReject(
                                    context,
                                    finance,
                                    quote,
                                  )
                              : null,
                        ),
                        onEdit: () => showOsQuotationFormDialog(
                          context,
                          existing: quote,
                        ),
                        onConvertToInvoice: quote.status ==
                                OsQuotationStatus.approved
                            ? () => _convertToInvoice(context, finance, quote)
                            : null,
                        onDelete: () => _confirmDelete(context, finance, quote),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(
    OsFinanceController finance,
    OsQuotationModel quote,
    String status,
  ) async {
    if (status == quote.status) return;
    final ok = await finance.setQuotationStatus(quote, status);
    if (!ok) {
      OsSnackbar.error(
        AppLocaleKeys.osQuotationsTitle.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
      throw Exception('status update failed');
    }
    OsSnackbar.success(
      AppLocaleKeys.osQuotationsTitle.tr,
      AppLocaleKeys.osQuotationsStatusUpdated.tr,
    );
  }

  Future<void> _confirmApprove(
    BuildContext context,
    OsFinanceController finance,
    OsQuotationModel quote,
  ) async {
    await FunHelper.showConfirmDailog(
      context,
      title: AppLocaleKeys.osQuotationsApprove.tr,
      message: AppLocaleKeys.osQuotationsApproveConfirm.tr,
      confirmText: AppLocaleKeys.osQuotationsApprove.tr,
      confirmColor: AppColors.primary,
      onTap: () => _setStatus(
        finance,
        quote,
        OsQuotationStatus.approved,
      ),
    );
  }

  Future<void> _confirmReject(
    BuildContext context,
    OsFinanceController finance,
    OsQuotationModel quote,
  ) async {
    await FunHelper.showConfirmDailog(
      context,
      title: AppLocaleKeys.osQuotationsReject.tr,
      message: AppLocaleKeys.osQuotationsRejectConfirm.tr,
      confirmText: AppLocaleKeys.osQuotationsReject.tr,
      confirmColor: AppColors.caution,
      onTap: () => _setStatus(
        finance,
        quote,
        OsQuotationStatus.rejected,
      ),
    );
  }

  Future<void> _confirmReopen(
    BuildContext context,
    OsFinanceController finance,
    OsQuotationModel quote,
  ) async {
    await FunHelper.showConfirmDailog(
      context,
      title: AppLocaleKeys.osQuotationsReopen.tr,
      message: AppLocaleKeys.osQuotationsReopenConfirm.tr,
      confirmText: AppLocaleKeys.osQuotationsReopen.tr,
      confirmColor: AppColors.primary,
      onTap: () => _setStatus(
        finance,
        quote,
        OsQuotationStatus.sent,
      ),
    );
  }

  Future<void> _copyLink(OsQuotationModel quote) async {
    await copyOsQuotationAcceptLink(quote);
    if (!mounted) return;
    setState(() => _copiedId = quote.id);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_copiedId == quote.id) setState(() => _copiedId = null);
    });
  }

  Future<void> _convertToInvoice(
    BuildContext context,
    OsFinanceController finance,
    OsQuotationModel quote,
  ) async {
    final quoteId = quote.id?.trim() ?? '';
    final alreadyLinked = finance.invoices.any(
      (inv) => inv.quotationId == quoteId && (inv.id?.isNotEmpty ?? false),
    );

    try {
      final invoiceId = await finance.createInvoiceFromQuotation(quote);
      if (!mounted) return;
      if (invoiceId == null || invoiceId.isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osQuotationsTitle.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
        return;
      }

      OsSnackbar.success(
        AppLocaleKeys.osQuotationsTitle.tr,
        alreadyLinked
            ? AppLocaleKeys.osQuotationsConvertExists.tr
            : AppLocaleKeys.osQuotationsConvertSuccess.tr,
      );

      final toOpen = await _waitForInvoice(finance, invoiceId);
      if (!mounted || toOpen == null) return;
      await showOsInvoiceFormDialog(context, existing: toOpen);
    } on OsFinanceException catch (e) {
      if (!mounted) return;
      OsSnackbar.error(AppLocaleKeys.osQuotationsTitle.tr, e.messageKey.tr);
    }
  }

  Future<OsInvoiceModel?> _waitForInvoice(
    OsFinanceController finance,
    String invoiceId,
  ) async {
    for (var i = 0; i < 20; i++) {
      for (final inv in finance.invoices) {
        if (inv.id == invoiceId) return inv;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OsFinanceController finance,
    OsQuotationModel quote,
  ) async {
    final id = quote.id;
    if (id == null || id.isEmpty) return;
    final confirmed = await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: AppLocaleKeys.osQuotationsDeleteConfirm.tr,
      onTap: () async {
        final ok = await finance.deleteQuotation(id);
        if (!ok) {
          OsSnackbar.error(
            AppLocaleKeys.osQuotationsTitle.tr,
            AppLocaleKeys.osCommonSaveFailed.tr,
          );
          throw Exception('delete failed');
        }
      },
    );
    if (confirmed == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OsSnackbar.success(
          AppLocaleKeys.osQuotationsTitle.tr,
          AppLocaleKeys.osQuotationsDeleted.tr,
        );
      });
    }
  }
}

class _TemplatePanel extends StatefulWidget {
  const _TemplatePanel({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_TemplatePanel> createState() => _TemplatePanelState();
}

class _TemplatePanelState extends State<_TemplatePanel> {
  late final TextEditingController _headerCtrl;
  late final TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    final template = Get.find<OsQuoteTemplateController>();
    _headerCtrl = TextEditingController(text: template.headerText.value);
    _footerCtrl = TextEditingController(text: template.footerText.value);
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final template = Get.find<OsQuoteTemplateController>();

    Widget headerField() => TextField(
          controller: _headerCtrl,
          decoration: osFinanceFieldDecoration(
            AppLocaleKeys.osQuotationsTemplateHeader.tr,
          ),
          onChanged: template.setHeaderText,
        );

    Widget footerField() => TextField(
          controller: _footerCtrl,
          decoration: osFinanceFieldDecoration(
            AppLocaleKeys.osQuotationsTemplateFooter.tr,
          ),
          onChanged: template.setFooterText,
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: theme.accentText, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleKeys.osQuotationsTemplateSettings.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryText,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppLocaleKeys.osCommonClose.tr,
                onPressed: widget.onClose,
                icon: Icon(Icons.close, color: theme.secondaryText, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 640;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: headerField()),
                    const SizedBox(width: 12),
                    Expanded(child: footerField()),
                  ],
                );
              }
              return Column(
                children: [
                  headerField(),
                  const SizedBox(height: 12),
                  footerField(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.copied,
    required this.onApprove,
    required this.onReject,
    required this.onReopen,
    required this.onCopyLink,
    required this.onPreview,
    required this.onEdit,
    required this.onDelete,
    this.onConvertToInvoice,
  });

  final OsQuotationModel quote;
  final bool copied;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onReopen;
  final VoidCallback onCopyLink;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onConvertToInvoice;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final color = OsFinanceFormat.quotationStatusColor(quote.status);
    final ref = OsFinanceFormat.quotationRef(quote);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final itemCount = quote.items.isEmpty ? 1 : quote.items.length;
    final isPending = quote.status == OsQuotationStatus.sent;
    final isApproved = quote.status == OsQuotationStatus.approved;
    final isRejected = quote.status == OsQuotationStatus.rejected;

    final meta =
        '${AppLocaleKeys.osQuotationsNumber.tr}: $ref • '
        '${AppLocaleKeys.osQuotationsIssueDate.tr}: ${quote.date} • '
        '${AppLocaleKeys.osQuotationsExpires.tr}: ${quote.expiryDate}';

    final info = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.description_outlined, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quote.clientName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meta,
                style: TextStyle(fontSize: 12, color: theme.mutedText),
              ),
              const SizedBox(height: 6),
              Text(
                osInvoiceItemsCountLabel(itemCount),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.accentText,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final amount = Column(
      children: [
        Text(
          OsFinanceFormat.money(quote.total),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: theme.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            OsFinanceFormat.quotationStatusLabel(quote.status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ),
      ],
    );

    FilledButton toolButton({
      required VoidCallback onPressed,
      required String label,
      IconData? icon,
      ButtonStyle? style,
    }) {
      final child = Text(label);
      final btnStyle = style ?? OsButtonStyles.inlineTool(theme);
      if (icon == null) {
        return FilledButton(
          onPressed: onPressed,
          style: btnStyle,
          child: child,
        );
      }
      return FilledButton.icon(
        onPressed: onPressed,
        style: btnStyle,
        icon: Icon(icon, size: 16),
        label: child,
      );
    }

    // RTL: first Row child sits on the right — primary CTA there, tools on the left.
    final primaryActions = <Widget>[
      if (isPending) ...[
        FilledButton.icon(
          onPressed: onApprove,
          style: OsButtonStyles.inlinePrimary(),
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: Text(AppLocaleKeys.osQuotationsApprove.tr),
        ),
        FilledButton.icon(
          onPressed: onReject,
          style: OsButtonStyles.inlineCaution(),
          icon: const Icon(Icons.cancel_outlined, size: 16),
          label: Text(AppLocaleKeys.osQuotationsReject.tr),
        ),
      ],
      if (isApproved && onConvertToInvoice != null)
        FilledButton.icon(
          onPressed: onConvertToInvoice,
          style: OsButtonStyles.inlinePrimary(),
          icon: const Icon(Icons.receipt_long_outlined, size: 16),
          label: Text(AppLocaleKeys.osQuotationsConvertToInvoice.tr),
        ),
      if (isRejected)
        FilledButton.icon(
          onPressed: onApprove,
          style: OsButtonStyles.inlinePrimary(),
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: Text(AppLocaleKeys.osQuotationsApprove.tr),
        ),
    ];

    final toolActions = <Widget>[
      toolButton(
        onPressed: onPreview,
        label: AppLocaleKeys.osQuotationsPreview.tr,
      ),
      toolButton(
        onPressed: onEdit,
        label: AppLocaleKeys.osQuotationsEdit.tr,
      ),
      toolButton(
        onPressed: onCopyLink,
        icon: copied ? Icons.check : Icons.link,
        label: copied
            ? AppLocaleKeys.osQuotationsCopied.tr
            : AppLocaleKeys.osQuotationsCopyLink.tr,
        style: copied
            ? OsButtonStyles.inlineTool(theme).copyWith(
                foregroundColor: WidgetStatePropertyAll(AppColors.primary),
                side: WidgetStatePropertyAll(
                  BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.45),
                  ),
                ),
              )
            : null,
      ),
      if (isApproved || isRejected)
        toolButton(
          onPressed: onReopen,
          label: AppLocaleKeys.osQuotationsReopen.tr,
        ),
      IconButton(
        tooltip: AppLocaleKeys.osCommonDelete.tr,
        onPressed: onDelete,
        visualDensity: VisualDensity.compact,
        icon: const Icon(
          Icons.delete_outline,
          color: AppColors.destructive,
          size: 20,
        ),
      ),
    ];

    final actions = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (primaryActions.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: primaryActions,
            ),
            if (toolActions.isNotEmpty) ...[
              Container(
                height: 28,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: theme.border,
              ),
            ],
          ],
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: toolActions,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (narrow) ...[
            info,
            const SizedBox(height: 14),
            amount,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: info),
                amount,
              ],
            ),
          const SizedBox(height: 16),
          actions,
        ],
      ),
    );
  }
}
