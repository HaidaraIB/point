import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/os_whatsapp_template_map.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Messaging/os_messaging_hub_tabs.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Shared/whatsapp_phone_field.dart';

/// A single field to collect before WhatsApp send.
class OsWhatsappMissingField {
  const OsWhatsappMissingField({
    required this.id,
    required this.label,
    this.isPhone = false,
    this.fieldKey,
    this.initialValue = '',
  });

  /// `recipient_phone` or template placeholder token.
  final String id;
  final String label;
  final bool isPhone;
  final String? fieldKey;
  final String initialValue;
}

/// Shows one dialog for all missing WhatsApp send fields.
/// Returns map of id → value, or null when cancelled.
Future<Map<String, String>?> showOsWhatsappMissingFieldsDialog({
  required List<OsWhatsappMissingField> fields,
}) async {
  if (fields.isEmpty) return const {};
  final ctx = Get.context;
  if (ctx == null) return null;

  return showDialog<Map<String, String>>(
    context: ctx,
    barrierDismissible: false,
    builder: (dialogContext) => _OsWhatsappMissingFieldsDialog(fields: fields),
  );
}

class _OsWhatsappMissingFieldsDialog extends StatefulWidget {
  const _OsWhatsappMissingFieldsDialog({required this.fields});

  final List<OsWhatsappMissingField> fields;

  @override
  State<_OsWhatsappMissingFieldsDialog> createState() =>
      _OsWhatsappMissingFieldsDialogState();
}

class _OsWhatsappMissingFieldsDialogState
    extends State<_OsWhatsappMissingFieldsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _textControllers;
  late final Map<String, String> _phoneValues;

  @override
  void initState() {
    super.initState();
    _textControllers = {};
    _phoneValues = {};
    for (final f in widget.fields) {
      if (f.isPhone) {
        _phoneValues[f.id] = f.initialValue;
      } else {
        _textControllers[f.id] = TextEditingController(text: f.initialValue);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final out = <String, String>{};
    for (final f in widget.fields) {
      if (f.isPhone) {
        out[f.id] = _phoneValues[f.id]?.trim() ?? '';
      } else {
        out[f.id] = _textControllers[f.id]?.text.trim() ?? '';
      }
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final narrow = MediaQuery.sizeOf(context).width < 520;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 28,
        vertical: narrow ? 16 : 28,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.send_outlined, color: theme.accentText, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocaleKeys.osWhatsappMissingFieldsTitle.tr,
                      style: TextStyle(
                        fontSize: narrow ? 17 : 18,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.secondaryText),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                AppLocaleKeys.osWhatsappMissingFieldsSubtitle.tr,
                style: TextStyle(fontSize: 13, color: theme.secondaryText),
              ),
            ),
            const Divider(height: 16),
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    children: [
                      for (final f in widget.fields) ...[
                        if (f.isPhone)
                          WhatsappPhoneField(
                            initialNormalized:
                                (_phoneValues[f.id] ?? '').trim().isEmpty
                                    ? null
                                    : _phoneValues[f.id]!.trim(),
                            decoration: osDialogFieldDecoration(context).copyWith(
                              labelText: f.label,
                            ),
                            onChanged: (v) => _phoneValues[f.id] = v ?? '',
                          )
                        else
                          osTypedTextFormField(
                            controller: _textControllers[f.id]!,
                            decoration: osDialogFieldDecoration(context).copyWith(
                              labelText: f.label,
                            ),
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty) {
                                return AppLocaleKeys.commonRequired.tr;
                              }
                              return null;
                            },
                          ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocaleKeys.commonCancel.tr),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: Text(AppLocaleKeys.osWhatsappMissingFieldsSend.tr),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<OsWhatsappMissingField> osWhatsappCollectMissingFields({
  required String recipientPhone,
  required OsWhatsappTemplateMapEntry mapEntry,
  required Map<String, String> resolvedValues,
}) {
  final out = <OsWhatsappMissingField>[];
  if (recipientPhone.trim().isEmpty) {
    out.add(
      OsWhatsappMissingField(
        id: 'recipient_phone',
        label: AppLocaleKeys.osMessagingHubRecipientPhone.tr,
        isPhone: true,
      ),
    );
  }
  for (final e in mapEntry.placeholderFields.entries) {
    final token = e.key;
    final fieldKey = e.value;
    if (fieldKey == OsWhatsappTemplateFieldKey.phone) continue;
    final value = resolvedValues[token]?.trim() ?? '';
    if (value.isNotEmpty) continue;
    out.add(
      OsWhatsappMissingField(
        id: token,
        label: osWhatsappFieldLabel(fieldKey),
        fieldKey: fieldKey,
        initialValue: value,
      ),
    );
  }
  return out;
}
