import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/os_invoice_service_presets.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_invoice_stamp.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:uuid/uuid.dart';

Future<void> showOsInvoiceFormDialog(
  BuildContext context, {
  OsInvoiceModel? existing,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OsInvoiceFormDialog(existing: existing),
  );
}

Future<void> showOsMarkPaidDialog(
  BuildContext context,
  OsInvoiceModel invoice,
) async {
  final finance = Get.find<OsFinanceController>();
  if (finance.bankAccounts.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osInvoicesErrorNoAccount.tr,
    );
    return;
  }

  String? selected = invoice.bankAccountId ?? finance.bankAccounts.first.id;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(AppLocaleKeys.osInvoicesMarkPaid.tr),
        content: StatefulBuilder(
          builder: (context, setLocal) {
            return DropdownButtonFormField<String>(
              key: ValueKey(selected),
              initialValue: selected,
              decoration: InputDecoration(
                labelText: AppLocaleKeys.osInvoicesSelectAccount.tr,
              ),
              items: [
                for (final a in finance.bankAccounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(
                      '${a.name} (${OsFinanceFormat.money(a.balance)})',
                    ),
                  ),
              ],
              onChanged: (v) => setLocal(() => selected = v),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocaleKeys.osCommonCancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocaleKeys.osInvoicesMarkPaid.tr),
          ),
        ],
      );
    },
  );

  if (confirmed != true || selected == null) return;

  try {
    final ok = await finance.markInvoicePaid(
      invoice: invoice,
      bankAccountId: selected!,
    );
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesPaidSuccess.tr,
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
}

Future<void> showOsInvoiceLinkAccountDialog(
  BuildContext context,
  OsInvoiceModel invoice,
) async {
  final finance = Get.find<OsFinanceController>();
  final accounts = finance.bankAccounts.toList();

  final chosen = await showDialog<String?>(
    context: context,
    builder: (ctx) {
      final theme = ctx.appTheme;
      final narrow = MediaQuery.sizeOf(ctx).width < 600;
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: narrow ? 12 : 28,
          vertical: narrow ? 16 : 28,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_outlined,
                        color: theme.accentText, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocaleKeys.osInvoicesLinkAccountTitle.tr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close, color: theme.secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocaleKeys.osInvoicesLinkAccountHint.tr,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final acc in accounts)
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(ctx, acc.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.panelTint,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: invoice.bankAccountId == acc.id
                                      ? AppColors.primary
                                      : theme.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    acc.type == OsBankAccountType.bank
                                        ? Icons.account_balance
                                        : Icons.wallet_outlined,
                                    color: theme.accentText,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          acc.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: theme.primaryText,
                                          ),
                                        ),
                                        Text(
                                          '${OsFinanceFormat.accountNumberLabel(acc.accountNumber)} | ${OsFinanceFormat.money(acc.balance)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.mutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (invoice.bankAccountId == acc.id)
                                    const Icon(
                                      Icons.check,
                                      color: Color(0xFF059669),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: Text(AppLocaleKeys.osInvoicesAccountAuto.tr),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocaleKeys.osCommonCancel.tr),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  // null = dismissed / cancel; empty string = clear to auto.
  if (chosen == null) return;

  final clear = chosen.isEmpty;
  final updated = invoice.copyWith(
    bankAccountId: clear ? null : chosen,
    clearBankAccountId: clear,
  );
  final ok = await finance.saveInvoice(updated);
  if (ok) {
    OsSnackbar.success(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osInvoicesSaved.tr,
    );
  } else {
    OsSnackbar.error(
      AppLocaleKeys.osInvoicesTitle.tr,
      AppLocaleKeys.osCommonSaveFailed.tr,
    );
  }
}

class _OsInvoiceFormDialog extends StatefulWidget {
  const _OsInvoiceFormDialog({this.existing});

  final OsInvoiceModel? existing;

  @override
  State<_OsInvoiceFormDialog> createState() => _OsInvoiceFormDialogState();
}

class _OsInvoiceFormDialogState extends State<_OsInvoiceFormDialog> {
  late String? _clientId;
  late DateTime _date;
  late DateTime _dueDate;
  late String _status;
  late double _taxRate;
  late String? _bankAccountId;
  late List<_LineDraft> _lines;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _clientId = e?.clientId;
    _date = OsFinanceFormat.parseYmd(e?.date) ?? now;
    _dueDate =
        OsFinanceFormat.parseYmd(e?.dueDate) ?? now.add(const Duration(days: 14));
    _status = e?.status ?? OsInvoiceStatus.sent;
    if (_status == OsInvoiceStatus.paid) {
      _status = OsInvoiceStatus.sent;
    }
    _taxRate = (e != null && e.vat > 0) ? 0.05 : 0;
    _bankAccountId = e?.bankAccountId;
    _lines = (e?.items.isNotEmpty == true)
        ? e!.items
            .map(
              (i) => _LineDraft(
                id: i.id,
                description: TextEditingController(text: i.description),
                qtyCtrl: TextEditingController(text: i.quantity.toString()),
                priceCtrl: TextEditingController(text: i.unitPrice.toString()),
              ),
            )
            .toList()
        : [_LineDraft.empty()];
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _subtotal {
    double sum = 0;
    for (final l in _lines) {
      sum += l.lineTotal;
    }
    return sum;
  }

  double get _vat => (_subtotal * _taxRate).roundToDouble();
  double get _total => _subtotal + _vat;

  Future<void> _pickDate({required bool due}) async {
    final initial = due ? _dueDate : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (due) {
        _dueDate = picked;
      } else {
        _date = picked;
      }
    });
  }

  void _applyServicePreset(OsInvoiceServicePreset srv) {
    setState(() {
      final last = _lines.last;
      final blank = last.description.text.trim().isEmpty && last.unitPrice == 0;
      if (_lines.length == 1 && blank) {
        last.description.text = srv.name;
        last.priceCtrl.text = srv.basePrice.toStringAsFixed(0);
      } else {
        _lines.add(
          _LineDraft(
            id: const Uuid().v4(),
            description: TextEditingController(text: srv.name),
            qtyCtrl: TextEditingController(text: '1'),
            priceCtrl:
                TextEditingController(text: srv.basePrice.toStringAsFixed(0)),
          ),
        );
      }
    });
  }

  Future<void> _save() async {
    final clients = Get.find<HomeController>().clients;
    ClientModel? client;
    for (final c in clients) {
      if (c.id == _clientId) {
        client = c;
        break;
      }
    }
    if (client == null || (client.id ?? '').isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesErrorNoClient.tr,
      );
      return;
    }

    final items = <OsInvoiceItem>[];
    for (final l in _lines) {
      final desc = l.description.text.trim();
      if (desc.isEmpty && l.lineTotal == 0) continue;
      if (desc.isEmpty || l.quantity <= 0) {
        OsSnackbar.error(
          AppLocaleKeys.osInvoicesTitle.tr,
          AppLocaleKeys.osInvoicesErrorNoItems.tr,
        );
        return;
      }
      items.add(
        OsInvoiceItem(
          id: l.id,
          description: desc,
          quantity: l.quantity,
          unitPrice: l.unitPrice,
          total: l.lineTotal,
        ),
      );
    }
    if (items.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesErrorNoItems.tr,
      );
      return;
    }

    setState(() => _saving = true);
    final model = OsInvoiceModel(
      id: widget.existing?.id,
      displayNumber: widget.existing?.displayNumber,
      clientId: client.id!,
      clientName: client.name?.trim().isNotEmpty == true
          ? client.name!.trim()
          : (client.email ?? client.id!),
      date: OsFinanceFormat.ymd(_date),
      dueDate: OsFinanceFormat.ymd(_dueDate),
      status: _status,
      amount: _subtotal,
      vat: _vat,
      total: _total,
      items: items,
      bankAccountId: _bankAccountId,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    final ok = await Get.find<OsFinanceController>().saveInvoice(model);
    setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesSaved.tr,
      );
      Navigator.pop(context);
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final clients = Get.find<HomeController>().clients;
    final finance = Get.find<OsFinanceController>();
    final stamp = Get.find<OsStampSettingsController>();
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final maxH = MediaQuery.sizeOf(context).height * (narrow ? 0.92 : 0.9);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 28,
        vertical: narrow ? 16 : 28,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 820, maxHeight: maxH),
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
                    child: Text(
                      widget.existing == null
                          ? AppLocaleKeys.osInvoicesAdd.tr
                          : AppLocaleKeys.osInvoicesEdit.tr,
                      style: TextStyle(
                        fontSize: narrow ? 17 : 20,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.secondaryText),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey(_clientId),
                      initialValue: _clientId != null &&
                              clients.any((c) => c.id == _clientId)
                          ? _clientId
                          : null,
                      decoration: osFinanceFieldDecoration(
                        AppLocaleKeys.osInvoicesClient.tr,
                      ),
                      items: [
                        for (final c in clients)
                          if (c.id != null)
                            DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name ?? c.email ?? c.id!),
                            ),
                      ],
                      onChanged: (v) => setState(() => _clientId = v),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: () => _pickDate(due: false),
                            child: Text(
                              '${AppLocaleKeys.osInvoicesDate.tr}: ${OsFinanceFormat.ymd(_date)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: () => _pickDate(due: true),
                            child: Text(
                              '${AppLocaleKeys.osInvoicesDueDate.tr}: ${OsFinanceFormat.ymd(_dueDate)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Obx(() {
                      final accounts = finance.bankAccounts.toList();
                      return DropdownButtonFormField<String?>(
                        key: ValueKey(_bankAccountId),
                        initialValue: _bankAccountId != null &&
                                accounts.any((a) => a.id == _bankAccountId)
                            ? _bankAccountId
                            : null,
                        decoration: osFinanceFieldDecoration(
                          AppLocaleKeys.osInvoicesCollectionAccount.tr,
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(AppLocaleKeys.osInvoicesAccountAuto.tr),
                          ),
                          for (final a in accounts)
                            DropdownMenuItem<String?>(
                              value: a.id,
                              child: Text(
                                '${a.name} (${OsFinanceFormat.money(a.balance)})',
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _bankAccountId = v),
                      );
                    }),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_status),
                      initialValue: OsInvoiceStatus.editable.contains(_status)
                          ? _status
                          : OsInvoiceStatus.sent,
                      decoration: osFinanceFieldDecoration(
                        AppLocaleKeys.osInvoicesStatus.tr,
                      ),
                      items: [
                        for (final s in OsInvoiceStatus.editable)
                          DropdownMenuItem(
                            value: s,
                            child: Text(OsFinanceFormat.invoiceStatusLabel(s)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _status = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.accentText.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.accentText.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocaleKeys.osInvoicesServiceChips.tr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.accentText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final srv in osInvoiceServicePresets)
                                ActionChip(
                                  avatar: const Icon(Icons.add, size: 16),
                                  label: Text(
                                    '${srv.name} (${OsFinanceFormat.money(srv.basePrice)})',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () => _applyServicePreset(srv),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          AppLocaleKeys.osInvoicesItems.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            osInvoiceItemsCountLabel(_lines.length),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < _lines.length; i++) ...[
                      _buildLineRow(i),
                      const SizedBox(height: 12),
                    ],
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _lines.add(_LineDraft.empty())),
                        icon: const Icon(Icons.add, size: 20),
                        label: Text(AppLocaleKeys.osInvoicesAddItem.tr),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<double>(
                      segments: [
                        ButtonSegment(
                          value: 0,
                          label: Text(AppLocaleKeys.osInvoicesTaxExempt.tr),
                        ),
                        ButtonSegment(
                          value: 0.05,
                          label: Text(AppLocaleKeys.osInvoicesTaxStamp.tr),
                        ),
                      ],
                      selected: {_taxRate},
                      onSelectionChanged: (s) =>
                          setState(() => _taxRate = s.first),
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
                            '${AppLocaleKeys.osInvoicesAmount.tr}: ${OsFinanceFormat.money(_subtotal)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${AppLocaleKeys.osInvoicesVat.tr}: ${OsFinanceFormat.money(_vat)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${AppLocaleKeys.osInvoicesTotal.tr}: ${OsFinanceFormat.money(_total)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: theme.accentText,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(() {
                      if (!stamp.stampEnabled.value) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.panelTint,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.border,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  AppLocaleKeys.osInvoicesStampPreview.tr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: theme.accentText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const OsInvoiceStamp(),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 20),
                  label: Text(AppLocaleKeys.osInvoicesSaveFull.tr),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineRow(int index) {
    final line = _lines[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: TextField(
            controller: line.description,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesItemDesc.tr,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: line.qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: osFinanceFieldDecoration(AppLocaleKeys.osInvoicesQty.tr),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: line.priceCtrl,
            keyboardType: TextInputType.number,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesUnitPrice.tr,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        IconButton(
          onPressed: _lines.length <= 1
              ? null
              : () {
                  setState(() {
                    _lines[index].dispose();
                    _lines.removeAt(index);
                  });
                },
          icon: const Icon(Icons.delete_outline, size: 22),
        ),
      ],
    );
  }
}

class _LineDraft {
  _LineDraft({
    required this.id,
    required this.description,
    required this.qtyCtrl,
    required this.priceCtrl,
  });

  factory _LineDraft.empty() => _LineDraft(
        id: const Uuid().v4(),
        description: TextEditingController(),
        qtyCtrl: TextEditingController(text: '1'),
        priceCtrl: TextEditingController(text: '0'),
      );

  final String id;
  final TextEditingController description;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  double get quantity => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(priceCtrl.text.trim()) ?? 0;
  double get lineTotal => quantity * unitPrice;

  void dispose() {
    description.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
