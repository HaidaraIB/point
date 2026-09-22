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
import 'package:point/Utils/AppFonts.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_finance_status_widgets.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_invoice_stamp.dart';
import 'package:point/View/Os/os_line_items_editor.dart';
import 'package:point/Utils/whatsapp_phone.dart';
import 'package:point/View/Os/os_custom_client.dart';
import 'package:point/View/Os/os_client_contact_fields.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/whatsapp_phone_field.dart';

Future<void> showOsInvoiceFormDialog(
  BuildContext context, {
  OsInvoiceModel? existing,
  String? initialClientId,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OsInvoiceFormDialog(
      existing: existing,
      initialClientId: initialClientId,
    ),
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
  const _OsInvoiceFormDialog({this.existing, this.initialClientId});

  final OsInvoiceModel? existing;
  final String? initialClientId;

  @override
  State<_OsInvoiceFormDialog> createState() => _OsInvoiceFormDialogState();
}

class _OsInvoiceFormDialogState extends State<_OsInvoiceFormDialog> {
  late String? _clientId;
  late DateTime _date;
  late DateTime _dueDate;
  late String _status;
  late String? _bankAccountId;
  late String _paymentMethod;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _customNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _taxCtrl;
  late final OsLineItemsController _lines;
  bool _saving = false;
  Set<OsClientContactField>? _clientHadAtEdit;

  ClientModel? _selectedClient(List<ClientModel> clients) {
    if (_clientId == null || osIsCustomClientId(_clientId)) return null;
    for (final c in clients) {
      if (c.id == _clientId) return c;
    }
    return null;
  }

  void _initContactControllersForEdit(OsInvoiceModel e, ClientModel client) {
    _clientHadAtEdit = osClientContactFieldsPresent(
      client,
      fields: kOsFinanceDocumentContactFields,
    );
    final missing = osClientMissingContactFields(
      client,
      fields: kOsFinanceDocumentContactFields,
    );
    _phoneCtrl.text = missing.contains(OsClientContactField.phone)
        ? (e.clientPhone ?? '')
        : '';
    _emailCtrl.text = missing.contains(OsClientContactField.email)
        ? (e.clientEmail ?? '')
        : '';
    _addressCtrl.text = missing.contains(OsClientContactField.address)
        ? (e.clientAddress ?? '')
        : '';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    final existingClientId = widget.initialClientId ?? e?.clientId;
    if (e != null && osDocumentHasCustomClient(clientId: e.clientId)) {
      _clientId = kOsCustomClientId;
    } else {
      _clientId = existingClientId;
    }
    _date = OsFinanceFormat.parseYmd(e?.date) ?? now;
    _dueDate =
        OsFinanceFormat.parseYmd(e?.dueDate) ?? now.add(const Duration(days: 14));
    _status = e?.status ?? OsInvoiceStatus.sent;
    if (_status == OsInvoiceStatus.paid) {
      _status = OsInvoiceStatus.sent;
    }
    _bankAccountId = e?.bankAccountId;
    _paymentMethod = e?.paymentMethod ?? OsPaymentMethod.bankTransfer;
    _discountCtrl = TextEditingController(
      text: (e?.discount ?? 0) > 0 ? e!.discount.toStringAsFixed(0) : '',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _phoneCtrl = TextEditingController(text: e?.clientPhone ?? '');
    _customNameCtrl = TextEditingController(
      text: e != null && osDocumentHasCustomClient(clientId: e.clientId)
          ? e.clientName
          : '',
    );
    _emailCtrl = TextEditingController(text: e?.clientEmail ?? '');
    _addressCtrl = TextEditingController(text: e?.clientAddress ?? '');
    _taxCtrl = TextEditingController(text: e?.clientTaxNumber ?? '');
    _lines = OsLineItemsController(
      initialItems: e?.items,
      initialTaxRate: (e != null && e.vat > 0) ? 0.05 : 0,
    );
    if (e != null && !osDocumentHasCustomClient(clientId: e.clientId)) {
      final clients = Get.find<HomeController>().clients;
      final client = _selectedClient(clients);
      if (client != null) {
        _initContactControllersForEdit(e, client);
      }
    } else if (e == null) {
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
    _customNameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _taxCtrl.dispose();
    _lines.dispose();
    super.dispose();
  }

  void _applyClientContact(String? clientId) {
    if (clientId == null || osIsCustomClientId(clientId)) {
      setState(() {
        _clientHadAtEdit = null;
        if (osIsCustomClientId(clientId)) {
          _phoneCtrl.clear();
          _emailCtrl.clear();
          _addressCtrl.clear();
        }
      });
      return;
    }
    final clients = Get.find<HomeController>().clients;
    ClientModel? client;
    for (final c in clients) {
      if (c.id == clientId) {
        client = c;
        break;
      }
    }
    if (client == null) return;
    final missing = osClientMissingContactFields(
      client,
      fields: kOsFinanceDocumentContactFields,
    );
    setState(() {
      _clientHadAtEdit = null;
      _phoneCtrl.text = missing.contains(OsClientContactField.phone)
          ? ''
          : '';
      _emailCtrl.text = missing.contains(OsClientContactField.email)
          ? ''
          : '';
      _addressCtrl.text = missing.contains(OsClientContactField.address)
          ? ''
          : '';
    });
  }

  OsClientContactDraft _contactDraftFromControllers(ClientModel? client) {
    final missing = client == null
        ? kOsFinanceDocumentContactFields
        : osClientMissingContactFields(
            client,
            fields: kOsFinanceDocumentContactFields,
          );
    return OsClientContactDraft(
      phone: missing.contains(OsClientContactField.phone)
          ? _phoneCtrl.text.trim()
          : null,
      email: missing.contains(OsClientContactField.email)
          ? _emailCtrl.text.trim()
          : null,
      address: missing.contains(OsClientContactField.address)
          ? _addressCtrl.text.trim()
          : null,
    );
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
    final home = Get.find<HomeController>();
    final clients = home.clients;
    late final String clientId;
    late final String clientName;
    late final OsClientContactDraft resolvedContact;
    ClientModel? linkedClient;

    if (osIsCustomClientId(_clientId)) {
      clientName = _customNameCtrl.text.trim();
      if (clientName.isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osInvoicesTitle.tr,
          AppLocaleKeys.osInvoicesClientName.tr,
        );
        return;
      }
      clientId = '';
      resolvedContact = OsClientContactDraft(
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
    } else {
      linkedClient = _selectedClient(clients);
      if (linkedClient == null || (linkedClient.id ?? '').isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osInvoicesTitle.tr,
          AppLocaleKeys.osInvoicesErrorNoClient.tr,
        );
        return;
      }
      clientId = linkedClient.id!;
      final draft = _contactDraftFromControllers(linkedClient);
      var resolved = osResolveDocumentContact(
        client: linkedClient,
        draft: draft,
        fields: kOsFinanceDocumentContactFields,
      );
      if (widget.existing != null && _clientHadAtEdit != null) {
        resolved = osPreserveExistingDocumentContact(
          existingDocument: OsClientContactDraft(
            phone: widget.existing!.clientPhone,
            email: widget.existing!.clientEmail,
            address: widget.existing!.clientAddress,
          ),
          resolved: resolved,
          clientHadAtEdit: _clientHadAtEdit!,
        );
      }
      resolvedContact = resolved;
      clientName = linkedClient.name?.trim().isNotEmpty == true
          ? linkedClient.name!.trim()
          : (linkedClient.email ?? linkedClient.id!);
    }

    final normalizedPhone = normalizeWhatsappPhone(
          resolvedContact.phone?.trim() ?? '',
        ) ??
        normalizeWhatsappPhoneParts(
          dialCode: splitWhatsappPhone(resolvedContact.phone ?? '').dialCode,
          nationalNumber: resolvedContact.phone ?? '',
        );

    if (normalizedPhone == null || normalizedPhone.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.commonPhoneInvalid.tr,
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

    if (linkedClient != null) {
      final fillOk = await home.fillEmptyClientContact(
        client: linkedClient,
        draft: _contactDraftFromControllers(linkedClient),
        fields: kOsFinanceDocumentContactFields,
      );
      if (!fillOk) {
        if (mounted) setState(() => _saving = false);
        return;
      }
    }

    final discount =
        double.tryParse(_discountCtrl.text.trim().replaceAll(',', '')) ?? 0;
    final model = OsInvoiceModel(
      id: widget.existing?.id,
      displayNumber: widget.existing?.displayNumber,
      clientId: clientId,
      clientName: clientName,
      clientPhone: normalizedPhone,
      clientEmail: resolvedContact.email?.trim().isEmpty ?? true
          ? null
          : resolvedContact.email!.trim(),
      clientAddress: resolvedContact.address?.trim().isEmpty ?? true
          ? null
          : resolvedContact.address!.trim(),
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
    final linkedClient = _selectedClient(clients);
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey(_clientId),
                      initialValue: osIsCustomClientId(_clientId)
                          ? kOsCustomClientId
                          : (_clientId != null &&
                                  clients.any((c) => c.id == _clientId)
                              ? _clientId
                              : null),
                      decoration: osFinanceFieldDecoration(
                        AppLocaleKeys.osInvoicesClient.tr,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: kOsCustomClientId,
                          child: Text(AppLocaleKeys.osInvoicesCustomClient.tr),
                        ),
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
                    if (osIsCustomClientId(_clientId)) ...[
                      const SizedBox(height: 14),
                      osTypedTextFormField(
                        controller: _customNameCtrl,
                        decoration: osFinanceFieldDecoration(
                          AppLocaleKeys.osInvoicesClientName.tr,
                        ),
                      ),
                    ],
                    if (osShowClientContactField(
                      client: linkedClient,
                      field: OsClientContactField.phone,
                      fields: kOsFinanceDocumentContactFields,
                    )) ...[
                      const SizedBox(height: 14),
                      WhatsappPhoneField(
                        key: ValueKey('phone-${_clientId ?? 'custom'}-${_phoneCtrl.text}'),
                        initialNormalized: _phoneCtrl.text.trim().isEmpty
                            ? null
                            : _phoneCtrl.text.trim(),
                        decoration: osClientContactFieldDecoration(
                          osFinanceFieldDecoration(
                            AppLocaleKeys.osInvoicesClientPhone.tr,
                          ),
                          savesToClient: linkedClient != null,
                        ),
                        onChanged: (v) => _phoneCtrl.text = v ?? '',
                      ),
                    ],
                    if (osShowClientContactField(
                      client: linkedClient,
                      field: OsClientContactField.email,
                      fields: kOsFinanceDocumentContactFields,
                    )) ...[
                      const SizedBox(height: 10),
                      osTypedTextFormField(
                        controller: _emailCtrl,
                        decoration: osClientContactFieldDecoration(
                          osFinanceFieldDecoration(
                            AppLocaleKeys.osInvoicesClientEmail.tr,
                          ),
                          savesToClient: linkedClient != null,
                        ),
                      ),
                    ],
                    if (osShowClientContactField(
                      client: linkedClient,
                      field: OsClientContactField.address,
                      fields: kOsFinanceDocumentContactFields,
                    )) ...[
                      const SizedBox(height: 10),
                      osTypedTextFormField(
                        controller: _addressCtrl,
                        decoration: osClientContactFieldDecoration(
                          osFinanceFieldDecoration(
                            AppLocaleKeys.osInvoicesClientAddress.tr,
                          ),
                          savesToClient: linkedClient != null,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    osTypedTextFormField(
                      controller: _taxCtrl,
                      decoration: osFinanceFieldDecoration(
                        AppLocaleKeys.osInvoicesClientTax.tr,
                      ),
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
                      items: osInvoiceStatusDropdownItems(
                        OsInvoiceStatus.editable,
                      ),
                      onChanged: (v) {
                        if (v != null) setState(() => _status = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    OsLineItemsEditor(controller: _lines),
                    const SizedBox(height: 12),
                    osTypedTextFormField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: osFinanceFieldDecoration(
                        AppLocaleKeys.osInvoicesDiscount.tr,
                      ),
                      onChanged: (_) => setState(() {}),
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
                    textStyle: Appfonts.text(
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
}
