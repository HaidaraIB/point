import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/os_arabic_currency.dart';
import 'package:point/View/Os/Finance/os_voucher_print.dart';
import 'package:point/View/Os/Finance/os_voucher_print_text.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_electronic_stamp.dart';
import 'package:point/View/Os/os_finance_format.dart';

class OsVoucherDetailPanel extends StatefulWidget {
  const OsVoucherDetailPanel({
    super.key,
    required this.voucher,
    required this.accountName,
    this.onDelete,
  });

  final OsVoucherModel voucher;
  final String accountName;
  final Future<void> Function(OsVoucherModel voucher)? onDelete;

  @override
  State<OsVoucherDetailPanel> createState() => _OsVoucherDetailPanelState();
}

class _OsVoucherDetailPanelState extends State<OsVoucherDetailPanel> {
  var _copied = false;
  var _deleting = false;

  String get _ref => OsFinanceFormat.voucherRef(widget.voucher);

  Future<void> _copy() async {
    final slip = buildOsVoucherPlainText(
      voucher: widget.voucher,
      accountName: widget.accountName,
    );
    await Clipboard.setData(ClipboardData(text: slip));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _print() async {
    await printOsVoucher(
      voucher: widget.voucher,
      accountName: widget.accountName,
    );
  }

  Future<void> _confirmDelete() async {
    if (widget.onDelete == null || _deleting) return;
    await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osVouchersDelete.tr,
      message: AppLocaleKeys.osVouchersDeleteConfirm.tr,
      onTap: () async {
        setState(() => _deleting = true);
        try {
          await widget.onDelete!(widget.voucher);
        } finally {
          if (mounted) setState(() => _deleting = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final v = widget.voucher;
    final isReceipt = v.type == OsVoucherType.receipt;
    final accent = isReceipt
        ? ((Theme.of(context).brightness == Brightness.dark)
            ? const Color(0xFF4ADE80)
            : Colors.green)
        : ((Theme.of(context).brightness == Brightness.dark)
            ? const Color(0xFFF87171)
            : Colors.redAccent);
    final desc = OsFinanceFormat.displayDescription(v.description);
    final canDelete =
        v.isManuallyDeletable && widget.onDelete != null && !_deleting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: theme.accentText),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        AppLocaleKeys.osVouchersPrintHint.tr,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _copy,
                    style: OsButtonStyles.secondaryCompact(theme),
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                    label: Text(
                      _copied
                          ? AppLocaleKeys.osVouchersCopied.tr
                          : AppLocaleKeys.osVouchersCopy.tr,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _print,
                    style: OsButtonStyles.primaryCompact(),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: Text(AppLocaleKeys.osVouchersPrint.tr),
                  ),
                  if (v.isManuallyDeletable && widget.onDelete != null)
                    OutlinedButton.icon(
                      onPressed: canDelete ? _confirmDelete : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF43F5E),
                        side: const BorderSide(color: Color(0xFFF43F5E)),
                        minimumSize: OsButtonStyles.compactMinSize,
                        padding: OsButtonStyles.compactPadding,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: _deleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline, size: 18),
                      label: Text(AppLocaleKeys.osVouchersDelete.tr),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleKeys.osVouchersAgency.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocaleKeys.osVouchersDept.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          AppLocaleKeys.osVouchersLocation.tr,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.pageBackground.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppLocaleKeys.osVouchersRef.tr}: $_ref',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.accentText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppLocaleKeys.osVouchersDate.tr}: ${v.date}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      isReceipt
                          ? AppLocaleKeys.osVouchersTitleReceipt.tr
                          : AppLocaleKeys.osVouchersTitlePayment.tr,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      label: AppLocaleKeys.osVouchersAmountDigits.tr,
                      value: OsFinanceFormat.money(v.amount),
                      valueColor: theme.accentText,
                      centered: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InfoTile(
                      label: AppLocaleKeys.osVouchersAccountLinked.tr,
                      value: widget.accountName,
                      centered: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReceiptRow(
                      label: isReceipt
                          ? AppLocaleKeys.osVouchersFrom.tr
                          : AppLocaleKeys.osVouchersTo.tr,
                      value: v.payeeOrPayer,
                      bold: true,
                    ),
                    const Divider(height: 20),
                    _ReceiptRow(
                      label: AppLocaleKeys.osVouchersAmountWordsLabel.tr,
                      value: OsArabicCurrency.formatIqd(v.amount),
                    ),
                    const Divider(height: 20),
                    _ReceiptRow(
                      label: AppLocaleKeys.osVouchersAboutLabel.tr,
                      value: desc.isEmpty
                          ? AppLocaleKeys.osVouchersDefaultDesc.tr
                          : desc,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Obx(() {
                final stampOn =
                    Get.find<OsStampSettingsController>().stampEnabled.value;
                final narrow = MediaQuery.sizeOf(context).width < 700;
                final stamp = OsElectronicStamp(
                  reference: _ref,
                  size: narrow ? 88 : 112,
                );
                if (narrow) {
                  return Column(
                    children: [
                      if (stampOn) ...[
                        stamp,
                        const SizedBox(height: 16),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SignBlock(
                              label: AppLocaleKeys.osVouchersSignPayee.tr,
                              subtitle:
                                  AppLocaleKeys.osVouchersSignPayeeSub.tr,
                            ),
                          ),
                          Expanded(
                            child: _SignBlock(
                              label: AppLocaleKeys.osVouchersSignAccountant.tr,
                              subtitle: AppLocaleKeys
                                  .osVouchersSignAccountantSub.tr,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SignBlock(
                        label: AppLocaleKeys.osVouchersSignPayee.tr,
                        subtitle: AppLocaleKeys.osVouchersSignPayeeSub.tr,
                      ),
                    ),
                    if (stampOn)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: stamp,
                      ),
                    Expanded(
                      child: _SignBlock(
                        label: AppLocaleKeys.osVouchersSignAccountant.tr,
                        subtitle: AppLocaleKeys.osVouchersSignAccountantSub.tr,
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),
              Text(
                AppLocaleKeys.osVouchersFooter.tr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: theme.secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.centered = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final align =
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.pageBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            label,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(fontSize: 11, color: theme.secondaryText),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: theme.secondaryText),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: theme.primaryText,
          ),
        ),
      ],
    );
  }
}

class _SignBlock extends StatelessWidget {
  const _SignBlock({required this.label, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: theme.secondaryText),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: theme.mutedText),
          ),
        ],
        const SizedBox(height: 28),
        Container(
          width: 120,
          height: 1,
          color: theme.border,
        ),
      ],
    );
  }
}
