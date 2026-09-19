import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show Bidi;

/// On mobile soft keyboards, Enter inserts a newline ([TextInputAction.newline]).
/// On desktop/web, Enter sends and Shift+Enter inserts a newline.
bool chatComposerEnterKeySendsMessage() {
  if (kIsWeb) return true;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => false,
    _ => true,
  };
}

TextInputAction chatComposerTextInputAction() =>
    chatComposerEnterKeySendsMessage()
    ? TextInputAction.send
    : TextInputAction.newline;

/// كشف موثوق لـ Shift على الويب وسطح المكتب (لـ Enter مقابل Shift+Enter).
bool composerShiftPressed() {
  final pressed = HardwareKeyboard.instance.logicalKeysPressed;
  return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
      pressed.contains(LogicalKeyboardKey.shiftRight) ||
      HardwareKeyboard.instance.isShiftPressed;
}

bool composerControlPressed() {
  final pressed = HardwareKeyboard.instance.logicalKeysPressed;
  return pressed.contains(LogicalKeyboardKey.controlLeft) ||
      pressed.contains(LogicalKeyboardKey.controlRight) ||
      HardwareKeyboard.instance.isControlPressed;
}

/// Paragraph direction for editable fields from **typed content** (first strong
/// character), not from app UI locale.
///
/// Empty → `null` (inherit ambient direction for caret/hint placement).
/// Arabic-first → RTL. Any other content (Latin, digits, `+`, URLs) → LTR.
TextDirection? typedInputTextDirection(String text) {
  if (text.trim().isEmpty) return null;
  if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
  return TextDirection.ltr;
}

/// Hint placeholder direction (e.g. `+964 770 000 0000` stays LTR in Arabic UI).
TextDirection? typedInputHintTextDirection(String? hintText) {
  if (hintText == null || hintText.trim().isEmpty) return null;
  return typedInputTextDirection(hintText);
}

/// Chat composer alias — same typed-content rules as [typedInputTextDirection].
TextDirection? textDirectionForTypedChatMessage(
  String text,
  TextDirection ambientDirection,
) {
  return typedInputTextDirection(text);
}

bool shouldUseRtlVisualCaretNavigation(
  String text,
  TextDirection ambientDirection,
) {
  final resolved = typedInputTextDirection(text);
  return resolved == TextDirection.rtl;
}

/// Rebuilds when [controller] text changes and supplies resolved directions.
class TypedTextDirection extends StatefulWidget {
  const TypedTextDirection({
    super.key,
    required this.controller,
    this.hintText,
    required this.builder,
  });

  final TextEditingController controller;
  final String? hintText;
  final Widget Function(
    BuildContext context,
    TextDirection? textDirection,
    TextDirection? hintTextDirection,
  ) builder;

  @override
  State<TypedTextDirection> createState() => _TypedTextDirectionState();
}

class _TypedTextDirectionState extends State<TypedTextDirection> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant TypedTextDirection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      typedInputTextDirection(widget.controller.text),
      typedInputHintTextDirection(widget.hintText),
    );
  }
}

/// [TextField] with paragraph direction from typed content, not UI locale.
Widget typedDirectionTextField({
  required TextEditingController controller,
  required InputDecoration decoration,
  ValueChanged<String>? onChanged,
  TextInputType? keyboardType,
  int? maxLines = 1,
  int? minLines,
  bool readOnly = false,
  VoidCallback? onTap,
  TextInputAction? textInputAction,
  ValueChanged<String>? onSubmitted,
  List<TextInputFormatter>? inputFormatters,
  TextStyle? style,
  TextAlignVertical? textAlignVertical,
  String? hintText,
  bool obscureText = false,
  bool enabled = true,
  FocusNode? focusNode,
  TextAlign textAlign = TextAlign.start,
  bool autofocus = false,
}) {
  final hint = hintText ?? decoration.hintText;
  return TypedTextDirection(
    controller: controller,
    hintText: hint,
    builder: (context, textDirection, hintTextDirection) => TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      onTap: onTap,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      style: style,
      textAlignVertical: textAlignVertical,
      textDirection: textDirection,
      obscureText: obscureText,
      enabled: enabled,
      focusNode: focusNode,
      textAlign: textAlign,
      autofocus: autofocus,
      decoration: decoration.copyWith(hintTextDirection: hintTextDirection),
    ),
  );
}

/// [TextFormField] with paragraph direction from typed content, not UI locale.
Widget typedDirectionTextFormField({
  required TextEditingController controller,
  required InputDecoration decoration,
  ValueChanged<String>? onChanged,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  int? maxLines = 1,
  int? minLines,
  bool readOnly = false,
  VoidCallback? onTap,
  TextInputAction? textInputAction,
  ValueChanged<String>? onFieldSubmitted,
  List<TextInputFormatter>? inputFormatters,
  TextStyle? style,
  TextAlignVertical? textAlignVertical,
  String? hintText,
  bool obscureText = false,
  bool enabled = true,
  FocusNode? focusNode,
  TextAlign textAlign = TextAlign.start,
  int? maxLength,
}) {
  final hint = hintText ?? decoration.hintText;
  return TypedTextDirection(
    controller: controller,
    hintText: hint,
    builder: (context, textDirection, hintTextDirection) => TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      onTap: onTap,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      style: style,
      textAlignVertical: textAlignVertical,
      textDirection: textDirection,
      obscureText: obscureText,
      enabled: enabled,
      focusNode: focusNode,
      textAlign: textAlign,
      maxLength: maxLength,
      decoration: decoration.copyWith(hintTextDirection: hintTextDirection),
    ),
  );
}

TextSelection? remapHorizontalArrowForRtlVisual({
  required String text,
  required TextSelection selection,
  required bool isArrowLeft,
  required bool shiftPressed,
  required bool ctrlPressed,
}) {
  final textLength = text.length;
  if (!selection.isValid || textLength < 0) return null;
  if (selection.baseOffset < 0 || selection.extentOffset < 0) return null;

  final minOffset = 0;
  final maxOffset = textLength;

  int clamp(int value) => value.clamp(minOffset, maxOffset);

  if (!shiftPressed && !selection.isCollapsed) {
    final collapseTo = isArrowLeft ? selection.end : selection.start;
    return TextSelection.collapsed(offset: clamp(collapseTo));
  }

  if (shiftPressed) {
    final nextExtent = ctrlPressed
        ? (isArrowLeft
              ? _nextWordBoundaryForward(text, selection.extentOffset)
              : _nextWordBoundaryBackward(text, selection.extentOffset))
        : clamp(selection.extentOffset + (isArrowLeft ? 1 : -1));
    if (nextExtent == selection.extentOffset) return selection;
    return TextSelection(
      baseOffset: selection.baseOffset,
      extentOffset: nextExtent,
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  final nextOffset = ctrlPressed
      ? (isArrowLeft
            ? _nextWordBoundaryForward(text, selection.extentOffset)
            : _nextWordBoundaryBackward(text, selection.extentOffset))
      : clamp(selection.extentOffset + (isArrowLeft ? 1 : -1));
  if (nextOffset == selection.extentOffset) return selection;
  return TextSelection.collapsed(offset: nextOffset);
}

int _nextWordBoundaryForward(String text, int from) {
  final len = text.length;
  if (from >= len) return len;
  var i = from;
  while (i < len && _isWordChar(text.codeUnitAt(i))) {
    i++;
  }
  while (i < len && !_isWordChar(text.codeUnitAt(i))) {
    i++;
  }
  return i;
}

int _nextWordBoundaryBackward(String text, int from) {
  if (from <= 0) return 0;
  var i = from;
  while (i > 0 && !_isWordChar(text.codeUnitAt(i - 1))) {
    i--;
  }
  while (i > 0 && _isWordChar(text.codeUnitAt(i - 1))) {
    i--;
  }
  return i;
}

bool _isWordChar(int codeUnit) {
  return (codeUnit >= 48 && codeUnit <= 57) || // 0-9
      (codeUnit >= 65 && codeUnit <= 90) || // A-Z
      (codeUnit >= 97 && codeUnit <= 122) || // a-z
      codeUnit == 95 || // _
      (codeUnit >= 0x0600 && codeUnit <= 0x06FF);
}
