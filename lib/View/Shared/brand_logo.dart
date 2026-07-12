import 'package:flutter/material.dart';
import 'package:point/Utils/AppImages.dart';

/// Branded logo for centered layouts (splash, session setup, auth chooser).
/// Dark mode uses the white wordmark; light mode uses the colored wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width,
    this.height,
    this.iconOnlyInDark = false,
  });

  final double? width;
  final double? height;

  /// When true, dark mode shows only the white "P" icon instead of the wordmark.
  final bool iconOnlyInDark;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useIconOnly = isDark && iconOnlyInDark;

    final asset = isDark
        ? (iconOnlyInDark
            ? AppImages.images.logoIconWhite
            : AppImages.images.logo)
        : AppImages.images.logocolored;

    final resolvedHeight = height ?? 80;
    final resolvedWidth =
        useIconOnly ? resolvedHeight : (width ?? resolvedHeight);

    return Image.asset(
      asset,
      width: resolvedWidth,
      height: resolvedHeight,
      fit: BoxFit.contain,
    );
  }
}
