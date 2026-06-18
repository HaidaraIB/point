import 'package:flutter/foundation.dart';
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

/// يحدد اتجاه حقل إدخال الرسالة من **محتوى النص** (أول حرف اتجاهي قوي)،
/// وليس من اتجاه واجهة التطبيق.
///
/// عند الفراغ يُرجع `null` ليستخدم [TextField] الاتجاه الموروث (لغة التطبيق للتلميح).
TextDirection? textDirectionForTypedChatMessage(
  String text,
  TextDirection ambientDirection,
) {
  if (text.trim().isEmpty) return null;
  if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
  if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
  return ambientDirection;
}

bool shouldUseRtlVisualCaretNavigation(
  String text,
  TextDirection ambientDirection,
) {
  final resolved = textDirectionForTypedChatMessage(text, ambientDirection);
  return resolved == TextDirection.rtl;
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
