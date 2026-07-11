import 'package:flutter/material.dart';
import 'package:point/Utils/AppImages.dart';

/// Branded logo for centered layouts (splash, session setup, auth chooser).
/// Dark mode uses the white icon-only asset; light mode uses the full wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width,
    this.height,
    this.iconOnlyInDark = true,
  });

  final double? width;
  final double? height;

  /// When true (default), dark mode shows only the white "P" icon.
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
