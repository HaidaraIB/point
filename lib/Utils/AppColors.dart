import 'package:flutter/material.dart';

class AppColors {
  /// تدرج أزرار تسجيل الدخول (عميل / موظف) — نفس `MainButton` في شاشات المصادقة
  static LinearGradient get authLoginButtonGradient => const LinearGradient(
        colors: [
          Color(0xff19133F),
          Color(0xff19133F),
          Color(0xff19133F),
          Color(0xff19133F),
          Color(0xff19133F),
          Color(0xff2F133F),
          Color(0xff2F133F),
          Color(0xff2F133F),
          Color(0xff2F133F),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
      );

  static const Color primary = Color(0xff6736AE);
  // static const Color primaryFontColor = Color(0xff34AD93);
  static const Color primaryfontColor = Color(0xff344054);
  static const Color fontColorGrey = Color(0xff656565);
  static const Color grey = Color(0xff778087);
  static const Color greylight = Color(0xffD7DDE1);
  static const Color greyBackground = Color(0xffF2F3F5);
  static const Color unselected = Color(0xffE2E2E2);

  /// حذف دائم — أزرار تدميرية
  static const Color destructive = Color(0xffC62828);
  /// تعطيل / إجراءات عكسية غير حذف
  static const Color caution = Color(0xffE65100);
  /// تفعيل / نجاح
  static const Color success = Color(0xff2E7D32);
}
