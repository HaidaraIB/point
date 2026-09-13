import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_line_items_editor.dart';
import 'package:point/View/Os/os_snackbar.dart';

Future<void> showOsQuotationFormDialog(
  BuildContext context, {
  OsQuotationModel? existing,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OsQuotationFormDialog(existing: existing),
  );
}

class _OsQuotationFormDialog extends StatefulWidget {
  const _OsQuotationFormDialog({this.existing});

  final OsQuotationModel? existing;

  @override
  State<_OsQuotationFormDialog> createState() => _OsQuotationFormDialogState();
}

class _OsQuotationFormDialogState extends State<_OsQuotationFormDialog> {
  String? _clientId;
  late DateTime _expiry;
  late final OsLineItemsController _lines;
  var _saving = false;

  List<ClientModel> get _clients {
    return Get.find<HomeController>()
        .clients
        .where((c) => (c.id ?? '').isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _clientId = e?.clientId;
    _expiry = OsFinanceFormat.parseYmd(e?.expiryDate) ??
        DateTime.now().add(const Duration(days: 14));
    _lines = OsLineItemsController(
      initialItems: e?.items,
      initialTaxRate: (e != null && e.vat > 0) ? 0.05 : 0,
    );
    // Legacy lump-sum: seed one line from amount/total when no items.
    if (e != null && e.items.isEmpty && e.total > 0) {
      final draft = _lines.lines.first;
      draft.description.text = AppLocaleKeys.osInvoicesItemsFallback.tr;
      draft.qtyCtrl.text = '1';
      draft.priceCtrl.text =
          (e.amount > 0 ? e.amount : e.total).toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _lines.dispose();
    super.dispose();
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.appTheme.secondaryText,
        ),
      ),
    );
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    final finance = Get.find<OsFinanceController>();
    final clients = _clients;
    final clientId = _clientId;
    ClientModel? client;
    if (clientId != null) {
      for (final c in clients) {
        if (c.id == clientId) {
          client = c;
          break;
        }
      }
    }
    if (client == null) {
      OsSnackbar.error(
        AppLocaleKeys.osQuotationsCreateTitle.tr,
        AppLocaleKeys.osQuotationsErrorNoClient.tr,
      );
      return;
    }

    final items = _lines.buildItems();
    if (items == null) {
      OsSnackbar.error(
        AppLocaleKeys.osQuotationsCreateTitle.tr,
        AppLocaleKeys.osInvoicesErrorNoItems.tr,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final existing = widget.existing;
      final ok = await finance.saveQuotation(
        OsQuotationModel(
          id: existing?.id,
          displayNumber: existing?.displayNumber,
          clientId: client.id!,
          clientName: (client.name ?? client.email ?? client.id!).trim(),
          date: existing?.date ?? OsFinanceFormat.ymd(now),
          expiryDate: OsFinanceFormat.ymd(_expiry),
          status: existing?.status ?? OsQuotationStatus.sent,
          amount: _lines.subtotal,
          vat: _lines.vat,
          total: _lines.total,
          items: items,
          createdAt: existing?.createdAt ?? now,
        ),
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          OsSnackbar.success(
            AppLocaleKeys.osQuotationsTitle.tr,
            AppLocaleKeys.osQuotationsSaved.tr,
          );
        });
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osQuotationsTitle.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = _clients;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final maxH = MediaQuery.sizeOf(context).height * (narrow ? 0.92 : 0.9);
    final theme = context.appTheme;
    final isEdit = widget.existing != null;

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
                  Icon(
                    Icons.description_outlined,
                    color: theme.accentText,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit
                          ? AppLocaleKeys.osQuotationsEditTitle.tr
                          : AppLocaleKeys.osQuotationsCreateTitle.tr,
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
                    _label(AppLocaleKeys.osQuotationsClient.tr),
                    DropdownButtonFormField<String>(
                      initialValue: clients.any((c) => c.id == _clientId)
                          ? _clientId
                          : null,
                      decoration: osDialogFieldDecoration(
                        context,
                        hint: AppLocaleKeys.osQuotationsClientHint.tr,
                      ),
                      items: [
                        for (final c in clients)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name ?? c.email ?? c.id!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _clientId = v),
                    ),
                    const SizedBox(height: 16),
                    _label(AppLocaleKeys.osQuotationsExpiry.tr),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        alignment: AlignmentDirectional.centerStart,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: _pickExpiry,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              OsFinanceFormat.ymd(_expiry),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OsLineItemsEditor(controller: _lines),
                    const SizedBox(height: 24),
                    OsFormDialogActions(
                      saveLabel: AppLocaleKeys.osQuotationsSaveSend.tr,
                      saveColor: AppColors.primary,
                      saveIcon: Icons.save_outlined,
                      saving: _saving,
                      onSave: _save,
                      onCancel: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
