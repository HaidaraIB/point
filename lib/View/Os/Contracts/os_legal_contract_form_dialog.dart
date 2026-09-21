import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_template_form_dialog.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/Os/OsContractClause.dart';
import 'package:point/Models/Os/OsContractPaymentTerm.dart';
import 'package:point/Models/Os/OsContractSettings.dart';
import 'package:point/Models/Os/OsContractTemplate.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/os_ai_service.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_status_widgets.dart';
import 'package:point/Utils/text_input_bidi.dart';
import 'package:point/View/Os/os_ai_generate_button.dart';
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
    builder: (_) => _OsLegalContractDrafterDialog(
      existing: existing,
      template: template,
      initialClientId: initialClientId,
    ),
  );
}

class _OsLegalContractDrafterDialog extends StatefulWidget {
  const _OsLegalContractDrafterDialog({
    this.existing,
    this.template,
    this.initialClientId,
  });

  final OsLegalContractModel? existing;
  final OsContractTemplate? template;
  final String? initialClientId;

  @override
  State<_OsLegalContractDrafterDialog> createState() =>
      _OsLegalContractDrafterDialogState();
}

class _OsLegalContractDrafterDialogState
    extends State<_OsLegalContractDrafterDialog> {
  final _ctrl = Get.find<OsLegalContractsController>();
  static const _totalSteps = 4;

  late int _step;
  late String _targetType;
  late String _status;
  late String _currency;
  late String? _selectedTemplateId;
  late String? _partyTwoSourceId;
  late DateTime _startDate;
  DateTime? _endDate;
  late List<OsContractClause> _clauses;
  late List<OsContractPaymentTerm> _paymentTerms;

  late final TextEditingController _numberCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _partyTwoNameCtrl;
  late final TextEditingController _partyTwoCompanyCtrl;
  late final TextEditingController _partyTwoNationalIdCtrl;
  late final TextEditingController _partyTwoAddressCtrl;
  late final TextEditingController _partyTwoPhoneCtrl;
  late final TextEditingController _partyTwoEmailCtrl;
  late final TextEditingController _partyTwoJobTitleCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _penaltyCtrl;
  late final TextEditingController _probationCtrl;
  late final TextEditingController _noticeCtrl;
  late final TextEditingController _governingLawCtrl;
  late final TextEditingController _jurisdictionCtrl;
  late final TextEditingController _scopeCtrl;
  late final TextEditingController _customTermsCtrl;

  var _saving = false;
  var _loadingNumber = false;
  String? _loadingAiKey;

  List<ClientModel> get _clients => Get.find<HomeController>()
      .clients
      .where((c) => (c.id ?? '').isNotEmpty)
      .toList();

  List<EmployeeModel> get _employees => Get.find<HomeController>()
      .employees
      .where((e) => (e.id ?? '').isNotEmpty)
      .toList();

  OsContractSettings get _settings => _ctrl.settings.value;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final tpl = widget.template;
    final settings = _settings;

    _step = e != null
        ? 2
        : (tpl != null || widget.initialClientId != null ? 2 : 1);

    _targetType = e?.targetType ??
        tpl?.targetType ??
        OsLegalContractTargetType.client;
    _status = e?.status ?? OsLegalContractStatus.draft;
    _currency = e?.currency ?? OsLegalContractCurrency.iqd;
    _selectedTemplateId = e?.templateId ?? tpl?.id;
    _partyTwoSourceId = e?.targetId.isNotEmpty == true
        ? e!.targetId
        : widget.initialClientId;

    _startDate = e?.startDate ?? DateTime.now();
    if (e?.endDate != null) {
      _endDate = e!.endDate;
    } else if (tpl?.defaultDurationMonths != null) {
      _endDate = DateTime(
        _startDate.year,
        _startDate.month + tpl!.defaultDurationMonths!,
        _startDate.day,
      );
    } else {
      _endDate = DateTime(
        _startDate.year,
        _startDate.month + 6,
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

    final totalValue = e?.totalValue ?? 6000000;
    _paymentTerms = e != null && e.paymentTerms.isNotEmpty
        ? List<OsContractPaymentTerm>.from(e.paymentTerms)
        : OsContractPaymentTerm.defaultClientSchedule(totalValue);

    _numberCtrl = TextEditingController(text: e?.contractNumber ?? '');
    _titleCtrl = TextEditingController(
      text: e?.title ??
          tpl?.suggestedTitle ??
          tpl?.name ??
          AppLocaleKeys.osLegalContractAdd.tr,
    );
    _partyTwoNameCtrl = TextEditingController(text: e?.targetName ?? '');
    _partyTwoCompanyCtrl =
        TextEditingController(text: e?.partyTwoCompany ?? '');
    _partyTwoNationalIdCtrl =
        TextEditingController(text: e?.partyTwoNationalId ?? '');
    _partyTwoAddressCtrl = TextEditingController(
      text: e?.partyTwoAddress.isNotEmpty == true
          ? e!.partyTwoAddress
          : 'بغداد - جمهورية العراق',
    );
    _partyTwoPhoneCtrl =
        TextEditingController(text: e?.partyTwoPhone ?? '');
    _partyTwoEmailCtrl =
        TextEditingController(text: e?.partyTwoEmail ?? '');
    _partyTwoJobTitleCtrl =
        TextEditingController(text: e?.partyTwoJobTitle ?? '');
    _valueCtrl = TextEditingController(
      text: totalValue > 0 ? totalValue.toStringAsFixed(0) : '',
    );
    _salaryCtrl = TextEditingController(
      text: e?.salaryMonthly != null && e!.salaryMonthly! > 0
          ? e.salaryMonthly!.toStringAsFixed(0)
          : '',
    );
    _penaltyCtrl = TextEditingController(
      text: (e?.penaltyDailyRate ?? settings.defaultLatePenaltyRate)
          .toString(),
    );
    _probationCtrl = TextEditingController(
      text: '${e?.probationPeriodDays ?? (_targetType == OsLegalContractTargetType.employee ? settings.defaultProbationDays : 0)}',
    );
    _noticeCtrl = TextEditingController(
      text: '${e?.noticePeriodDays ?? 30}',
    );
    _governingLawCtrl = TextEditingController(
      text: e?.governingLaw ??
          tpl?.governingLaw ??
          settings.defaultCivilLawRef,
    );
    _jurisdictionCtrl = TextEditingController(
      text: e?.jurisdiction ??
          (_targetType == OsLegalContractTargetType.employee
              ? 'محكمة عمل بغداد المختصة'
              : settings.defaultJurisdiction),
    );
    _scopeCtrl = TextEditingController(
      text: e?.scopeOfWork.isNotEmpty == true
          ? e!.scopeOfWork
          : 'تقديم خدمات الإنتاج والتسويق الرقمي وإدارة الحملات الإعلانية وصناعة المحتوى الإبداعي وفق المواصفات المعتمدة.',
    );
    _customTermsCtrl =
        TextEditingController(text: e?.customTerms ?? '');

    if (e == null && _numberCtrl.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNumber());
    }
    if (e == null && _partyTwoSourceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_targetType == OsLegalContractTargetType.employee) {
          _applyEmployee(_partyTwoSourceId);
        } else {
          _applyClient(_partyTwoSourceId);
        }
      });
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _titleCtrl.dispose();
    _partyTwoNameCtrl.dispose();
    _partyTwoCompanyCtrl.dispose();
    _partyTwoNationalIdCtrl.dispose();
    _partyTwoAddressCtrl.dispose();
    _partyTwoPhoneCtrl.dispose();
    _partyTwoEmailCtrl.dispose();
    _partyTwoJobTitleCtrl.dispose();
    _valueCtrl.dispose();
    _salaryCtrl.dispose();
    _penaltyCtrl.dispose();
    _probationCtrl.dispose();
    _noticeCtrl.dispose();
    _governingLawCtrl.dispose();
    _jurisdictionCtrl.dispose();
    _scopeCtrl.dispose();
    _customTermsCtrl.dispose();
    super.dispose();
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
    final client = _clients.cast<ClientModel?>().firstWhere(
          (c) => c?.id == clientId,
          orElse: () => null,
        );
    if (client == null) return;
    _partyTwoNameCtrl.text = (client.name ?? '').trim();
    _partyTwoCompanyCtrl.text = (client.company ?? '').trim();
    _partyTwoPhoneCtrl.text = (client.phone ?? '').trim();
    _partyTwoEmailCtrl.text = (client.email ?? '').trim();
    _partyTwoAddressCtrl.text =
        (client.address ?? '').trim().isNotEmpty
            ? client.address!.trim()
            : _partyTwoAddressCtrl.text;
    _partyTwoNationalIdCtrl.text = client.id ?? '';
  }

  void _applyEmployee(String? employeeId) {
    if (employeeId == null) return;
    final employee = _employees.cast<EmployeeModel?>().firstWhere(
          (e) => e?.id == employeeId,
          orElse: () => null,
        );
    if (employee == null) return;
    _partyTwoNameCtrl.text = (employee.name ?? '').trim();
    _partyTwoJobTitleCtrl.text = (employee.jobTitle ?? '').trim();
    _partyTwoPhoneCtrl.text = (employee.phone ?? '').trim();
    _partyTwoEmailCtrl.text = (employee.email ?? '').trim();
    final salary = employee.salary ?? 1500000;
    _salaryCtrl.text = salary.toStringAsFixed(0);
    _valueCtrl.text = (salary * 12).toStringAsFixed(0);
    _recalcPaymentAmounts();
  }

  void _selectTemplate(OsContractTemplate tpl) {
    setState(() {
      _selectedTemplateId = tpl.id;
      _targetType = tpl.targetType;
      _titleCtrl.text = tpl.suggestedTitle.isNotEmpty
          ? tpl.suggestedTitle
          : tpl.name;
      _governingLawCtrl.text = tpl.governingLaw.isNotEmpty
          ? tpl.governingLaw
          : _settings.defaultCivilLawRef;
      _clauses = tpl.clauses
          .map(
            (c) => OsContractClause(
              id: c.id,
              title: c.title,
              content: c.content,
              isMandatory: c.isMandatory,
              isEnabled: c.isEnabled,
            ),
          )
          .toList();
      if (tpl.defaultDurationMonths != null) {
        _endDate = DateTime(
          _startDate.year,
          _startDate.month + tpl.defaultDurationMonths!,
          _startDate.day,
        );
      }
      if (tpl.targetType == OsLegalContractTargetType.employee) {
        _probationCtrl.text = '${_settings.defaultProbationDays}';
        _jurisdictionCtrl.text = 'محكمة عمل بغداد المختصة';
      } else {
        _probationCtrl.text = '0';
        _jurisdictionCtrl.text = _settings.defaultJurisdiction;
      }
    });
  }

  double get _totalValue =>
      double.tryParse(_valueCtrl.text.replaceAll(',', '')) ?? 0;

  void _recalcPaymentAmounts() {
    final total = _totalValue;
    _paymentTerms = _paymentTerms
        .map(
          (p) => p.copyWith(
            amount: ((total * p.percentage) / 100).roundToDouble(),
          ),
        )
        .toList();
  }

  void _onTotalValueChanged(String raw) {
    _recalcPaymentAmounts();
    setState(() {});
  }

  OsAiContractInput _contractAiInput({String? clauseTitle, String? clauseContent}) {
    final tpl = _ctrl.templateById(_selectedTemplateId);
    final templateDescription = _scopeCtrl.text.trim().isNotEmpty
        ? _scopeCtrl.text.trim()
        : (tpl?.description ?? '');
    var durationMonths = tpl?.defaultDurationMonths ?? 0;
    if (_endDate != null) {
      final months = ((_endDate!.difference(_startDate).inDays) / 30).round();
      if (months > 0) durationMonths = months;
    }
    return OsAiContractInput(
      contractTitle: _titleCtrl.text.trim(),
      targetType: _targetType,
      targetName: _partyTwoNameCtrl.text.trim(),
      templateTitle: tpl?.suggestedTitle.trim().isNotEmpty == true
          ? tpl!.suggestedTitle
          : (tpl?.name ?? ''),
      totalValue: _totalValue,
      currency: _currency,
      clauseTitle: clauseTitle ?? '',
      clauseContent: clauseContent ?? '',
      startDate: FirestoreOsFinanceApi.formatDate(_startDate),
      endDate: _endDate == null
          ? ''
          : FirestoreOsFinanceApi.formatDate(_endDate!),
      templateDescription: templateDescription,
      subType: tpl?.subType ?? '',
      defaultDurationMonths: durationMonths,
      governingLaw: _governingLawCtrl.text.trim(),
      customTerms: _customTermsCtrl.text.trim(),
      jurisdiction: _jurisdictionCtrl.text.trim(),
    );
  }

  Future<bool> _confirmReplaceClauses() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppLocaleKeys.osLegalContractGenerateClausesConfirmTitle.tr,
        ),
        content: Text(
          AppLocaleKeys.osLegalContractGenerateClausesConfirmMessage.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocaleKeys.commonCancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocaleKeys.commonConfirm.tr),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _generateAllClauses() async {
    if (_loadingAiKey != null) return;
    if (!await _confirmReplaceClauses()) return;

    setState(() => _loadingAiKey = 'clauses-all');
    try {
      final drafts = await OsAiService.instance.generateContractClauses(
        input: _contractAiInput(),
      );
      if (!mounted) return;
      final ts = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _clauses = drafts
            .asMap()
            .entries
            .map(
              (e) => OsContractClause(
                id: 'c-ai-$ts-${e.key}',
                title: e.value.title,
                content: e.value.content,
              ),
            )
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loadingAiKey = null);
    }
  }

  Future<void> _generateContractTitle() async {
    if (_loadingAiKey != null) return;
    setState(() => _loadingAiKey = 'title');
    try {
      final text = await OsAiService.instance.generateContractTitle(
        input: _contractAiInput(),
      );
      if (mounted) _titleCtrl.text = text;
    } finally {
      if (mounted) setState(() => _loadingAiKey = null);
    }
  }

  Future<void> _generateContractScope() async {
    if (_loadingAiKey != null) return;
    setState(() => _loadingAiKey = 'scope');
    try {
      final text = await OsAiService.instance.generateContractScope(
        input: _contractAiInput(),
      );
      if (mounted) _scopeCtrl.text = text;
    } finally {
      if (mounted) setState(() => _loadingAiKey = null);
    }
  }

  Future<void> _generateGoverningLaw() async {
    if (_loadingAiKey != null) return;
    setState(() => _loadingAiKey = 'governing-law');
    try {
      final text = await OsAiService.instance.generateContractGoverningLaw(
        input: _contractAiInput(),
      );
      if (mounted) _governingLawCtrl.text = text;
    } finally {
      if (mounted) setState(() => _loadingAiKey = null);
    }
  }

  Future<void> _generateCustomTerms() async {
    if (_loadingAiKey != null) return;
    setState(() => _loadingAiKey = 'custom-terms');
    try {
      final text = await OsAiService.instance.generateContractCustomTerms(
        input: _contractAiInput(),
      );
      if (mounted) _customTermsCtrl.text = text;
    } finally {
      if (mounted) setState(() => _loadingAiKey = null);
    }
  }

  Future<void> _generateJurisdiction() async {
    if (_loadingAiKey != null) return;
    setState(() => _loadingAiKey = 'jurisdiction');
    try {
      final text = await OsAiService.instance.generateContractJurisdiction(
        input: _contractAiInput(),
      );
      if (mounted) _jurisdictionCtrl.text = text;
    } finally {
      if (mounted) setState(() => _loadingAiKey = null);
    }
  }

  Future<void> _generatePaymentSchedule() async {
    if (_loadingAiKey != null) return;
    setState(() => _loadingAiKey = 'payment-schedule');
    try {
      final terms = await OsAiService.instance.generateContractPaymentSchedule(
        input: _contractAiInput(),
        totalValue: _totalValue,
      );
      if (mounted) {
        setState(() => _paymentTerms = terms);
      }
    } finally {
      if (mounted) setState(() => _loadingAiKey = null);
    }
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

  bool _validateStep(int step) {
    if (step == 1 && (_selectedTemplateId == null || _selectedTemplateId!.isEmpty)) {
      OsSnackbar.error(
        AppLocaleKeys.osLegalContractTitle.tr,
        AppLocaleKeys.osLegalContractErrorRequired.tr,
      );
      return false;
    }
    if (step == 2) {
      if (_titleCtrl.text.trim().isEmpty ||
          _numberCtrl.text.trim().isEmpty ||
          _partyTwoNameCtrl.text.trim().isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osLegalContractTitle.tr,
          AppLocaleKeys.osLegalContractErrorRequired.tr,
        );
        return false;
      }
    }
    return true;
  }

  void _goNext() {
    if (!_validateStep(_step)) return;
    if (_step < _totalSteps) setState(() => _step++);
  }

  void _goPrevious() {
    if (_step > 1) setState(() => _step--);
  }

  Future<void> _save() async {
    if (!_validateStep(2)) {
      setState(() => _step = 2);
      return;
    }
    final settings = _settings;
    final existing = widget.existing;
    final value = _totalValue;
    final signedAt = _status == OsLegalContractStatus.active
        ? (existing?.signedAt ?? DateTime.now())
        : existing?.signedAt;
    final emp = Get.find<HomeController>().effectiveEmployee;

    setState(() => _saving = true);
    try {
      final ok = await _ctrl.saveContract(
        OsLegalContractModel(
          id: existing?.id ?? '',
          contractNumber: _numberCtrl.text.trim(),
          title: _titleCtrl.text.trim(),
          targetType: _targetType,
          targetId: _partyTwoSourceId ?? '',
          targetName: _partyTwoNameCtrl.text.trim(),
          status: _status,
          startDate: _startDate,
          endDate: _endDate,
          totalValue: value,
          currency: _currency,
          governingLaw: _governingLawCtrl.text.trim(),
          jurisdiction: _jurisdictionCtrl.text.trim(),
          clauses: _clauses,
          templateId: _selectedTemplateId,
          partyOneName: settings.agencyLegalName,
          partyOneRep: settings.agencyAuthorizedSignatory,
          partyOneTitle: settings.agencySignatoryTitle,
          partyOneAddress: settings.agencyHeadquarters,
          partyOnePhone: settings.agencyPhone,
          partyOneEmail: settings.agencyEmail,
          partyOneRegistrationNo: settings.agencyCommercialReg,
          partyTwoCompany: _partyTwoCompanyCtrl.text.trim(),
          partyTwoNationalId: _partyTwoNationalIdCtrl.text.trim(),
          partyTwoAddress: _partyTwoAddressCtrl.text.trim(),
          partyTwoPhone: _partyTwoPhoneCtrl.text.trim(),
          partyTwoEmail: _partyTwoEmailCtrl.text.trim(),
          partyTwoJobTitle: _partyTwoJobTitleCtrl.text.trim(),
          probationPeriodDays: int.tryParse(_probationCtrl.text.trim()),
          noticePeriodDays: int.tryParse(_noticeCtrl.text.trim()),
          salaryMonthly: double.tryParse(_salaryCtrl.text.replaceAll(',', '')),
          penaltyDailyRate: double.tryParse(_penaltyCtrl.text.trim()),
          paymentTerms: _paymentTerms,
          scopeOfWork: _scopeCtrl.text.trim(),
          customTerms: _customTermsCtrl.text.trim(),
          signedAt: signedAt,
          createdAt: existing?.createdAt,
          createdBy: existing?.createdBy ?? emp?.id,
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

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxH = size.height * (narrow ? 0.94 : 0.9) - viewInsets.bottom;
    final isEdit = widget.existing != null;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 8 : 24,
        vertical: narrow ? 12 : 24,
      ),
      backgroundColor: theme.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 960,
            maxHeight: maxH.clamp(320, size.height),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(theme, isEdit),
              _buildStepper(theme),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _buildStepBody(theme),
                ),
              ),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeExtension theme, bool isEdit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.border)),
        color: theme.elevatedSurface.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.balance, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit
                      ? AppLocaleKeys.osLegalContractEditTitle.tr
                      : AppLocaleKeys.osLegalContractWizardTitle.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: theme.primaryText,
                  ),
                ),
                Text(
                  AppLocaleKeys.osLegalContractWizardSubtitle.tr,
                  style: TextStyle(fontSize: 11, color: theme.mutedText),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: Icon(Icons.close, color: theme.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(AppThemeExtension theme) {
    final steps = [
      AppLocaleKeys.osLegalContractStepTemplate.tr,
      AppLocaleKeys.osLegalContractStepParties.tr,
      AppLocaleKeys.osLegalContractStepFinancials.tr,
      AppLocaleKeys.osLegalContractStepClauses.tr,
    ];
    final narrow = MediaQuery.sizeOf(context).width < 600;

    final stepOfLabel = Text(
      AppLocaleKeys.osLegalContractStepOf.trParams({
        'step': '$_step',
        'total': '$_totalSteps',
      }),
      style: TextStyle(
        fontSize: 11,
        fontFamily: 'monospace',
        color: theme.mutedText,
      ),
    );

    final pills = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('/', style: TextStyle(color: theme.border)),
              ),
            _stepPill(theme, i + 1, steps[i], compact: narrow),
          ],
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.border)),
        color: theme.elevatedSurface.withValues(alpha: 0.35),
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: stepOfLabel,
                ),
                const SizedBox(height: 8),
                pills,
              ],
            )
          : Row(
              children: [
                Expanded(child: pills),
                const SizedBox(width: 12),
                stepOfLabel,
              ],
            ),
    );
  }

  Widget _stepPill(
    AppThemeExtension theme,
    int stepNum,
    String label, {
    bool compact = false,
  }) {
    final active = _step == stepNum;
    final showLabel = !compact || active;
    return Material(
      color: active ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _saving ? null : () => setState(() => _step = stepNum),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 10 : 8,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : theme.border,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$stepNum',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : theme.secondaryText,
                  ),
                ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : theme.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody(AppThemeExtension theme) {
    switch (_step) {
      case 1:
        return _buildStep1(theme);
      case 2:
        return _buildStep2(theme);
      case 3:
        return _buildStep3(theme);
      case 4:
        return _buildStep4(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1(AppThemeExtension theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackHeader = constraints.maxWidth < 600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stackHeader) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocaleKeys.osLegalContractTemplateHelp.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocaleKeys.osLegalContractTemplateLawNote.tr,
                    style: TextStyle(fontSize: 12, color: theme.mutedText),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _categoryPills(theme),
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleKeys.osLegalContractTemplateHelp.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocaleKeys.osLegalContractTemplateLawNote.tr,
                          style: TextStyle(fontSize: 12, color: theme.mutedText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _categoryPills(theme),
                ],
              ),
            const SizedBox(height: 16),
            Obx(() {
              final templates = _ctrl.templates
                  .where((t) => t.targetType == _targetType)
                  .toList();
              return LayoutBuilder(
                builder: (context, c) {
                  final twoCol = c.maxWidth >= 700;
                  const spacing = 12.0;
                  final itemWidth =
                      twoCol ? (c.maxWidth - spacing) / 2 : c.maxWidth;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final tpl in templates)
                        SizedBox(
                          width: itemWidth,
                          child: _templateCard(
                            theme,
                            tpl,
                            _selectedTemplateId == tpl.id,
                          ),
                        ),
                      SizedBox(
                        width: itemWidth,
                        child: _addTemplateCard(theme),
                      ),
                    ],
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  Widget _addTemplateCard(AppThemeExtension theme) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.border,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final saved = await showOsLegalContractTemplateFormDialog(
            context,
            initialTargetType: _targetType,
          );
          if (saved != null && mounted) {
            _selectTemplate(saved);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 32,
                color: AppColors.primary,
              ),
              const SizedBox(height: 10),
              Text(
                AppLocaleKeys.osLegalContractAddTemplate.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: theme.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryPills(AppThemeExtension theme) {
    Widget pill(String type, String label) {
      final selected = _targetType == type;
      return Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() {
            _targetType = type;
            _selectedTemplateId = null;
          }),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : theme.secondaryText,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill(
            OsLegalContractTargetType.client,
            AppLocaleKeys.osLegalContractCategoryClients.tr,
          ),
          pill(
            OsLegalContractTargetType.employee,
            AppLocaleKeys.osLegalContractCategoryEmployees.tr,
          ),
          pill(
            OsLegalContractTargetType.freelancer,
            AppLocaleKeys.osLegalContractCategoryFreelancers.tr,
          ),
        ],
      ),
    );
  }

  Widget _templateCard(AppThemeExtension theme, OsContractTemplate tpl, bool selected) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : theme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.primary : theme.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _selectTemplate(tpl),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tpl.subType.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tpl.subType,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        Text(
                          tpl.suggestedTitle.isNotEmpty
                              ? tpl.suggestedTitle
                              : tpl.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: theme.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tpl.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: theme.secondaryText),
              ),
              const SizedBox(height: 8),
              Text(
                tpl.governingLaw,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: theme.secondaryText),
              ),
              Text(
                AppLocaleKeys.osLegalContractClausesCount.trParams({
                  'count': '${tpl.clauses.length}',
                }),
                style: TextStyle(fontSize: 10, color: theme.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2(AppThemeExtension theme) {
    final settings = _settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label(AppLocaleKeys.osLegalContractOfficialTitle.tr),
                  osTypedTextField(
                    controller: _titleCtrl,
                    decoration: osDialogFieldDecoration(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OsAiGenerateButton(
              isLoading: _loadingAiKey == 'title',
              onPressed:
                  _loadingAiKey != null ? null : _generateContractTitle,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _label(AppLocaleKeys.osLegalContractContractualNumber.tr),
        osTypedTextField(
          controller: _numberCtrl,
          readOnly: _loadingNumber,
          decoration: osDialogFieldDecoration(
            context,
            suffixText: _loadingNumber ? '…' : null,
          ),
        ),
        const SizedBox(height: 16),
        _partyOneBox(theme, settings),
        const SizedBox(height: 16),
        _partyTwoForm(theme),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _label(AppLocaleKeys.osLegalContractGoverningLaw.tr),
            ),
            OsAiGenerateButton(
              isLoading: _loadingAiKey == 'governing-law',
              onPressed:
                  _loadingAiKey != null ? null : _generateGoverningLaw,
            ),
          ],
        ),
        osTypedTextField(
          controller: _governingLawCtrl,
          maxLines: 2,
          decoration: osDialogFieldDecoration(context),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label(AppLocaleKeys.osLegalContractInitialStatus.tr),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: osDialogFieldDecoration(context),
                    items: osLegalContractStatusDropdownItems(),
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
      ],
    );
  }

  Widget _partyOneBox(AppThemeExtension theme, OsContractSettings settings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(14),
        color: theme.elevatedSurface.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleKeys.osLegalContractPartyOneTitle.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: theme.primaryText,
                  ),
                ),
              ),
              Text(
                AppLocaleKeys.osLegalContractPartyOneAuto.tr,
                style: TextStyle(fontSize: 10, color: theme.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(settings.agencyLegalName,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          Text(
            '${settings.agencyAuthorizedSignatory} — ${settings.agencySignatoryTitle}',
            style: TextStyle(fontSize: 11, color: theme.secondaryText),
          ),
          Text(
            settings.agencyHeadquarters,
            style: TextStyle(fontSize: 11, color: theme.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _partyTwoForm(AppThemeExtension theme) {
    final isEmployee = _targetType == OsLegalContractTargetType.employee;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocaleKeys.osLegalContractPartyTwoTitle.tr,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          if (isEmployee && _employees.isNotEmpty) ...[
            _label(AppLocaleKeys.osLegalContractQuickSelectEmployee.tr),
            DropdownButtonFormField<String?>(
              initialValue: _partyTwoSourceId,
              decoration: osDialogFieldDecoration(context),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(AppLocaleKeys.osCommonNa.tr),
                ),
                ..._employees.map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.id,
                    child: Text(e.name ?? '', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _partyTwoSourceId = v;
                  _applyEmployee(v);
                });
              },
            ),
            const SizedBox(height: 10),
          ] else if (!isEmployee && _clients.isNotEmpty) ...[
            _label(AppLocaleKeys.osLegalContractQuickSelectClient.tr),
            DropdownButtonFormField<String?>(
              initialValue: _partyTwoSourceId,
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
                  _partyTwoSourceId = v;
                  _applyClient(v);
                });
              },
            ),
            const SizedBox(height: 10),
          ],
          _label('${AppLocaleKeys.osLegalContractPartyName.tr} *'),
          osTypedTextField(
            controller: _partyTwoNameCtrl,
            decoration: osDialogFieldDecoration(context),
          ),
          const SizedBox(height: 10),
          _label(AppLocaleKeys.osLegalContractPartyCompany.tr),
          osTypedTextField(
            controller: _partyTwoCompanyCtrl,
            decoration: osDialogFieldDecoration(context),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(AppLocaleKeys.osLegalContractPartyNationalId.tr),
                    osTypedTextField(
                      controller: _partyTwoNationalIdCtrl,
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
                    _label(AppLocaleKeys.osLegalContractPartyPhone.tr),
                    osPhoneTextField(
                      controller: _partyTwoPhoneCtrl,
                      decoration: osDialogFieldDecoration(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _label(AppLocaleKeys.osLegalContractPartyEmail.tr),
          osTypedTextField(
            controller: _partyTwoEmailCtrl,
            decoration: osDialogFieldDecoration(context),
          ),
          const SizedBox(height: 10),
          if (isEmployee) ...[
            _label(AppLocaleKeys.osLegalContractPartyJobTitle.tr),
            osTypedTextField(
              controller: _partyTwoJobTitleCtrl,
              decoration: osDialogFieldDecoration(context),
            ),
            const SizedBox(height: 10),
          ],
          _label(AppLocaleKeys.osLegalContractPartyAddress.tr),
          osTypedTextField(
            controller: _partyTwoAddressCtrl,
            maxLines: 2,
            decoration: osDialogFieldDecoration(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(AppThemeExtension theme) {
    final isEmployee = _targetType == OsLegalContractTargetType.employee;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final percentSum =
        _paymentTerms.fold<double>(0, (s, p) => s + p.percentage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 640;

            Widget totalValueBlock() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(AppLocaleKeys.osLegalContractTotalValue.tr),
                    osTypedTextField(
                      controller: _valueCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: _onTotalValueChanged,
                      decoration: osDialogFieldDecoration(context),
                    ),
                  ],
                );

            Widget currencyBlock() => Column(
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
                              child: Text(c == OsLegalContractCurrency.iqd
                                  ? AppLocaleKeys.osLegalContractCurrencyIqd.tr
                                  : AppLocaleKeys.osLegalContractCurrencyUsd.tr),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _currency = v);
                      },
                    ),
                  ],
                );

            Widget salaryOrPenaltyBlock() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(
                      isEmployee
                          ? AppLocaleKeys.osLegalContractSalaryMonthly.tr
                          : AppLocaleKeys.osLegalContractPenaltyDaily.tr,
                    ),
                    osTypedTextField(
                      controller:
                          isEmployee ? _salaryCtrl : _penaltyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: osDialogFieldDecoration(context),
                    ),
                  ],
                );

            final blocks = [
              totalValueBlock(),
              currencyBlock(),
              salaryOrPenaltyBlock(),
            ];

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < blocks.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: blocks[i]),
                  ],
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < blocks.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  blocks[i],
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _dateField(
                AppLocaleKeys.osLegalContractEffectiveDate.tr,
                FirestoreOsFinanceApi.formatDate(_startDate),
                () => _pickDate(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dateField(
                AppLocaleKeys.osLegalContractEnd.tr,
                _endDate == null
                    ? AppLocaleKeys.osCommonNa.tr
                    : FirestoreOsFinanceApi.formatDate(_endDate!),
                () => _pickDate(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (isEmployee)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(AppLocaleKeys.osLegalContractProbationDays.tr),
                    osTypedTextField(
                      controller: _probationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: osDialogFieldDecoration(context),
                    ),
                  ],
                ),
              ),
            if (isEmployee) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label(AppLocaleKeys.osLegalContractNoticeDays.tr),
                  osTypedTextField(
                    controller: _noticeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: osDialogFieldDecoration(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _paymentScheduleHeader(theme, narrow, percentSum),
              const SizedBox(height: 12),
              for (var i = 0; i < _paymentTerms.length; i++)
                _paymentRow(theme, i, compact: narrow),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentScheduleHeader(
    AppThemeExtension theme,
    bool narrow,
    double percentSum,
  ) {
    final percentLabel = Text(
      AppLocaleKeys.osLegalContractPaymentTotalPercent.trParams({
        'percent': percentSum.toStringAsFixed(0),
      }),
      style: TextStyle(fontSize: 11, color: theme.mutedText),
    );

    final addButton = OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _paymentTerms = [
            ..._paymentTerms,
            OsContractPaymentTerm(
              milestone:
                  '${AppLocaleKeys.osLegalContractAddPayment.tr} ${_paymentTerms.length + 1}',
              percentage: 10,
              amount: (_totalValue * 0.1).roundToDouble(),
              dueDateDescription: '',
            ),
          ];
        });
      },
      icon: const Icon(Icons.add, size: 16),
      label: Text(AppLocaleKeys.osLegalContractAddPayment.tr),
    );

    final aiActionColor = OsAiColors.actionForeground(context);
    final aiScheduleButton = OutlinedButton.icon(
      onPressed: _loadingAiKey != null ? null : _generatePaymentSchedule,
      style: OutlinedButton.styleFrom(foregroundColor: aiActionColor),
      icon: _loadingAiKey == 'payment-schedule'
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: aiActionColor,
              ),
            )
          : Icon(Icons.auto_awesome, size: 16, color: aiActionColor),
      label: Text(AppLocaleKeys.osAiContractPaymentScheduleTitle.tr),
    );

    final title = Text(
      AppLocaleKeys.osLegalContractPaymentSchedule.tr,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: theme.primaryText,
      ),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 10),
          percentLabel,
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: aiScheduleButton),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: addButton),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        percentLabel,
        const SizedBox(width: 8),
        aiScheduleButton,
        const SizedBox(width: 8),
        addButton,
      ],
    );
  }

  Widget _dateField(String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(label),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: osDialogFieldDecoration(
              context,
              prefixIcon: Icon(
                Icons.event_outlined,
                size: 20,
                color: context.appTheme.mutedText,
              ),
            ),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _paymentRow(
    AppThemeExtension theme,
    int index, {
    bool compact = false,
  }) {
    final term = _paymentTerms[index];

    final milestoneField = TextFormField(
      key: ValueKey('milestone-$index-${term.milestone.hashCode}'),
      initialValue: term.milestone,
      textDirection: typedInputTextDirection(term.milestone),
      decoration: osDialogFieldDecoration(
        context,
        hint: AppLocaleKeys.osLegalContractPaymentMilestone.tr,
      ).copyWith(
        hintTextDirection: typedInputHintTextDirection(
          AppLocaleKeys.osLegalContractPaymentMilestone.tr,
        ),
      ),
      onChanged: (v) {
        setState(() {
          _paymentTerms[index] = term.copyWith(milestone: v);
        });
      },
    );

    final percentField = TextFormField(
      key: ValueKey('pct-$index-${term.percentage}'),
      initialValue: term.percentage.toStringAsFixed(0),
      keyboardType: TextInputType.number,
      textDirection: typedInputTextDirection(
        term.percentage.toStringAsFixed(0),
      ),
      decoration: osDialogFieldDecoration(
        context,
        suffixText: '%',
      ),
      onChanged: (v) {
        final pct = double.tryParse(v) ?? 0;
        setState(() {
          _paymentTerms[index] = term.copyWith(
            percentage: pct,
            amount: ((_totalValue * pct) / 100).roundToDouble(),
          );
        });
      },
    );

    final amountLabel = Text(
      osLegalContractMoneyLabel(term.amount, _currency),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: AppColors.success,
        fontSize: 12,
      ),
    );

    final dueField = TextFormField(
      key: ValueKey('due-$index-${term.dueDateDescription.hashCode}'),
      initialValue: term.dueDateDescription,
      textDirection: typedInputTextDirection(term.dueDateDescription),
      decoration: osDialogFieldDecoration(
        context,
        hint: AppLocaleKeys.osLegalContractPaymentDue.tr,
      ).copyWith(
        hintTextDirection: typedInputHintTextDirection(
          AppLocaleKeys.osLegalContractPaymentDue.tr,
        ),
      ),
      onChanged: (v) {
        setState(() {
          _paymentTerms[index] = term.copyWith(dueDateDescription: v);
        });
      },
    );

    final deleteBtn = IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: _paymentTerms.length <= 1
          ? null
          : () => setState(() {
                _paymentTerms = List.of(_paymentTerms)..removeAt(index);
              }),
      icon: Icon(Icons.delete_outline, color: theme.mutedText, size: 20),
    );

    if (compact) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        decoration: BoxDecoration(
          color: theme.elevatedSurface.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: milestoneField),
                deleteBtn,
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label(AppLocaleKeys.osLegalContractPaymentPercent.tr),
                      percentField,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label(AppLocaleKeys.osLegalContractPaymentAmount.tr),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: amountLabel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            dueField,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          deleteBtn,
          Expanded(flex: 3, child: milestoneField),
          const SizedBox(width: 8),
          SizedBox(width: 72, child: percentField),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: amountLabel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: dueField),
        ],
      ),
    );
  }

  Widget _buildStep4(AppThemeExtension theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _label(AppLocaleKeys.osLegalContractScopeOfWork.tr),
            ),
            OsAiGenerateButton(
              isLoading: _loadingAiKey == 'scope',
              onPressed:
                  _loadingAiKey != null ? null : _generateContractScope,
            ),
          ],
        ),
        osTypedTextField(
          controller: _scopeCtrl,
          maxLines: 4,
          decoration: osDialogFieldDecoration(context),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                AppLocaleKeys.osLegalContractLegalArticles.tr,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: theme.primaryText,
                ),
              ),
            ),
            OsAiGenerateButton(
              compact: true,
              isLoading: _loadingAiKey == 'clauses-all',
              onPressed:
                  _loadingAiKey != null ? null : _generateAllClauses,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _loadingAiKey != null
                  ? null
                  : () {
                      setState(() {
                        _clauses = [
                          ..._clauses,
                          OsContractClause(
                            id:
                                'c-custom-${DateTime.now().millisecondsSinceEpoch}',
                            title: AppLocaleKeys.osLegalContractAddClause.tr,
                            content:
                                'اتفق الطرفان على الالتزام بالشروط والضوابط المحددة في هذا البند التزاماً تاماً وبحسن نية.',
                          ),
                        ];
                      });
                    },
              icon: const Icon(Icons.add, size: 16),
              label: Text(AppLocaleKeys.osLegalContractAddClause.tr),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _clauses.length; i++) _clauseEditor(theme, i),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _label(AppLocaleKeys.osLegalContractCustomTerms.tr)),
            OsAiGenerateButton(
              isLoading: _loadingAiKey == 'custom-terms',
              onPressed:
                  _loadingAiKey != null ? null : _generateCustomTerms,
            ),
          ],
        ),
        osTypedTextField(
          controller: _customTermsCtrl,
          maxLines: 3,
          decoration: osDialogFieldDecoration(context),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _label(AppLocaleKeys.osLegalContractJurisdiction.tr)),
            OsAiGenerateButton(
              isLoading: _loadingAiKey == 'jurisdiction',
              onPressed:
                  _loadingAiKey != null ? null : _generateJurisdiction,
            ),
          ],
        ),
        osTypedTextField(
          controller: _jurisdictionCtrl,
          maxLines: 2,
          decoration: osDialogFieldDecoration(context),
        ),
      ],
    );
  }

  Widget _clauseEditor(AppThemeExtension theme, int index) {
    final clause = _clauses[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(12),
        color: theme.elevatedSurface.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!clause.isMandatory)
                IconButton(
                  onPressed: () => setState(() {
                    _clauses = List.of(_clauses)..removeAt(index);
                  }),
                  icon: Icon(Icons.delete_outline, color: theme.mutedText),
                ),
              Expanded(
                child: TextFormField(
                  key: ValueKey('clause-title-${clause.id}'),
                  initialValue: clause.title,
                  textDirection: typedInputTextDirection(clause.title),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.primaryText,
                    fontSize: 12,
                  ),
                  decoration: osDialogFieldDecoration(context),
                  onChanged: (v) {
                    setState(() {
                      _clauses[index] = clause.copyWith(title: v);
                    });
                  },
                ),
              ),
              Checkbox(
                value: clause.isEnabled,
                onChanged: clause.isMandatory
                    ? null
                    : (v) => setState(() {
                          _clauses[index] =
                              clause.copyWith(isEnabled: v ?? false);
                        }),
              ),
            ],
          ),
          TextFormField(
            key: ValueKey('clause-body-${clause.id}-${clause.content.hashCode}'),
            initialValue: clause.content,
            maxLines: 5,
            textDirection: typedInputTextDirection(clause.content),
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: theme.primaryText,
            ),
            decoration: osDialogFieldDecoration(context),
            onChanged: (v) {
              setState(() {
                _clauses[index] = clause.copyWith(content: v);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppThemeExtension theme) {
    final rtl = Directionality.of(context) == TextDirection.rtl;

    IconData previousIcon() =>
        rtl ? Icons.chevron_left : Icons.chevron_right;
    IconData nextIcon() => rtl ? Icons.chevron_right : Icons.chevron_left;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.border)),
        color: theme.cardSurface,
      ),
      child: Row(
        children: [
          if (_step == 1)
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text('cancel'.tr),
            )
          else
            OutlinedButton(
              onPressed: _saving ? null : _goPrevious,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(previousIcon(), size: 18),
                  const SizedBox(width: 6),
                  Text(AppLocaleKeys.osLegalContractPrevious.tr),
                ],
              ),
            ),
          const Spacer(),
          if (_step < _totalSteps)
            FilledButton(
              onPressed: _saving ? null : _goNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_nextLabel()),
                  const SizedBox(width: 6),
                  Icon(nextIcon(), size: 18, color: Colors.white),
                ],
              ),
            )
          else
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: OsButtonStyles.primaryCompact(),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(AppLocaleKeys.osLegalContractApproveSave.tr),
            ),
        ],
      ),
    );
  }

  String _nextLabel() {
    switch (_step) {
      case 1:
        return AppLocaleKeys.osLegalContractNextParties.tr;
      case 2:
        return AppLocaleKeys.osLegalContractNextFinancials.tr;
      case 3:
        return AppLocaleKeys.osLegalContractNextClauses.tr;
      default:
        return AppLocaleKeys.osLegalContractSave.tr;
    }
  }
}
