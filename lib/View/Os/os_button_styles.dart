import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppFonts.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Shared OS action button styles (readable on dark theme).
///
/// Page headers, filter bars, toolbars, and cards should use
/// [primaryCompact] / [secondaryCompact] (or [inline] inside cards).
/// Keep [primary] / [secondary] for rare full-size CTAs only.
class OsButtonStyles {
  OsButtonStyles._();

  static const headerPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 14);
  static const headerMinSize = Size(48, 48);

  static TextStyle get headerTextStyle => Appfonts.text(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      );

  static const compactPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  static const compactMinSize = Size(0, 42);

  static TextStyle get compactTextStyle => Appfonts.text(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      );

  static const inlinePadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 6);

  static TextStyle get inlineTextStyle => Appfonts.text(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      );

  /// Secondary / toggle actions — elevated fill + primary text (not dim outline).
  static ButtonStyle secondary(
    AppThemeExtension theme, {
    bool active = false,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    TextStyle? textStyle,
    VisualDensity visualDensity = VisualDensity.standard,
    MaterialTapTargetSize tapTargetSize = MaterialTapTargetSize.padded,
  }) {
    return FilledButton.styleFrom(
      foregroundColor: active ? Colors.white : theme.primaryText,
      backgroundColor: active ? AppColors.primary : theme.elevatedSurface,
      disabledForegroundColor: theme.mutedText,
      disabledBackgroundColor: theme.unselected,
      side: BorderSide(
        color: active ? AppColors.primary : theme.border,
      ),
      minimumSize: minimumSize ?? headerMinSize,
      padding: padding ?? headerPadding,
      textStyle: textStyle ?? headerTextStyle,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      iconSize: 18,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  /// Primary CTA (new invoice, save, etc.).
  static ButtonStyle primary({
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    TextStyle? textStyle,
    VisualDensity visualDensity = VisualDensity.standard,
    MaterialTapTargetSize tapTargetSize = MaterialTapTargetSize.padded,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: minimumSize ?? headerMinSize,
      padding: padding ?? headerPadding,
      textStyle: textStyle ?? headerTextStyle,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      iconSize: 18,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  /// Compact secondary for toolbars / card actions.
  static ButtonStyle secondaryCompact(
    AppThemeExtension theme, {
    bool active = false,
  }) {
    return secondary(
      theme,
      active: active,
      padding: compactPadding,
      minimumSize: compactMinSize,
      textStyle: compactTextStyle,
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// Compact primary so toolbar pairs share the same height.
  static ButtonStyle primaryCompact() {
    return primary(
      padding: compactPadding,
      minimumSize: compactMinSize,
      textStyle: compactTextStyle,
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// Muted tool chip — matches OS secondary buttons on dark cards.
  static ButtonStyle inlineTool(AppThemeExtension theme) {
    return FilledButton.styleFrom(
      foregroundColor: theme.secondaryText,
      backgroundColor: theme.inputFill,
      disabledForegroundColor: theme.mutedText,
      disabledBackgroundColor: theme.unselected,
      side: BorderSide(color: theme.border),
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: inlineTextStyle.copyWith(color: theme.secondaryText),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      iconSize: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  /// Compact filled CTA that matches [inline] height.
  static ButtonStyle inlinePrimary({Color? backgroundColor}) {
    final bg = backgroundColor ?? AppColors.primary;
    return FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: inlineTextStyle.copyWith(color: Colors.white),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      iconSize: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  /// Secondary decision (reject) — palette caution, soft fill.
  static ButtonStyle inlineCaution() {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.caution.withValues(alpha: 0.12),
      foregroundColor: AppColors.caution,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: inlineTextStyle.copyWith(color: AppColors.caution),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      iconSize: 16,
      side: BorderSide(color: AppColors.caution.withValues(alpha: 0.45)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
