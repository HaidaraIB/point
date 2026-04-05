import 'package:flutter/material.dart' show TextDirection;
import 'package:intl/intl.dart' show Bidi;

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
