import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/whatsapp_phone.dart';

/// Country dial-code selector + national number, always LTR.
class WhatsappPhoneField extends StatefulWidget {
  const WhatsappPhoneField({
    super.key,
    this.initialNormalized,
    this.onChanged,
    this.decoration,
    this.enabled = true,
    this.validator,
  });

  final String? initialNormalized;
  final ValueChanged<String?>? onChanged;
  final InputDecoration? decoration;
  final bool enabled;
  final String? Function(String? normalized)? validator;

  @override
  State<WhatsappPhoneField> createState() => _WhatsappPhoneFieldState();
}

class _WhatsappPhoneFieldState extends State<WhatsappPhoneField> {
  late String _dialCode;
  late final TextEditingController _nationalCtrl;

  @override
  void initState() {
    super.initState();
    final split = splitWhatsappPhone(widget.initialNormalized);
    _dialCode = split.dialCode;
    _nationalCtrl = TextEditingController(text: split.national);
  }

  @override
  void didUpdateWidget(covariant WhatsappPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialNormalized != widget.initialNormalized &&
        widget.initialNormalized != _currentNormalized()) {
      final split = splitWhatsappPhone(widget.initialNormalized);
      setState(() {
        _dialCode = split.dialCode;
        _nationalCtrl.text = split.national;
      });
    }
  }

  @override
  void dispose() {
    _nationalCtrl.dispose();
    super.dispose();
  }

  String? _currentNormalized() {
    return normalizeWhatsappPhoneParts(
      dialCode: _dialCode,
      nationalNumber: _nationalCtrl.text,
    );
  }

  void _notify() {
    widget.onChanged?.call(_currentNormalized());
  }

  void _onNationalChanged(String raw) {
    final sanitized = sanitizeNationalPhoneInput(raw, dialCode: _dialCode);
    if (sanitized != raw) {
      _nationalCtrl.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final locale = Get.locale?.languageCode ?? 'ar';
    final baseDecoration = widget.decoration ?? const InputDecoration();
    final labelText = baseDecoration.labelText;
    final fieldDecoration = baseDecoration.copyWith(labelText: null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (labelText != null) ...[
          Text(
            labelText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 148,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_dialCode),
                  initialValue: _dialCode,
                  isExpanded: true,
                  decoration: fieldDecoration.copyWith(
                    hintText: null,
                    errorText: null,
                  ),
                  items: [
                    for (final c in kWhatsappCountryDialCodes)
                      DropdownMenuItem(
                        value: c.dialCode,
                        child: Text(
                          c.displayLabel(locale),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                  onChanged: widget.enabled
                      ? (v) {
                          if (v == null) return;
                          setState(() => _dialCode = v);
                          _onNationalChanged(_nationalCtrl.text);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _nationalCtrl,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: theme.primaryText),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: fieldDecoration.copyWith(
                    hintText: AppLocaleKeys.commonPhoneNationalHint.tr,
                    errorText: baseDecoration.errorText,
                  ),
                  validator: (_) {
                    final normalized = _currentNormalized();
                    if (normalized == null || normalized.isEmpty) {
                      return AppLocaleKeys.commonPhoneInvalid.tr;
                    }
                    return widget.validator?.call(normalized);
                  },
                  onChanged: _onNationalChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Form wrapper with built-in required validation.
Widget whatsappPhoneFormField({
  required GlobalKey<FormFieldState<String>> fieldKey,
  String? initialNormalized,
  InputDecoration? decoration,
  bool enabled = true,
  bool required = true,
  ValueChanged<String?>? onChanged,
}) {
  return FormField<String>(
    key: fieldKey,
    initialValue: initialNormalized,
    validator: (value) {
      final normalized = value?.trim();
      if (required && (normalized == null || normalized.isEmpty)) {
        return AppLocaleKeys.commonPhoneRequired.tr;
      }
      if (normalized != null &&
          normalized.isNotEmpty &&
          normalizeWhatsappPhone(normalized) == null) {
        return AppLocaleKeys.commonPhoneInvalid.tr;
      }
      return null;
    },
    builder: (state) {
      return WhatsappPhoneField(
        initialNormalized: state.value,
        enabled: enabled,
        decoration: (decoration ?? const InputDecoration()).copyWith(
          errorText: state.errorText,
        ),
        onChanged: (normalized) {
          state.didChange(normalized);
          onChanged?.call(normalized);
        },
      );
    },
  );
}

/// Drop-in replacement for [osPhoneTextFormField] with country selector.
class WhatsappPhoneTextFormField extends StatefulWidget {
  const WhatsappPhoneTextFormField({
    super.key,
    required this.controller,
    required this.decoration,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  State<WhatsappPhoneTextFormField> createState() =>
      _WhatsappPhoneTextFormFieldState();
}

class _WhatsappPhoneTextFormFieldState extends State<WhatsappPhoneTextFormField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();

  @override
  Widget build(BuildContext context) {
    return whatsappPhoneFormField(
      fieldKey: _fieldKey,
      initialNormalized: widget.controller.text.trim().isEmpty
          ? null
          : widget.controller.text.trim(),
      decoration: widget.decoration,
      enabled: widget.enabled,
      onChanged: (normalized) {
        widget.controller.text = normalized ?? '';
        widget.onChanged?.call(normalized ?? '');
      },
    );
  }
}
