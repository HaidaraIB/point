import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:point/View/Os/os_snackbar.dart';

Future<void> showOsQuotationFormDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _OsQuotationFormDialog(),
  );
}

class _OsQuotationFormDialog extends StatefulWidget {
  const _OsQuotationFormDialog();

  @override
  State<_OsQuotationFormDialog> createState() => _OsQuotationFormDialogState();
}

class _OsQuotationFormDialogState extends State<_OsQuotationFormDialog> {
  final _amountCtrl = TextEditingController(text: '0');
  String? _clientId;
  late DateTime _expiry;
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
    _expiry = DateTime.now().add(const Duration(days: 14));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
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
    final amount = double.tryParse(
          _amountCtrl.text.trim().replaceAll(',', ''),
        ) ??
        0;
    if (amount <= 0) {
      OsSnackbar.error(
        AppLocaleKeys.osQuotationsCreateTitle.tr,
        AppLocaleKeys.osQuotationsErrorAmount.tr,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final ok = await finance.saveQuotation(
        OsQuotationModel(
          clientId: client.id!,
          clientName: (client.name ?? client.email ?? client.id!).trim(),
          date: OsFinanceFormat.ymd(now),
          expiryDate: OsFinanceFormat.ymd(_expiry),
          status: OsQuotationStatus.sent,
          total: amount,
          createdAt: now,
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
    final currency = AppLocaleKeys.osInvoicesCurrency.tr;

    return OsDialogFrame(
      title: AppLocaleKeys.osQuotationsCreateTitle.tr,
      icon: Icons.description_outlined,
      closeEnabled: !_saving,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(AppLocaleKeys.osQuotationsClient.tr),
          DropdownButtonFormField<String>(
            initialValue:
                clients.any((c) => c.id == _clientId) ? _clientId : null,
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _clientId = v),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(AppLocaleKeys.osQuotationsTotal.tr),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: osDialogFieldDecoration(
                        context,
                        hint: '0',
                        suffixText: currency,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                  ],
                ),
              ),
            ],
          ),
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
    );
  }
}
