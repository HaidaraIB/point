import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsContractClause.dart';
import 'package:point/Models/Os/OsContractTemplate.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

Future<void> showOsLegalContractFormDialog(
  BuildContext context, {
  OsLegalContractModel? existing,
  OsContractTemplate? template,
  String? initialClientId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OsLegalContractFormDialog(
      existing: existing,
      template: template,
      initialClientId: initialClientId,
    ),
  );
}

class _OsLegalContractFormDialog extends StatefulWidget {
  const _OsLegalContractFormDialog({
    this.existing,
    this.template,
    this.initialClientId,
  });

  final OsLegalContractModel? existing;
  final OsContractTemplate? template;
  final String? initialClientId;

  @override
  State<_OsLegalContractFormDialog> createState() =>
      _OsLegalContractFormDialogState();
}

class _OsLegalContractFormDialogState extends State<_OsLegalContractFormDialog> {
  final _ctrl = Get.find<OsLegalContractsController>();
  late final TextEditingController _numberCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _targetNameCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _governingLawCtrl;
  late final TextEditingController _jurisdictionCtrl;
  late final TextEditingController _notesCtrl;
  late String _targetType;
  late String _status;
  late String _currency;
  String? _clientId;
  late DateTime _startDate;
  DateTime? _endDate;
  late List<OsContractClause> _clauses;
  var _saving = false;
  var _loadingNumber = false;

  List<ClientModel> get _clients {
    return Get.find<HomeController>()
        .clients
        .where((c) => (c.id ?? '').isNotEmpty)
        .toList();
  }

  String? _resolveClientDropdownValue(String? raw) {
    final id = raw?.trim();
    if (id == null || id.isEmpty) return null;
    if (!_clients.any((c) => c.id == id)) return null;
    return id;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final tpl = widget.template;
    final settings = _ctrl.settings.value;

    _targetType = e?.targetType ??
        tpl?.targetType ??
        OsLegalContractTargetType.client;
    if (!OsLegalContractTargetType.ordered.contains(_targetType)) {
      _targetType = OsLegalContractTargetType.client;
    }
    _status = e?.status ?? OsLegalContractStatus.draft;
    if (!OsLegalContractStatus.ordered.contains(_status)) {
      _status = OsLegalContractStatus.draft;
    }
    _currency = e?.currency ?? OsLegalContractCurrency.iqd;
    if (!OsLegalContractCurrency.ordered.contains(_currency)) {
      _currency = OsLegalContractCurrency.iqd;
    }
    _clientId = _resolveClientDropdownValue(
      widget.initialClientId ?? e?.targetId,
    );
    _startDate = e?.startDate ?? DateTime.now();
    if (e?.endDate != null) {
      _endDate = e!.endDate;
    } else if (tpl?.defaultDurationMonths != null) {
      _endDate = DateTime(
        _startDate.year,
        _startDate.month + tpl!.defaultDurationMonths!,
        _startDate.day,
      );
    }
    _clauses = e != null
        ? List<OsContractClause>.from(e.clauses)
        : tpl != null
            ? tpl.clauses
                .map(
                  (c) => OsContractClause(
                    id: c.id,
                    title: c.title,
                    content: c.content,
                    isMandatory: c.isMandatory,
                    isEnabled: c.isEnabled,
                  ),
                )
                .toList()
            : <OsContractClause>[];

    _numberCtrl = TextEditingController(text: e?.contractNumber ?? '');
    _titleCtrl = TextEditingController(
      text: e?.title ?? tpl?.suggestedTitle ?? tpl?.name ?? '',
    );
    _targetNameCtrl = TextEditingController(text: e?.targetName ?? '');
    _valueCtrl = TextEditingController(
      text: e != null && e.totalValue > 0
          ? e.totalValue.toStringAsFixed(0)
          : '',
    );
    _governingLawCtrl = TextEditingController(
      text: e?.governingLaw ?? settings.defaultCivilLawRef,
    );
    _jurisdictionCtrl = TextEditingController(
      text: e?.jurisdiction ?? settings.defaultJurisdiction,
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');

    if (e == null && _numberCtrl.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNumber());
    }
    if (e == null && _clientId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyClient(_clientId));
    }
  }

  Future<void> _loadNumber() async {
    setState(() => _loadingNumber = true);
    try {
      final n = await _ctrl.generateContractNumber();
      if (mounted) _numberCtrl.text = n;
    } finally {
      if (mounted) setState(() => _loadingNumber = false);
    }
  }

  void _applyClient(String? clientId) {
    if (clientId == null) return;
    ClientModel? client;
    for (final c in _clients) {
      if (c.id == clientId) {
        client = c;
        break;
      }
    }
    if (client == null) return;
    final company = (client.company ?? '').trim();
    _targetNameCtrl.text =
        company.isNotEmpty ? company : (client.name ?? '').trim();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _titleCtrl.dispose();
    _targetNameCtrl.dispose();
    _valueCtrl.dispose();
    _governingLawCtrl.dispose();
    _jurisdictionCtrl.dispose();
    _notesCtrl.dispose();
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

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final number = _numberCtrl.text.trim();
    final targetName = _targetNameCtrl.text.trim();
    if (title.isEmpty || number.isEmpty || targetName.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osLegalContractTitle.tr,
        AppLocaleKeys.osLegalContractErrorRequired.tr,
      );
      return;
    }
    final value = double.tryParse(_valueCtrl.text.replaceAll(',', '')) ?? 0;

    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final ok = await _ctrl.saveContract(
        OsLegalContractModel(
          id: existing?.id ?? '',
          contractNumber: number,
          title: title,
          targetType: _targetType,
          targetId: _clientId ?? '',
          targetName: targetName,
          status: _status,
          startDate: _startDate,
          endDate: _endDate,
          totalValue: value,
          currency: _currency,
          governingLaw: _governingLawCtrl.text.trim(),
          jurisdiction: _jurisdictionCtrl.text.trim(),
          clauses: _clauses.where((c) => c.isEnabled).toList(),
          notes: _notesCtrl.text.trim(),
          signedAt: existing?.signedAt,
          createdAt: existing?.createdAt,
          createdBy: existing?.createdBy,
        ),
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          OsSnackbar.success(
            AppLocaleKeys.osLegalContractTitle.tr,
            AppLocaleKeys.osLegalContractSaved.tr,
          );
        });
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osLegalContractTitle.tr,
          AppLocaleKeys.errorsOsLegalContractsSave.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final isEdit = widget.existing != null;

    return OsDialogFrame(
      title: isEdit
          ? AppLocaleKeys.osLegalContractEditTitle.tr
          : AppLocaleKeys.osLegalContractAddTitle.tr,
      icon: Icons.description_outlined,
      maxWidth: 720,
      closeEnabled: !_saving,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(AppLocaleKeys.osLegalContractNumber.tr),
          TextField(
            controller: _numberCtrl,
            readOnly: _loadingNumber,
            decoration: osDialogFieldDecoration(
              context,
              suffixText: _loadingNumber ? '…' : null,
            ),
          ),
          const SizedBox(height: 14),
          _label(AppLocaleKeys.osLegalContractFieldTitle.tr),
          TextField(
            controller: _titleCtrl,
            decoration: osDialogFieldDecoration(context),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(AppLocaleKeys.osLegalContractTargetType.tr),
                    DropdownButtonFormField<String>(
                      initialValue: _targetType,
                      decoration: osDialogFieldDecoration(context),
                      items: OsLegalContractTargetType.ordered
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(_targetTypeLabel(t)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _targetType = v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(AppLocaleKeys.osLegalContractStatus.tr),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: osDialogFieldDecoration(context),
                      items: OsLegalContractStatus.ordered
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(_statusLabel(s)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _status = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_targetType == OsLegalContractTargetType.client &&
              _clients.isNotEmpty) ...[
            const SizedBox(height: 14),
            _label(AppLocaleKeys.osLegalContractClient.tr),
            DropdownButtonFormField<String?>(
              initialValue: _clientId,
              decoration: osDialogFieldDecoration(context),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(AppLocaleKeys.osCommonNa.tr),
                ),
                ..._clients.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(
                      (c.company ?? '').trim().isNotEmpty
                          ? c.company!.trim()
                          : (c.name ?? ''),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _clientId = v;
                  _applyClient(v);
                });
              },
            ),
          ],
          const SizedBox(height: 14),
          _label(AppLocaleKeys.osLegalContractPartyName.tr),
          TextField(
            controller: _targetNameCtrl,
            decoration: osDialogFieldDecoration(context),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(AppLocaleKeys.osLegalContractStart.tr),
                    InkWell(
                      onTap: () => _pickDate(true),
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: osDialogFieldDecoration(
                          context,
                          prefixIcon: Icon(
                            Icons.event_outlined,
                            size: 20,
                            color: theme.mutedText,
                          ),
                        ),
                        child: Text(
                          FirestoreOsFinanceApi.formatDate(_startDate),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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
                    _label(AppLocaleKeys.osLegalContractEnd.tr),
                    InkWell(
                      onTap: () => _pickDate(false),
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: osDialogFieldDecoration(
                          context,
                          prefixIcon: Icon(
                            Icons.event_outlined,
                            size: 20,
                            color: theme.mutedText,
                          ),
                        ),
                        child: Text(
                          _endDate == null
                              ? AppLocaleKeys.osCommonNa.tr
                              : FirestoreOsFinanceApi.formatDate(_endDate!),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(AppLocaleKeys.osLegalContractValue.tr),
                    TextField(
                      controller: _valueCtrl,
                      keyboardType: TextInputType.number,
                      decoration: osDialogFieldDecoration(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(AppLocaleKeys.osLegalContractCurrency.tr),
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: osDialogFieldDecoration(context),
                      items: OsLegalContractCurrency.ordered
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _currency = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _label(AppLocaleKeys.osLegalContractGoverningLaw.tr),
          TextField(
            controller: _governingLawCtrl,
            maxLines: 2,
            decoration: osDialogFieldDecoration(context),
          ),
          const SizedBox(height: 14),
          _label(AppLocaleKeys.osLegalContractJurisdiction.tr),
          TextField(
            controller: _jurisdictionCtrl,
            maxLines: 2,
            decoration: osDialogFieldDecoration(context),
          ),
          if (_clauses.isNotEmpty) ...[
            const SizedBox(height: 16),
            _label(AppLocaleKeys.osLegalContractClauses.tr),
            for (var i = 0; i < _clauses.length; i++)
              _ClauseTile(
                clause: _clauses[i],
                onToggle: (enabled) {
                  setState(() {
                    _clauses[i] = _clauses[i].copyWith(isEnabled: enabled);
                  });
                },
              ),
          ],
          const SizedBox(height: 14),
          _label(AppLocaleKeys.osLegalContractNotes.tr),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: osDialogFieldDecoration(context),
          ),
          const SizedBox(height: 20),
          OsFormDialogActions(
            saveLabel: AppLocaleKeys.osLegalContractSave.tr,
            saving: _saving,
            onSave: _save,
            onCancel: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _targetTypeLabel(String t) {
    switch (t) {
      case OsLegalContractTargetType.client:
        return AppLocaleKeys.osLegalContractTargetClient.tr;
      case OsLegalContractTargetType.employee:
        return AppLocaleKeys.osLegalContractTargetEmployee.tr;
      default:
        return AppLocaleKeys.osLegalContractTargetFreelancer.tr;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case OsLegalContractStatus.active:
        return AppLocaleKeys.osLegalContractStatusActive.tr;
      case OsLegalContractStatus.pendingSignature:
        return AppLocaleKeys.osLegalContractStatusPending.tr;
      case OsLegalContractStatus.draft:
        return AppLocaleKeys.osLegalContractStatusDraft.tr;
      case OsLegalContractStatus.expired:
        return AppLocaleKeys.osLegalContractStatusExpired.tr;
      default:
        return AppLocaleKeys.osLegalContractStatusTerminated.tr;
    }
  }
}

class _ClauseTile extends StatelessWidget {
  const _ClauseTile({required this.clause, required this.onToggle});

  final OsContractClause clause;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    clause.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: theme.primaryText,
                    ),
                  ),
                ),
                Switch(
                  value: clause.isEnabled,
                  onChanged: clause.isMandatory ? null : onToggle,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              clause.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: theme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
