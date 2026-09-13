import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/os_quote_template_settings.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
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
                        onCycleStatus: () => _cycleStatus(finance, quote),
                        onCopyLink: () => _copyLink(quote),
                        onPreview: () =>
                            showOsQuotationPreviewDialog(context, quote),
                        onEdit: () => showOsQuotationFormDialog(
                          context,
                          existing: quote,
                        ),
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

  Future<void> _cycleStatus(
    OsFinanceController finance,
    OsQuotationModel quote,
  ) async {
    final ok = await finance.cycleQuotationStatus(quote);
    if (!ok) {
      OsSnackbar.error(
        AppLocaleKeys.osQuotationsTitle.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
    }
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
    required this.onCycleStatus,
    required this.onCopyLink,
    required this.onPreview,
    required this.onEdit,
    required this.onDelete,
  });

  final OsQuotationModel quote;
  final bool copied;
  final VoidCallback onCycleStatus;
  final VoidCallback onCopyLink;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final color = OsFinanceFormat.quotationStatusColor(quote.status);
    final ref = OsFinanceFormat.quotationRef(quote);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final itemCount = quote.items.isEmpty ? 1 : quote.items.length;

    final meta =
        '${AppLocaleKeys.osQuotationsNumber.tr}: $ref • '
        '${AppLocaleKeys.osQuotationsIssueDate.tr}: ${quote.date} • '
        '${AppLocaleKeys.osQuotationsExpires.tr}: ${quote.expiryDate}';

    final statusLabel = switch (quote.status) {
      OsQuotationStatus.approved =>
        '✓ ${OsFinanceFormat.quotationStatusLabel(quote.status)}',
      OsQuotationStatus.rejected =>
        '✕ ${OsFinanceFormat.quotationStatusLabel(quote.status)}',
      _ => '⧗ ${OsFinanceFormat.quotationStatusLabel(quote.status)}',
    };

    final info = Row(
      children: [
        Tooltip(
          message: AppLocaleKeys.osQuotationsCycleStatusHint.tr,
          child: Material(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onCycleStatus,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(Icons.description_outlined, color: color, size: 24),
              ),
            ),
          ),
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
        const SizedBox(height: 4),
        Text(
          statusLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: color,
          ),
        ),
      ],
    );

    final actionStyle = OsButtonStyles.inline(theme).copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(0, 34)),
      maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 34)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final copyStyle = copied
        ? actionStyle.copyWith(
            foregroundColor: const WidgetStatePropertyAll(AppColors.success),
            backgroundColor: WidgetStatePropertyAll(
              AppColors.success.withValues(alpha: 0.16),
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: AppColors.success),
            ),
          )
        : actionStyle;

    final actions = Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.end,
        children: [
          FilledButton(
            onPressed: onEdit,
            style: actionStyle,
            child: Text(AppLocaleKeys.osQuotationsEdit.tr),
          ),
          FilledButton(
            onPressed: onCopyLink,
            style: copyStyle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(copied ? Icons.check : Icons.link, size: 16),
                const SizedBox(width: 6),
                Text(
                  copied
                      ? AppLocaleKeys.osQuotationsCopied.tr
                      : AppLocaleKeys.osQuotationsCopyLink.tr,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onPreview,
            style: actionStyle,
            child: Text(AppLocaleKeys.osQuotationsPreview.tr),
          ),
          IconButton(
            tooltip: AppLocaleKeys.osCommonDelete.tr,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFF43F5E), size: 20),
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
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 14),
                amount,
                const SizedBox(height: 12),
                actions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: info),
                Expanded(flex: 2, child: Center(child: amount)),
                Flexible(flex: 3, child: actions),
              ],
            ),
    );
  }
}
