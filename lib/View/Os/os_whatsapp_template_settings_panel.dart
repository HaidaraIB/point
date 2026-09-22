import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsWhatsappHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsWhatsappLogModel.dart';
import 'package:point/Models/Os/os_whatsapp_template_map.dart';
import 'package:point/Services/os_whatsapp_service.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/os_whatsapp_template_vars.dart';
import 'package:point/View/Os/Messaging/os_messaging_hub_tabs.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_message_preview.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/responsive.dart';

String _documentAttachmentLabel(String value) {
  switch (value) {
    case OsWhatsappTemplateDocumentAttachment.invoicePdf:
      return AppLocaleKeys.osSettingsWhatsappTemplatesDocInvoice.tr;
    case OsWhatsappTemplateDocumentAttachment.quotationPdf:
      return AppLocaleKeys.osSettingsWhatsappTemplatesDocQuotation.tr;
    case OsWhatsappTemplateDocumentAttachment.voucherPdf:
    case OsWhatsappTemplateDocumentAttachment.receiptPdf:
      return AppLocaleKeys.osSettingsWhatsappTemplatesDocVoucher.tr;
    case OsWhatsappTemplateDocumentAttachment.paymentPdf:
      return AppLocaleKeys.osSettingsWhatsappTemplatesDocPayment.tr;
    case OsWhatsappTemplateDocumentAttachment.contractPdf:
      return AppLocaleKeys.osSettingsWhatsappTemplatesDocContract.tr;
    case OsWhatsappTemplateDocumentAttachment.payslipPdf:
      return AppLocaleKeys.osSettingsWhatsappTemplatesDocPayslip.tr;
    default:
      return AppLocaleKeys.osSettingsWhatsappTemplatesDocNone.tr;
  }
}

String? _sampleDocumentFilename(String attachment) {
  switch (attachment) {
    case OsWhatsappTemplateDocumentAttachment.invoicePdf:
      return 'INV-001.pdf';
    case OsWhatsappTemplateDocumentAttachment.quotationPdf:
      return 'QUO-001.pdf';
    case OsWhatsappTemplateDocumentAttachment.voucherPdf:
    case OsWhatsappTemplateDocumentAttachment.receiptPdf:
      return 'voucher-RCP-001.pdf';
    case OsWhatsappTemplateDocumentAttachment.paymentPdf:
      return 'voucher-PAY-001.pdf';
    case OsWhatsappTemplateDocumentAttachment.contractPdf:
      return 'contract-CTR-001.pdf';
    case OsWhatsappTemplateDocumentAttachment.payslipPdf:
      return 'payslip-SLIP-001.pdf';
    default:
      return null;
  }
}

Map<String, String> _sampleValues(
  List<OsWhatsappTemplatePlaceholder> list,
  Map<String, String> placeholderFields,
) {
  final out = <String, String>{};
  for (final p in list) {
    final field = placeholderFields[p.token];
    if (field != null && field.isNotEmpty) {
      out[p.token] = osWhatsappSampleValueForField(field);
    } else {
      out[p.token] = '…';
    }
  }
  return out;
}

class OsWhatsappTemplateSettingsPanel extends StatefulWidget {
  const OsWhatsappTemplateSettingsPanel({super.key});

  @override
  State<OsWhatsappTemplateSettingsPanel> createState() =>
      _OsWhatsappTemplateSettingsPanelState();
}

class _OsWhatsappTemplateSettingsPanelState
    extends State<OsWhatsappTemplateSettingsPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  var _loading = true;
  String? _savingKey;
  String? _expandedKey;
  final _templates = <OsWhatsappTemplateModel>[];
  final _entries = <String, OsWhatsappTemplateMapEntry>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _applyResult(
    List<OsWhatsappTemplateModel> templates,
    OsWhatsappTemplateMapConfig map,
  ) {
    _templates
      ..clear()
      ..addAll(templates);
    _entries.clear();
    for (final e in map.entries) {
      OsWhatsappTemplateModel? template;
      for (final t in templates) {
        if (t.name == e.templateName && t.language == e.languageCode) {
          template = t;
          break;
        }
      }
      final tokens = template == null
          ? const <String>[]
          : osWhatsappExtractPlaceholders(template).map((p) => p.token);
      _entries[e.mapKey()] = e.coerced(placeholderTokens: tokens);
    }
    for (final t in _templates) {
      final key = '${t.name}|${t.language}';
      _entries.putIfAbsent(
        key,
        () => OsWhatsappTemplateMapEntry(
          templateName: t.name,
          languageCode: t.language,
        ),
      );
    }
  }

  Future<void> _load() async {
    final service = OsWhatsappService.instance;
    final cachedTemplates = service.cachedTemplates;
    if (cachedTemplates != null && cachedTemplates.isNotEmpty) {
      _applyResult(cachedTemplates, service.cachedTemplateMap);
      if (mounted) setState(() => _loading = false);
      unawaited(_refreshFromServer(showLoading: false));
      return;
    }

    setState(() => _loading = true);
    await _refreshFromServer(showLoading: true);
  }

  Future<void> _refreshFromServer({required bool showLoading}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final result = await OsWhatsappService.instance.listTemplatesWithMap();
      if (!mounted) return;
      _applyResult(result.templates, result.map);
    } finally {
      if (mounted && showLoading) setState(() => _loading = false);
      else if (mounted) setState(() {});
    }
  }

  void _updateEntry(OsWhatsappTemplateMapEntry entry) {
    _entries[entry.mapKey()] = entry;
  }

  void _toggleExpanded(String key) {
    setState(() {
      _expandedKey = _expandedKey == key ? null : key;
    });
  }

  Future<void> _saveEntry(OsWhatsappTemplateMapEntry entry) async {
    final template = _templateFor(entry);
    if (template == null) return;

    final tokens =
        osWhatsappExtractPlaceholders(template).map((p) => p.token);
    final normalized = entry.coerced(placeholderTokens: tokens);

    if (normalized.hasUnmappedPlaceholders(tokens)) {
      OsSnackbar.error(
        AppLocaleKeys.osSettingsWhatsappTemplatesSection.tr,
        AppLocaleKeys.osSettingsWhatsappTemplatesPlaceholdersIncomplete.tr,
      );
      return;
    }
    if (normalized.hasWrongDocumentForPurpose(
      templateHasDocumentHeader: template.hasDocumentHeader,
    )) {
      OsSnackbar.error(
        AppLocaleKeys.osSettingsWhatsappTemplatesSection.tr,
        AppLocaleKeys.osSettingsWhatsappTemplatesDocumentMismatch.tr,
      );
      return;
    }

    final merged = OsWhatsappService.instance.cachedTemplateMap
        .withReplacedEntry(normalized);
    if (normalized.enabled &&
        normalized.purpose != OsWhatsappTemplatePurpose.unused &&
        normalized.purpose != OsWhatsappTemplatePurpose.custom) {
      for (final other in merged.entries) {
        if (other.mapKey() == normalized.mapKey()) continue;
        if (!other.enabled) continue;
        if (other.purpose == normalized.purpose) {
          OsSnackbar.error(
            AppLocaleKeys.osSettingsWhatsappTemplatesSection.tr,
            AppLocaleKeys.osSettingsWhatsappTemplatesPurposeDuplicate.tr,
          );
          return;
        }
      }
    }

    final key = normalized.mapKey();
    setState(() => _savingKey = key);
    try {
      final saved = await OsWhatsappService.instance.saveTemplateMap(merged);
      if (saved == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsWhatsappTemplatesSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      final savedEntry = saved.entryFor(
        normalized.templateName,
        normalized.languageCode,
      );
      if (savedEntry != null) {
        _entries[key] = savedEntry;
      }
      if (Get.isRegistered<OsWhatsappHubController>()) {
        await Get.find<OsWhatsappHubController>().refreshTemplates();
      }
      if (mounted) setState(() {});
      OsSnackbar.success(
        AppLocaleKeys.osSettingsWhatsappTemplatesSection.tr,
        AppLocaleKeys.osSettingsWhatsappTemplatesSaved.tr,
      );
    } finally {
      if (mounted) setState(() => _savingKey = null);
    }
  }

  OsWhatsappTemplateModel? _templateFor(OsWhatsappTemplateMapEntry entry) {
    for (final t in _templates) {
      if (t.name == entry.templateName && t.language == entry.languageCode) {
        return t;
      }
    }
    return null;
  }

  String _purposeLabel(String purpose) {
    switch (purpose) {
      case OsWhatsappTemplatePurpose.invoice:
        return AppLocaleKeys.osWhatsappPurposeInvoice.tr;
      case OsWhatsappTemplatePurpose.quotation:
        return AppLocaleKeys.osWhatsappPurposeQuotation.tr;
      case OsWhatsappTemplatePurpose.paymentConfirmation:
        return AppLocaleKeys.osWhatsappPurposePaymentConfirmation.tr;
      case OsWhatsappTemplatePurpose.paymentReceipt:
        return AppLocaleKeys.osWhatsappPurposePaymentReceipt.tr;
      case OsWhatsappTemplatePurpose.contract:
        return AppLocaleKeys.osWhatsappPurposeContract.tr;
      case OsWhatsappTemplatePurpose.payslip:
        return AppLocaleKeys.osWhatsappPurposePayslip.tr;
      case OsWhatsappTemplatePurpose.custom:
        return AppLocaleKeys.osWhatsappPurposeCustom.tr;
      default:
        return AppLocaleKeys.osWhatsappPurposeUnused.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = context.appTheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_templates.isEmpty) {
      return Text(
        AppLocaleKeys.osMessagingHubNoTemplates.tr,
        style: TextStyle(color: theme.secondaryText),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocaleKeys.osSettingsWhatsappTemplatesDescription.tr,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _templates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final t = _templates[index];
            final key = '${t.name}|${t.language}';
            final entry = _entries[key]!;
            return _TemplateMapCard(
              key: ValueKey(key),
              template: t,
              entry: entry,
              isExpanded: _expandedKey == key,
              isSaving: _savingKey == key,
              onToggleExpand: () => _toggleExpanded(key),
              purposeLabel: _purposeLabel,
              onChanged: _updateEntry,
              onSave: () => _saveEntry(_entries[key]!),
            );
          },
        ),
      ],
    );
  }
}

class _TemplateMapCard extends StatefulWidget {
  const _TemplateMapCard({
    super.key,
    required this.template,
    required this.entry,
    required this.isExpanded,
    required this.isSaving,
    required this.onToggleExpand,
    required this.purposeLabel,
    required this.onChanged,
    required this.onSave,
  });

  final OsWhatsappTemplateModel template;
  final OsWhatsappTemplateMapEntry entry;
  final bool isExpanded;
  final bool isSaving;
  final VoidCallback onToggleExpand;
  final String Function(String) purposeLabel;
  final ValueChanged<OsWhatsappTemplateMapEntry> onChanged;
  final VoidCallback onSave;

  @override
  State<_TemplateMapCard> createState() => _TemplateMapCardState();
}

class _TemplateMapCardState extends State<_TemplateMapCard> {
  static final _purposes = OsWhatsappTemplatePurpose.menuOrder;

  late OsWhatsappTemplateMapEntry _entry;
  late List<OsWhatsappTemplatePlaceholder> _placeholders;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _placeholders = osWhatsappExtractPlaceholders(widget.template);
  }

  @override
  void didUpdateWidget(_TemplateMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template != widget.template) {
      _placeholders = osWhatsappExtractPlaceholders(widget.template);
    }
    if (oldWidget.entry != widget.entry) {
      _entry = widget.entry;
    }
  }

  void _update(OsWhatsappTemplateMapEntry entry) {
    setState(() => _entry = entry);
    widget.onChanged(entry);
  }

  Widget _buildPreview(BuildContext context) {
    return osMessagingHubWhatsappPreview(
      context,
      widget.template,
      valueByToken: _sampleValues(_placeholders, _entry.placeholderFields),
      documentFilename: _sampleDocumentFilename(
        _entry.effectiveDocumentAttachment(),
      ),
    );
  }

  Widget _buildSaveRow(BuildContext context, {required bool showPreview}) {
    final theme = context.appTheme;
    final saveButton = FilledButton.icon(
      onPressed: widget.isSaving ? null : widget.onSave,
      style: OsButtonStyles.primaryCompact(),
      icon: widget.isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined, size: 18),
      label: Text(AppLocaleKeys.osSettingsWhatsappTemplatesSave.tr),
    );

    if (!showPreview) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [saveButton],
      );
    }

    final previewButton = OutlinedButton.icon(
      onPressed: () => _showPreviewDialog(context),
      style: OsButtonStyles.outlinedCompact(theme),
      icon: const Icon(Icons.visibility_outlined, size: 18),
      label: Text(
        AppLocaleKeys.osSettingsWhatsappTemplatesShowPreview.tr,
      ),
    );

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: previewButton,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: saveButton,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel(BuildContext context) {
    final theme = context.appTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocaleKeys.osMessagingHubPreview.tr,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        _buildPreview(context),
      ],
    );
  }

  void _showPreviewDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocaleKeys.osMessagingHubPreview.tr),
        content: SingleChildScrollView(
          child: _buildPreview(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocaleKeys.osCommonClose.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final theme = context.appTheme;
    final purpose = _entry.purpose;
    final fieldOptions = purpose == OsWhatsappTemplatePurpose.unused
        ? const <String>[]
        : _entry.allowedFieldKeys();
    final isBuiltIn = OsWhatsappTemplatePurpose.isBuiltIn(purpose);
    final showCustomDocument = purpose == OsWhatsappTemplatePurpose.custom;
    final showLockedDocument =
        isBuiltIn && widget.template.hasDocumentHeader;
    final showValuesFrom =
        showCustomDocument && !widget.template.hasDocumentHeader;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: purpose,
                decoration: osFinanceFieldDecoration(
                  AppLocaleKeys.osSettingsWhatsappTemplatesPurpose.tr,
                ),
                items: _purposes
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(widget.purposeLabel(p)),
                      ),
                    )
                    .toList(),
                onChanged: (p) {
                  if (p == null) return;
                  _update(
                    _entry.withPurposeChange(
                      p,
                      placeholderTokens:
                          _placeholders.map((item) => item.token),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (purpose == OsWhatsappTemplatePurpose.custom) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('custom-label-${_entry.mapKey()}'),
            initialValue: _entry.customLabel,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osSettingsWhatsappTemplatesCustomLabel.tr,
            ),
            onChanged: (v) => _update(_entry.copyWith(customLabel: v)),
          ),
        ],
        if (showLockedDocument) ...[
          const SizedBox(height: 12),
          InputDecorator(
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osSettingsWhatsappTemplatesDocument.tr,
            ),
            child: Text(
              widget.purposeLabel(purpose),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
          ),
        ] else if (showCustomDocument && widget.template.hasDocumentHeader) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: OsWhatsappTemplateDocumentAttachment
                    .documentDropdownOptions()
                    .contains(_entry.documentAttachment)
                ? _entry.documentAttachment
                : OsWhatsappTemplateDocumentAttachment.none,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osSettingsWhatsappTemplatesDocument.tr,
            ),
            items: OsWhatsappTemplateDocumentAttachment.documentDropdownOptions()
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(_documentAttachmentLabel(v)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              _update(
                _entry.withDocumentAttachmentChange(
                  v,
                  placeholderTokens:
                      _placeholders.map((item) => item.token),
                ),
              );
            },
          ),
        ] else if (showValuesFrom) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: OsWhatsappTemplateDocumentAttachment
                    .documentDropdownOptions()
                    .contains(_entry.documentAttachment)
                ? _entry.documentAttachment
                : OsWhatsappTemplateDocumentAttachment.none,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osSettingsWhatsappTemplatesValuesFrom.tr,
            ),
            items: OsWhatsappTemplateDocumentAttachment.documentDropdownOptions()
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(_documentAttachmentLabel(v)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              _update(
                _entry.withDocumentAttachmentChange(
                  v,
                  placeholderTokens:
                      _placeholders.map((item) => item.token),
                ),
              );
            },
          ),
        ],
        if (_placeholders.isNotEmpty &&
            purpose != OsWhatsappTemplatePurpose.unused) ...[
          const SizedBox(height: 12),
          Text(
            AppLocaleKeys.osSettingsWhatsappTemplatesPlaceholders.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          ..._placeholders.map((p) {
            final current = _entry.placeholderFields[p.token];
            final selected = current != null && fieldOptions.contains(current)
                ? current
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: selected,
                    decoration: osFinanceFieldDecoration('{{${p.token}}}'),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          AppLocaleKeys
                              .osSettingsWhatsappTemplatesChooseField.tr,
                          style: TextStyle(color: theme.secondaryText),
                        ),
                      ),
                      ...fieldOptions.map(
                        (f) => DropdownMenuItem<String?>(
                          value: f,
                          child: Text(osWhatsappFieldLabel(f)),
                        ),
                      ),
                    ],
                    onChanged: (f) {
                      final next = Map<String, String>.from(
                        _entry.placeholderFields,
                      );
                      if (f == null) {
                        next.remove(p.token);
                      } else {
                        next[p.token] = f;
                      }
                      _update(_entry.copyWith(placeholderFields: next));
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final compact = Responsive.isMobile(context);
    final title = '${widget.template.name} (${widget.template.language})';

    return Container(
      decoration: BoxDecoration(
        color: theme.panelTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isExpanded ? theme.accentText : theme.border,
          width: widget.isExpanded ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onToggleExpand,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: widget.isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: theme.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.accentText.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.purposeLabel(_entry.purpose),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.accentText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _entry.enabled,
                      onChanged: (v) => _update(_entry.copyWith(enabled: v)),
                    ),
                    Text(
                      AppLocaleKeys.osSettingsWhatsappTemplatesEnabled.tr,
                      style: TextStyle(fontSize: 12, color: theme.secondaryText),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            Divider(height: 1, color: theme.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = !compact && constraints.maxWidth >= 720;

                  if (wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildControls(context)),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _buildPreviewPanel(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSaveRow(context, showPreview: false),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildControls(context),
                      const SizedBox(height: 16),
                      _buildSaveRow(context, showPreview: compact),
                      if (!compact) ...[
                        const SizedBox(height: 16),
                        _buildPreviewPanel(context),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
