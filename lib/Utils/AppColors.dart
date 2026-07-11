import 'package:flutter/material.dart';

class AppColors {
  /// تدرج أزرار تسجيل الدخول (عميل / موظف) — نفس `MainButton` في شاشات المصادقة
  static LinearGradient get authLoginButtonGradient => const LinearGradient(
        colors: [
          Color(0xff1f1957),
          Color(0xff514091),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
      );

  static const Color primary = Color(0xff514091);
  static const Color primaryDark = Color(0xff1f1957);

  /// @deprecated Use `context.appTheme.primaryText` instead.
  static const Color primaryfontColor = Color(0xff344054);

  /// @deprecated Use `context.appTheme.secondaryText` instead.
  static const Color fontColorGrey = Color(0xff656565);

  /// @deprecated Use `context.appTheme.mutedText` instead.
  static const Color grey = Color(0xff778087);

  /// @deprecated Use `context.appTheme.border` instead.
  static const Color greylight = Color(0xffD7DDE1);

  /// @deprecated Use `context.appTheme.pageBackground` instead.
  static const Color greyBackground = Color(0xffF2F3F5);

  /// @deprecated Use `context.appTheme.unselected` instead.
  static const Color unselected = Color(0xffE2E2E2);

  /// حذف دائم — أزرار تدميرية
  static const Color destructive = Color(0xffC62828);
  /// تعطيل / إجراءات عكسية غير حذف
  static const Color caution = Color(0xffE65100);
  /// تفعيل / نجاح
  static const Color success = Color(0xff2E7D32);
}
