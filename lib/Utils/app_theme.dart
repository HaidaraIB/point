import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light, AppThemeExtension.light);

  static ThemeData dark() => _build(Brightness.dark, AppThemeExtension.dark);

  static ThemeData _build(Brightness brightness, AppThemeExtension ext) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: ext.cardSurface,
      onSurface: ext.primaryText,
      surfaceContainerHighest: ext.elevatedSurface,
      outline: ext.border,
      outlineVariant: ext.border,
    );

    final almaraiTextTheme = GoogleFonts.almaraiTextTheme(base.textTheme).apply(
      bodyColor: ext.primaryText,
      displayColor: ext.primaryText,
    );

    final overlayStyle = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: ext.pageBackground,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: ext.pageBackground,
          );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ext.pageBackground,
      canvasColor: ext.pageBackground,
      cardColor: ext.cardSurface,
      dividerColor: ext.border,
      shadowColor: ext.shadowColor,
      extensions: [ext],
      appBarTheme: AppBarTheme(
        backgroundColor: ext.cardSurface,
        foregroundColor: ext.primaryText,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
        iconTheme: IconThemeData(color: ext.primaryText),
        titleTextStyle: almaraiTextTheme.titleLarge?.copyWith(
          color: ext.primaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ext.cardSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: almaraiTextTheme.titleLarge?.copyWith(
          color: ext.primaryText,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: almaraiTextTheme.bodyMedium?.copyWith(
          color: ext.primaryText,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ext.cardSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: ext.cardSurface,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: ext.navSurface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: ext.cardSurface,
        surfaceTintColor: Colors.transparent,
        textStyle: almaraiTextTheme.bodyMedium?.copyWith(color: ext.primaryText),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(ext.cardSurface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ext.inputFill,
        hintStyle: TextStyle(color: ext.mutedText),
        labelStyle: TextStyle(color: ext.secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ext.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ext.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ext.accentText,
        linearTrackColor: ext.unselected,
        circularTrackColor: ext.unselected,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ext.accentText),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ext.accentText,
          side: BorderSide(color: ext.accentBorder),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ext.secondaryText,
        textColor: ext.primaryText,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return ext.unselected;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return ext.mutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.4);
          }
          return ext.unselected;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ext.panelTint,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: ext.primaryText),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide(color: ext.border),
        checkmarkColor: Colors.white,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(ext.panelTint),
        dataRowColor: WidgetStateProperty.all(ext.cardSurface),
        headingTextStyle: almaraiTextTheme.labelLarge?.copyWith(
          color: ext.primaryText,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: almaraiTextTheme.bodyMedium?.copyWith(
          color: ext.primaryText,
        ),
        dividerThickness: 1,
      ),
      textTheme: almaraiTextTheme,
      iconTheme: IconThemeData(color: ext.primaryText),
      primaryIconTheme: const IconThemeData(color: Colors.white),
    );
  }
}
