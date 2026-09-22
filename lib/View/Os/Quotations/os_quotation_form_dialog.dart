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
import 'package:point/View/Os/os_finance_status_widgets.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_line_items_editor.dart';
import 'package:point/Utils/whatsapp_phone.dart';
import 'package:point/View/Os/os_custom_client.dart';
import 'package:point/View/Os/os_client_contact_fields.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/whatsapp_phone_field.dart';

Future<void> showOsQuotationFormDialog(
  BuildContext context, {
  OsQuotationModel? existing,
  String? initialClientId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OsQuotationFormDialog(
      existing: existing,
      initialClientId: initialClientId,
    ),
  );
}

class _OsQuotationFormDialog extends StatefulWidget {
  const _OsQuotationFormDialog({this.existing, this.initialClientId});

  final OsQuotationModel? existing;
  final String? initialClientId;

  @override
  State<_OsQuotationFormDialog> createState() => _OsQuotationFormDialogState();
}

class _OsQuotationFormDialogState extends State<_OsQuotationFormDialog> {
  String? _clientId;
  late String _status;
  late DateTime _expiry;
  late final OsLineItemsController _lines;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _customNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  var _saving = false;
  Set<OsClientContactField>? _clientHadAtEdit;

  List<ClientModel> get _clients {
    return Get.find<HomeController>()
        .clients
        .where((c) => (c.id ?? '').isNotEmpty)
        .toList();
  }

  ClientModel? _selectedClient() {
    if (_clientId == null || osIsCustomClientId(_clientId)) return null;
    for (final c in _clients) {
      if (c.id == _clientId) return c;
    }
    return null;
  }

  void _initContactControllersForEdit(OsQuotationModel e, ClientModel client) {
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
    final existingClientId = widget.initialClientId ?? e?.clientId;
    if (e != null && osDocumentHasCustomClient(clientId: e.clientId)) {
      _clientId = kOsCustomClientId;
    } else {
      _clientId = existingClientId;
    }
    _status = OsQuotationStatus.all.contains(e?.status)
        ? e!.status
        : OsQuotationStatus.sent;
    _expiry = OsFinanceFormat.parseYmd(e?.expiryDate) ??
        DateTime.now().add(const Duration(days: 14));
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
    if (e != null && !osDocumentHasCustomClient(clientId: e.clientId)) {
      final client = _selectedClient();
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
    ClientModel? client;
    for (final c in _clients) {
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
      _phoneCtrl.text = missing.contains(OsClientContactField.phone) ? '' : '';
      _emailCtrl.text = missing.contains(OsClientContactField.email) ? '' : '';
      _addressCtrl.text =
          missing.contains(OsClientContactField.address) ? '' : '';
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
    final home = Get.find<HomeController>();
    late final String resolvedClientId;
    late final String clientName;
    late final OsClientContactDraft resolvedContact;
    ClientModel? linkedClient;

    if (osIsCustomClientId(_clientId)) {
      clientName = _customNameCtrl.text.trim();
      if (clientName.isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osQuotationsCreateTitle.tr,
          AppLocaleKeys.osInvoicesClientName.tr,
        );
        return;
      }
      resolvedClientId = '';
      resolvedContact = OsClientContactDraft(
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
    } else {
      linkedClient = _selectedClient();
      if (linkedClient == null) {
        OsSnackbar.error(
          AppLocaleKeys.osQuotationsCreateTitle.tr,
          AppLocaleKeys.osQuotationsErrorNoClient.tr,
        );
        return;
      }
      resolvedClientId = linkedClient.id!;
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
      clientName = (linkedClient.name ?? linkedClient.email ?? linkedClient.id!)
          .trim();
    }

    final normalizedPhone =
        normalizeWhatsappPhone(resolvedContact.phone?.trim() ?? '');

    if (normalizedPhone == null || normalizedPhone.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osQuotationsCreateTitle.tr,
        AppLocaleKeys.commonPhoneInvalid.tr,
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
      if (linkedClient != null) {
        final fillOk = await home.fillEmptyClientContact(
          client: linkedClient,
          draft: _contactDraftFromControllers(linkedClient),
          fields: kOsFinanceDocumentContactFields,
        );
        if (!fillOk) return;
      }

      final now = DateTime.now();
      final existing = widget.existing;
      final discount =
          double.tryParse(_discountCtrl.text.trim().replaceAll(',', '')) ?? 0;
      final ok = await finance.saveQuotation(
        OsQuotationModel(
          id: existing?.id,
          displayNumber: existing?.displayNumber,
          clientId: resolvedClientId,
          clientName: clientName,
          clientPhone: normalizedPhone,
          clientEmail: resolvedContact.email?.trim().isEmpty ?? true
              ? null
              : resolvedContact.email!.trim(),
          clientAddress: resolvedContact.address?.trim().isEmpty ?? true
              ? null
              : resolvedContact.address!.trim(),
          date: existing?.date ?? OsFinanceFormat.ymd(now),
          expiryDate: OsFinanceFormat.ymd(_expiry),
          status: _status,
          amount: _lines.subtotal,
          discount: discount < 0 ? 0 : discount,
          vat: _lines.vat,
          total: OsQuotationModel.computeTotal(
            amount: _lines.subtotal,
            discount: discount < 0 ? 0 : discount,
            vat: _lines.vat,
          ),
          items: items,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
    final linkedClient = _selectedClient();
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(AppLocaleKeys.osQuotationsClient.tr),
                    DropdownButtonFormField<String>(
                      initialValue: osIsCustomClientId(_clientId)
                          ? kOsCustomClientId
                          : (clients.any((c) => c.id == _clientId)
                              ? _clientId
                              : null),
                      decoration: osDialogFieldDecoration(
                        context,
                        hint: AppLocaleKeys.osQuotationsClientHint.tr,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: kOsCustomClientId,
                          child: Text(
                            AppLocaleKeys.osQuotationsCustomClient.tr,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
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
                      onChanged: (v) {
                        setState(() => _clientId = v);
                        _applyClientContact(v);
                      },
                    ),
                    if (osIsCustomClientId(_clientId)) ...[
                      const SizedBox(height: 12),
                      _label(AppLocaleKeys.osInvoicesClientName.tr),
                      osTypedTextFormField(
                        controller: _customNameCtrl,
                        decoration: osDialogFieldDecoration(context),
                      ),
                    ],
                    if (osShowClientContactField(
                      client: linkedClient,
                      field: OsClientContactField.phone,
                      fields: kOsFinanceDocumentContactFields,
                    )) ...[
                      const SizedBox(height: 12),
                      _label(AppLocaleKeys.osInvoicesClientPhone.tr),
                      WhatsappPhoneField(
                        key: ValueKey(
                          'phone-${_clientId ?? 'custom'}-${_phoneCtrl.text}',
                        ),
                        initialNormalized: _phoneCtrl.text.trim().isEmpty
                            ? null
                            : _phoneCtrl.text.trim(),
                        decoration: osClientContactFieldDecoration(
                          osDialogFieldDecoration(context),
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
                      const SizedBox(height: 12),
                      _label(AppLocaleKeys.osInvoicesClientEmail.tr),
                      osTypedTextFormField(
                        controller: _emailCtrl,
                        decoration: osClientContactFieldDecoration(
                          osDialogFieldDecoration(context),
                          savesToClient: linkedClient != null,
                        ),
                      ),
                    ],
                    if (osShowClientContactField(
                      client: linkedClient,
                      field: OsClientContactField.address,
                      fields: kOsFinanceDocumentContactFields,
                    )) ...[
                      const SizedBox(height: 12),
                      _label(AppLocaleKeys.osInvoicesClientAddress.tr),
                      osTypedTextFormField(
                        controller: _addressCtrl,
                        decoration: osClientContactFieldDecoration(
                          osDialogFieldDecoration(context),
                          savesToClient: linkedClient != null,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _label(AppLocaleKeys.osQuotationsApprovalStatus.tr),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: osDialogFieldDecoration(context),
                      items: osQuotationStatusDropdownItems(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _status = v);
                      },
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
                    OsLineItemsEditor(
                      controller: _lines,
                      titleKey: AppLocaleKeys.osQuotationsItems,
                    ),
                    const SizedBox(height: 12),
                    _label(AppLocaleKeys.osInvoicesDiscount.tr),
                    osTypedTextFormField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: osDialogFieldDecoration(context),
                    ),
                    const SizedBox(height: 12),
                    _label(AppLocaleKeys.osInvoicesNotes.tr),
                    osTypedTextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: osDialogFieldDecoration(context),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
