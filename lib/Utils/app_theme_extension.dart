import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';

AppThemeExtension resolveAppTheme([BuildContext? context]) {
  if (context != null) {
    return Theme.of(context).extension<AppThemeExtension>() ??
        AppThemeExtension.light;
  }
  return Get.theme.extension<AppThemeExtension>() ?? AppThemeExtension.light;
}

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.pageBackground,
    required this.cardSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.border,
    required this.inputFill,
    required this.unselected,
    required this.panelTint,
    required this.shadowColor,
    required this.elevatedSurface,
    required this.accentText,
    required this.accentBorder,
    required this.navSurface,
    required this.onNavSurface,
  });

  final Color pageBackground;
  final Color cardSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final Color border;
  final Color inputFill;
  final Color unselected;
  final Color panelTint;
  final Color shadowColor;
  final Color elevatedSurface;
  final Color accentText;
  final Color accentBorder;
  /// Dark brand fill for sidebar, headers, and dialog banners.
  final Color navSurface;
  /// Readable text/icons on [navSurface].
  final Color onNavSurface;

  static const light = AppThemeExtension(
    pageBackground: Color(0xffF2F3F5),
    cardSurface: Color(0xffffffff),
    primaryText: Color(0xff344054),
    secondaryText: Color(0xff656565),
    mutedText: Color(0xff778087),
    border: Color(0xffD7DDE1),
    inputFill: Color(0xffF1F5F9),
    unselected: Color(0xffE2E2E2),
    panelTint: Color(0xffF7F6FF),
    shadowColor: Color(0x1A000000),
    elevatedSurface: Color(0xffffffff),
    accentText: AppColors.primary,
    accentBorder: AppColors.primary,
    navSurface: AppColors.primary,
    onNavSurface: Colors.white,
  );

  static const dark = AppThemeExtension(
    pageBackground: Color(0xff0F0F14),
    cardSurface: Color(0xff1A1A24),
    primaryText: Color(0xffE8EAED),
    secondaryText: Color(0xffA0A4AB),
    mutedText: Color(0xff7A7F88),
    border: Color(0xff2E2E3A),
    inputFill: Color(0xff1E1E28),
    unselected: Color(0xff2A2A34),
    panelTint: Color(0xff1F1A2E),
    shadowColor: Color(0x66000000),
    elevatedSurface: Color(0xff22222E),
    accentText: Color(0xffB8AAE8),
    accentBorder: Color(0x998B7CC8),
    navSurface: AppColors.primary,
    onNavSurface: Colors.white,
  );

  @override
  AppThemeExtension copyWith({
    Color? pageBackground,
    Color? cardSurface,
    Color? primaryText,
    Color? secondaryText,
    Color? mutedText,
    Color? border,
    Color? inputFill,
    Color? unselected,
    Color? panelTint,
    Color? shadowColor,
    Color? elevatedSurface,
    Color? accentText,
    Color? accentBorder,
    Color? navSurface,
    Color? onNavSurface,
  }) {
    return AppThemeExtension(
      pageBackground: pageBackground ?? this.pageBackground,
      cardSurface: cardSurface ?? this.cardSurface,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      mutedText: mutedText ?? this.mutedText,
      border: border ?? this.border,
      inputFill: inputFill ?? this.inputFill,
      unselected: unselected ?? this.unselected,
      panelTint: panelTint ?? this.panelTint,
      shadowColor: shadowColor ?? this.shadowColor,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      accentText: accentText ?? this.accentText,
      accentBorder: accentBorder ?? this.accentBorder,
      navSurface: navSurface ?? this.navSurface,
      onNavSurface: onNavSurface ?? this.onNavSurface,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      border: Color.lerp(border, other.border, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      unselected: Color.lerp(unselected, other.unselected, t)!,
      panelTint: Color.lerp(panelTint, other.panelTint, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      accentBorder: Color.lerp(accentBorder, other.accentBorder, t)!,
      navSurface: Color.lerp(navSurface, other.navSurface, t)!,
      onNavSurface: Color.lerp(onNavSurface, other.onNavSurface, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeExtension get appTheme {
    final ext = Theme.of(this).extension<AppThemeExtension>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? AppThemeExtension.dark
        : AppThemeExtension.light;
  }

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get accentForeground => appTheme.accentText;

  /// Readable text on a filled surface (handles legacy white fills in dark mode).
  Color textOnFill(Color fill) {
    return fill.computeLuminance() > 0.55
        ? AppThemeExtension.light.primaryText
        : appTheme.primaryText;
  }

  Color hintOnFill(Color fill) {
    return fill.computeLuminance() > 0.55
        ? AppThemeExtension.light.mutedText
        : appTheme.mutedText;
  }

  /// Status/count chip background: light tints in light mode, translucent in dark.
  Color statusChipBackground(Color foreground, Color lightBackground) {
    if (Theme.of(this).brightness == Brightness.dark) {
      return foreground.withValues(alpha: 0.18);
    }
    return lightBackground;
  }

  WidgetStateProperty<Color?> get tableDataRowColor =>
      WidgetStateProperty.all(appTheme.cardSurface);

  WidgetStateProperty<Color?> get tableHeadingRowColor =>
      WidgetStateProperty.all(appTheme.panelTint);
}
