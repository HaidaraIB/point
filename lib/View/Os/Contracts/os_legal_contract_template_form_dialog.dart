import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsContractClause.dart';
import 'package:point/Models/Os/OsContractTemplate.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/text_input_bidi.dart';
import 'package:point/Services/os_ai_service.dart';
import 'package:point/View/Os/os_ai_generate_button.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Opens the template editor; returns the saved template on success.
Future<OsContractTemplate?> showOsLegalContractTemplateFormDialog(
  BuildContext context, {
  OsContractTemplate? existing,
  String? initialTargetType,
  OsContractTemplate? duplicateFrom,
}) {
  return showDialog<OsContractTemplate>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OsLegalContractTemplateFormDialog(
      existing: existing,
      initialTargetType: initialTargetType,
      duplicateFrom: duplicateFrom,
    ),
  );
}

class _OsLegalContractTemplateFormDialog extends StatefulWidget {
  const _OsLegalContractTemplateFormDialog({
    this.existing,
    this.initialTargetType,
    this.duplicateFrom,
  });

  final OsContractTemplate? existing;
  final String? initialTargetType;
  final OsContractTemplate? duplicateFrom;

  @override
  State<_OsLegalContractTemplateFormDialog> createState() =>
      _OsLegalContractTemplateFormDialogState();
}

class _OsLegalContractTemplateFormDialogState
    extends State<_OsLegalContractTemplateFormDialog> {
  static const _totalSteps = 2;

  final _ctrl = Get.find<OsLegalContractsController>();
  var _step = 1;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _suggestedTitleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _subTypeCtrl;
  late final TextEditingController _governingLawCtrl;
  late final TextEditingController _durationCtrl;
  late String _targetType;
  late List<OsContractClause> _clauses;
  var _saving = false;
  String? _loadingAiKey;

  OsAiContractInput _templateAiInput({
    String? clauseTitle,
    String? clauseContent,
  }) {
    final title = _suggestedTitleCtrl.text.trim().isNotEmpty
        ? _suggestedTitleCtrl.text.trim()
        : _nameCtrl.text.trim();
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    return OsAiContractInput(
      contractTitle: _nameCtrl.text.trim(),
      templateTitle: title,
      targetType: _targetType,
      templateDescription: _descriptionCtrl.text.trim(),
      subType: _subTypeCtrl.text.trim(),
      defaultDurationMonths: duration,
      governingLaw: _governingLawCtrl.text.trim(),
      clauseTitle: clauseTitle ?? '',
      clauseContent: clauseContent ?? '',
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
    if (_loadingAiKey != null || _saving) return;
    if (!await _confirmReplaceClauses()) return;

    setState(() => _loadingAiKey = 'clauses-all');
    try {
      final drafts = await OsAiService.instance.generateContractClauses(
        input: _templateAiInput(),
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

  Future<void> _generateDescription() async {
    if (_loadingAiKey != null) return;
    setState(() => _loadingAiKey = 'template-description');
    try {
      final text =
          await OsAiService.instance.generateContractTemplateDescription(
        input: _templateAiInput(),
      );
      if (mounted) _descriptionCtrl.text = text;
    } finally {
      if (mounted) setState(() => _loadingAiKey = null);
    }
  }

  Future<void> _generateGoverningLaw() async {
    if (_loadingAiKey != null) return;
    setState(() => _loadingAiKey = 'governing-law');
    try {
      final text = await OsAiService.instance.generateContractGoverningLaw(
        input: _templateAiInput(),
      );
      if (mounted) _governingLawCtrl.text = text;
    } finally {
      if (mounted) setState(() => _loadingAiKey = null);
    }
  }

  @override
  void initState() {
    super.initState();
    final source = widget.existing ??
        (widget.duplicateFrom != null
            ? widget.duplicateFrom!.copyWith(
                id: '',
                isPreset: false,
              )
            : null);
    _targetType = source?.targetType ??
        widget.initialTargetType ??
        OsLegalContractTargetType.client;
    _nameCtrl = TextEditingController(text: source?.name ?? '');
    _suggestedTitleCtrl =
        TextEditingController(text: source?.suggestedTitle ?? '');
    _descriptionCtrl = TextEditingController(text: source?.description ?? '');
    _subTypeCtrl = TextEditingController(text: source?.subType ?? '');
    _governingLawCtrl = TextEditingController(text: source?.governingLaw ?? '');
    _durationCtrl = TextEditingController(
      text: source?.defaultDurationMonths != null
          ? '${source!.defaultDurationMonths}'
          : '6',
    );
    _clauses = source != null
        ? source.clauses
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
        : [
            OsContractClause(
              id: 'c-custom-${DateTime.now().millisecondsSinceEpoch}',
              title: AppLocaleKeys.osLegalContractAddClause.tr,
              content:
                  'اتفق الطرفان على الالتزام بالشروط والضوابط المحددة في هذا البند التزاماً تاماً وبحسن نية.',
            ),
          ];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _suggestedTitleCtrl.dispose();
    _descriptionCtrl.dispose();
    _subTypeCtrl.dispose();
    _governingLawCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    if (_nameCtrl.text.trim().isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osLegalContractTitle.tr,
        AppLocaleKeys.osLegalContractErrorTemplateNameRequired.tr,
      );
      return false;
    }
    return true;
  }

  void _goNext() {
    if (!_validateStep1()) return;
    if (_step < _totalSteps) setState(() => _step++);
  }

  void _goPrevious() {
    if (_step > 1) setState(() => _step--);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osLegalContractTitle.tr,
        AppLocaleKeys.osLegalContractErrorTemplateNameRequired.tr,
      );
      setState(() => _step = 1);
      return;
    }
    final validClauses = _clauses
        .where((c) => c.title.trim().isNotEmpty && c.content.trim().isNotEmpty)
        .toList();
    if (validClauses.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osLegalContractTitle.tr,
        AppLocaleKeys.osLegalContractErrorRequiredClause.tr,
      );
      return;
    }

    final duration = int.tryParse(_durationCtrl.text.trim());
    final template = OsContractTemplate(
      id: widget.existing?.id ?? '',
      name: name,
      description: _descriptionCtrl.text.trim(),
      targetType: _targetType,
      clauses: validClauses,
      suggestedTitle: _suggestedTitleCtrl.text.trim(),
      subType: _subTypeCtrl.text.trim(),
      governingLaw: _governingLawCtrl.text.trim(),
      defaultDurationMonths: duration,
      isPreset: false,
    );

    setState(() => _saving = true);
    final saved = await _ctrl.saveTemplate(template);
    if (!mounted) return;
    setState(() => _saving = false);

    if (saved == null) {
      OsSnackbar.error(
        AppLocaleKeys.osCommonSaveFailed.tr,
        AppLocaleKeys.errorsOsLegalContractsTemplateSave.tr,
      );
      return;
    }
    OsSnackbar.success(
      AppLocaleKeys.osLegalContractSavedTemplate.tr,
      saved.name,
    );
    Navigator.of(context).pop(saved);
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
    final maxH = size.height * (narrow ? 0.92 : 0.88) - viewInsets.bottom;
    final isEdit = widget.existing != null && !widget.existing!.isPreset;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 28,
        vertical: narrow ? 16 : 28,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: maxH.clamp(280, size.height),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    Icon(
                      isEdit ? Icons.edit_outlined : Icons.note_add_outlined,
                      color: theme.accentText,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEdit
                            ? AppLocaleKeys.osLegalContractEditTemplate.tr
                            : AppLocaleKeys.osLegalContractAddTemplateTitle.tr,
                        style: TextStyle(
                          fontSize: narrow ? 17 : 20,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: theme.secondaryText),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              _buildStepper(theme, narrow),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: _step == 1
                      ? _buildStep1Context(theme)
                      : _buildStep2Drafting(theme),
                ),
              ),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(AppThemeExtension theme, bool narrow) {
    final steps = [
      AppLocaleKeys.osLegalContractStepTemplateContext.tr,
      AppLocaleKeys.osLegalContractStepTemplateClauses.tr,
    ];

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

    final pills = Row(
      mainAxisSize: MainAxisSize.min,
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: pills,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: pills,
                  ),
                ),
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
        onTap: _saving
            ? null
            : () {
                if (stepNum == 2 && !_validateStep1()) return;
                setState(() => _step = stepNum);
              },
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

  Widget _buildStep1Context(AppThemeExtension theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_targetType),
          initialValue: _targetType,
          isExpanded: true,
          decoration: osFinanceFieldDecoration(
            AppLocaleKeys.osLegalContractTargetType.tr,
          ),
          items: [
            DropdownMenuItem(
              value: OsLegalContractTargetType.client,
              child: Text(
                AppLocaleKeys.osLegalContractCategoryClients.tr,
              ),
            ),
            DropdownMenuItem(
              value: OsLegalContractTargetType.employee,
              child: Text(
                AppLocaleKeys.osLegalContractCategoryEmployees.tr,
              ),
            ),
            DropdownMenuItem(
              value: OsLegalContractTargetType.freelancer,
              child: Text(
                AppLocaleKeys.osLegalContractCategoryFreelancers.tr,
              ),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _targetType = v);
          },
        ),
        const SizedBox(height: 14),
        osTypedTextField(
          controller: _nameCtrl,
          decoration: osFinanceFieldDecoration(
            AppLocaleKeys.osLegalContractTemplateName.tr,
          ),
        ),
        const SizedBox(height: 14),
        osTypedTextField(
          controller: _suggestedTitleCtrl,
          decoration: osFinanceFieldDecoration(
            AppLocaleKeys.osLegalContractFieldTitle.tr,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final stack = c.maxWidth < 520;
            final subType = osTypedTextField(
              controller: _subTypeCtrl,
              decoration: osFinanceFieldDecoration(
                AppLocaleKeys.osLegalContractTemplateSubType.tr,
              ),
            );
            final duration = osTypedTextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: osFinanceFieldDecoration(
                AppLocaleKeys.osLegalContractTemplateDurationMonths.tr,
              ),
            );
            if (stack) {
              return Column(
                children: [
                  subType,
                  const SizedBox(height: 14),
                  duration,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: subType),
                const SizedBox(width: 12),
                SizedBox(width: 160, child: duration),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep2Drafting(AppThemeExtension theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _label(AppLocaleKeys.osLegalContractNotes.tr),
            ),
            OsAiGenerateButton(
              isLoading: _loadingAiKey == 'template-description',
              onPressed: _loadingAiKey != null || _saving
                  ? null
                  : _generateDescription,
            ),
          ],
        ),
        osTypedTextField(
          controller: _descriptionCtrl,
          maxLines: 3,
          decoration: osDialogFieldDecoration(context),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _label(AppLocaleKeys.osLegalContractGoverningLaw.tr),
            ),
            OsAiGenerateButton(
              isLoading: _loadingAiKey == 'governing-law',
              onPressed: _loadingAiKey != null || _saving
                  ? null
                  : _generateGoverningLaw,
            ),
          ],
        ),
        osTypedTextField(
          controller: _governingLawCtrl,
          maxLines: 2,
          decoration: osDialogFieldDecoration(context),
        ),
        const SizedBox(height: 18),
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
              onPressed: _loadingAiKey != null || _saving
                  ? null
                  : _generateAllClauses,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _loadingAiKey != null || _saving
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
      ],
    );
  }

  Widget _buildFooter(AppThemeExtension theme) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    IconData previousIcon() =>
        rtl ? Icons.chevron_left : Icons.chevron_right;
    IconData nextIcon() => rtl ? Icons.chevron_right : Icons.chevron_left;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          if (_step == 1)
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: Text(AppLocaleKeys.commonCancel.tr),
            )
          else
            OutlinedButton(
              onPressed: _saving ? null : _goPrevious,
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
                  Text(AppLocaleKeys.osLegalContractNextClauses.tr),
                  const SizedBox(width: 6),
                  Icon(nextIcon(), size: 18, color: Colors.white),
                ],
              ),
            )
          else
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 20),
              label: Text(AppLocaleKeys.osLegalContractSaveTemplate.tr),
            ),
        ],
      ),
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
              IconButton(
                onPressed: () => setState(() {
                  _clauses = List.of(_clauses)..removeAt(index);
                }),
                icon: Icon(Icons.delete_outline, color: theme.mutedText),
              ),
              Expanded(
                child: TextFormField(
                  key: ValueKey('tpl-clause-title-${clause.id}'),
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
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('tpl-clause-body-${clause.id}'),
            initialValue: clause.content,
            textDirection: typedInputTextDirection(clause.content),
            maxLines: 5,
            style: TextStyle(fontSize: 12, color: theme.secondaryText),
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
}
