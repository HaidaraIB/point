import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/text_input_bidi.dart';

Widget osEmailHubTextField(
  BuildContext context, {
  required String label,
  TextEditingController? controller,
  String? value,
  ValueChanged<String>? onChanged,
  TextInputType? keyboardType,
  int maxLines = 1,
  bool showLabel = true,
  String? hintText,
  Widget? prefixIcon,
}) {
  final decoration = _fieldDecoration(
    context,
    hintText: hintText,
    prefixIcon: prefixIcon,
  );

  if (controller != null) {
    return _OsEmailHubTextFieldShell(
      context: context,
      label: label,
      showLabel: showLabel,
      child: TypedTextDirection(
        controller: controller,
        hintText: hintText,
        builder: (context, textDirection, hintTextDirection) => TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textDirection: textDirection,
          decoration: decoration.copyWith(hintTextDirection: hintTextDirection),
        ),
      ),
    );
  }

  return _OsEmailHubBoundTextField(
    label: label,
    showLabel: showLabel,
    value: value ?? '',
    onChanged: onChanged,
    keyboardType: keyboardType,
    maxLines: maxLines,
    decoration: decoration,
  );
}

class _OsEmailHubBoundTextField extends StatefulWidget {
  const _OsEmailHubBoundTextField({
    required this.label,
    required this.value,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.showLabel = true,
    required this.decoration,
  });

  final String label;
  final String value;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool showLabel;
  final InputDecoration decoration;

  @override
  State<_OsEmailHubBoundTextField> createState() =>
      _OsEmailHubBoundTextFieldState();
}

class _OsEmailHubBoundTextFieldState extends State<_OsEmailHubBoundTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _OsEmailHubBoundTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.value = _controller.value.copyWith(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
        composing: TextRange.empty,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OsEmailHubTextFieldShell(
      context: context,
      label: widget.label,
      showLabel: widget.showLabel,
      child: TypedTextDirection(
        controller: _controller,
        hintText: widget.decoration.hintText,
        builder: (context, textDirection, hintTextDirection) => TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          textDirection: textDirection,
          decoration: widget.decoration.copyWith(
            hintTextDirection: hintTextDirection,
          ),
        ),
      ),
    );
  }
}

class _OsEmailHubTextFieldShell extends StatelessWidget {
  const _OsEmailHubTextFieldShell({
    required this.context,
    required this.label,
    required this.child,
    this.showLabel = true,
  });

  final BuildContext context;
  final String label;
  final Widget child;
  final bool showLabel;

  @override
  Widget build(BuildContext _) {
    final theme = context.appTheme;
    if (!showLabel) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefixIcon,
}) {
  final theme = context.appTheme;
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: theme.panelTint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    isDense: true,
  );
}

Widget osEmailHubSwitchRow(
  BuildContext context, {
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final theme = context.appTheme;
  return Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(fontSize: 13, color: theme.primaryText),
        ),
      ),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

Widget osEmailHubEnumDropdown({
  required BuildContext context,
  required String label,
  required String value,
  required List<String> options,
  required String Function(String) labelFor,
  required ValueChanged<String?> onChanged,
}) {
  final theme = context.appTheme;
  final selected = options.contains(value) ? value : options.first;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.secondaryText,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: selected,
        items: options
            .map(
              (opt) => DropdownMenuItem<String>(
                value: opt,
                child: Text(
                  labelFor(opt),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: theme.panelTint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
      ),
    ],
  );
}

Widget osEmailHubDocumentDropdown<T>({
  required BuildContext context,
  required String label,
  required T? value,
  required List<T> items,
  required String Function(T) itemLabel,
  required ValueChanged<T?> onChanged,
}) {
  final theme = context.appTheme;
  T? selected;
  if (value != null) {
    for (final item in items) {
      if (item == value) {
        selected = item;
        break;
      }
    }
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.secondaryText,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        initialValue: selected,
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabel(item),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: theme.panelTint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
      ),
    ],
  );
}
