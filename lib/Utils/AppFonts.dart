import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App typeface. Almarai is registered at runtime via [GoogleFonts],
/// not as a pubspec asset — always go through [text] / [family].
class Appfonts {
  Appfonts._();

  static String get family => GoogleFonts.almarai().fontFamily ?? 'Almarai';

  /// Loads Almarai (required) and returns a [TextStyle] using it.
  static TextStyle text({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) {
    return GoogleFonts.almarai(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
    );
  }
}
