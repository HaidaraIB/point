import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show Bidi;

/// كشف موثوق لـ Shift على الويب وسطح المكتب (لـ Enter مقابل Shift+Enter).
bool composerShiftPressed() {
  final pressed = HardwareKeyboard.instance.logicalKeysPressed;
  return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
      pressed.contains(LogicalKeyboardKey.shiftRight) ||
      HardwareKeyboard.instance.isShiftPressed;
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
