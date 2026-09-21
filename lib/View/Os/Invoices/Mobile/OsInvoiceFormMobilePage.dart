import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_finance_status_widgets.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_invoice_stamp.dart';
import 'package:point/View/Os/os_line_items_editor.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsInvoiceFormMobilePage extends StatefulWidget {
  const OsInvoiceFormMobilePage({super.key, this.existing});

  final OsInvoiceModel? existing;

  @override
  State<OsInvoiceFormMobilePage> createState() =>
      _OsInvoiceFormMobilePageState();
}

class _OsInvoiceFormMobilePageState extends State<OsInvoiceFormMobilePage> {
  late String? _clientId;
  late DateTime _date;
  late DateTime _dueDate;
  late String _status;
  late String? _bankAccountId;
  late String _paymentMethod;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _taxCtrl;
  late final OsLineItemsController _lines;
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
    if (_status == OsInvoiceStatus.paid) _status = OsInvoiceStatus.sent;
    _bankAccountId = e?.bankAccountId;
    _paymentMethod = e?.paymentMethod ?? OsPaymentMethod.bankTransfer;
    _discountCtrl = TextEditingController(
      text: (e?.discount ?? 0) > 0 ? e!.discount.toStringAsFixed(0) : '',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _phoneCtrl = TextEditingController(text: e?.clientPhone ?? '');
    _emailCtrl = TextEditingController(text: e?.clientEmail ?? '');
    _addressCtrl = TextEditingController(text: e?.clientAddress ?? '');
    _taxCtrl = TextEditingController(text: e?.clientTaxNumber ?? '');
    _lines = OsLineItemsController(
      initialItems: e?.items,
      initialTaxRate: (e != null && e.vat > 0) ? 0.05 : 0,
    );
    if (e == null ||
        ((e.clientPhone == null || e.clientPhone!.isEmpty) &&
            (e.clientEmail == null || e.clientEmail!.isEmpty))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyClientContact(_clientId);
      });
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _taxCtrl.dispose();
    _lines.dispose();
    super.dispose();
  }

  void _applyClientContact(String? clientId) {
    if (clientId == null) return;
    final clients = Get.find<HomeController>().clients;
    ClientModel? client;
    for (final c in clients) {
      if (c.id == clientId) {
        client = c;
        break;
      }
    }
    if (client == null) return;
    setState(() {
      if (_phoneCtrl.text.trim().isEmpty) {
        _phoneCtrl.text = client!.phone?.trim() ?? '';
      }
      if (_emailCtrl.text.trim().isEmpty) {
        _emailCtrl.text = client!.email?.trim() ?? '';
      }
      if (_addressCtrl.text.trim().isEmpty) {
        _addressCtrl.text = client!.address?.trim() ?? '';
      }
    });
  }

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

  Future<void> _save() async {
    final clients = Get.find<HomeController>().clients;
    ClientModel? client;
    for (final c in clients) {
      if (c.id == _clientId) {
        client = c;
        break;
      }
    }
    if (client?.id == null) {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesErrorNoClient.tr,
      );
      return;
    }

    final items = _lines.buildItems();
    if (items == null) {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesErrorNoItems.tr,
      );
      return;
    }

    setState(() => _saving = true);
    final discount =
        double.tryParse(_discountCtrl.text.trim().replaceAll(',', '')) ?? 0;
    final model = OsInvoiceModel(
      id: widget.existing?.id,
      displayNumber: widget.existing?.displayNumber,
      clientId: client!.id!,
      clientName: client.name?.trim().isNotEmpty == true
          ? client.name!.trim()
          : (client.email ?? client.id!),
      clientPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      clientEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      clientAddress:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      clientTaxNumber:
          _taxCtrl.text.trim().isEmpty ? null : _taxCtrl.text.trim(),
      date: OsFinanceFormat.ymd(_date),
      dueDate: OsFinanceFormat.ymd(_dueDate),
      status: _status,
      amount: _lines.subtotal,
      discount: discount < 0 ? 0 : discount,
      vat: _lines.vat,
      total: OsInvoiceModel.computeTotal(
        amount: _lines.subtotal,
        discount: discount < 0 ? 0 : discount,
        vat: _lines.vat,
      ),
      items: items,
      bankAccountId: _bankAccountId,
      paymentMethod: _paymentMethod,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
      Get.back();
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

    return Scaffold(
      backgroundColor: theme.pageBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: widget.existing == null
                ? AppLocaleKeys.osInvoicesAdd.tr
                : AppLocaleKeys.osInvoicesEdit.tr,
            currentRoute: '/os/invoices',
            onBack: () {
              if (Get.key.currentState?.canPop() ?? false) {
                Get.back();
              } else {
                Get.offNamed('/os/invoices');
              }
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          DropdownButtonFormField<String>(
            key: ValueKey(_clientId),
            initialValue:
                _clientId != null && clients.any((c) => c.id == _clientId)
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
            onChanged: (v) {
              setState(() => _clientId = v);
              _applyClientContact(v);
            },
          ),
          const SizedBox(height: 10),
          osPhoneTextFormField(
            controller: _phoneCtrl,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesClientPhone.tr,
            ),
          ),
          const SizedBox(height: 10),
          osTypedTextFormField(
            controller: _emailCtrl,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesClientEmail.tr,
            ),
          ),
          const SizedBox(height: 10),
          osTypedTextFormField(
            controller: _addressCtrl,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesClientAddress.tr,
            ),
          ),
          const SizedBox(height: 10),
          osTypedTextFormField(
            controller: _taxCtrl,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesClientTax.tr,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _pickDate(due: false),
            child: Text(
              '${AppLocaleKeys.osInvoicesDate.tr}: ${OsFinanceFormat.ymd(_date)}',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _pickDate(due: true),
            child: Text(
              '${AppLocaleKeys.osInvoicesDueDate.tr}: ${OsFinanceFormat.ymd(_dueDate)}',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_paymentMethod),
            initialValue: OsPaymentMethod.all.contains(_paymentMethod)
                ? _paymentMethod
                : OsPaymentMethod.bankTransfer,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesPaymentMethod.tr,
            ),
            items: [
              for (final m in OsPaymentMethod.all)
                DropdownMenuItem(
                  value: m,
                  child: Text(OsFinanceFormat.paymentMethodLabel(m)),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _paymentMethod = v);
            },
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_status),
            initialValue: OsInvoiceStatus.editable.contains(_status)
                ? _status
                : OsInvoiceStatus.sent,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesStatus.tr,
            ),
            items: osInvoiceStatusDropdownItems(OsInvoiceStatus.editable),
            onChanged: (v) {
              if (v != null) setState(() => _status = v);
            },
          ),
          const SizedBox(height: 16),
          OsLineItemsEditor(controller: _lines, compact: true),
          const SizedBox(height: 12),
          osTypedTextFormField(
            controller: _discountCtrl,
            keyboardType: TextInputType.number,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesDiscount.tr,
            ),
          ),
          const SizedBox(height: 10),
          osTypedTextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesNotes.tr,
            ),
          ),
          Obx(() {
            if (!stamp.stampEnabled.value) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  Text(
                    AppLocaleKeys.osInvoicesStampPreview.tr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: theme.accentText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const OsInvoiceStamp(compact: true),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
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
                : const Icon(Icons.save_outlined),
            label: Text(AppLocaleKeys.osInvoicesSaveFull.tr),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
