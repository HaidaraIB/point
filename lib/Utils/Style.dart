import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';

class Style {
  static BoxDecoration roundedContainer(BuildContext context) {
    final appTheme = context.appTheme;
    return BoxDecoration(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(25),
        topRight: Radius.circular(25),
      ),
      color: appTheme.cardSurface,
      boxShadow: [
        BoxShadow(
          color: appTheme.shadowColor,
          blurRadius: 10,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }

  static TextStyle sectionTitle(BuildContext context, {double fontSize = 16}) {
    final theme = context.appTheme;
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: theme.accentText,
    );
  }

  static TextStyle caption(BuildContext context, {double fontSize = 12}) {
    return TextStyle(
      fontSize: fontSize,
      color: context.appTheme.secondaryText,
    );
  }

  static TextStyle accentLabel(BuildContext context, {double fontSize = 13}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: context.appTheme.accentText,
    );
  }
}
