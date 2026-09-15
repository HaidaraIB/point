import 'package:barcode/barcode.dart';

/// Inline SVG barcodes / QR codes for Point OS print documents.
class OsPrintCodes {
  OsPrintCodes._();

  /// QR code SVG (default size matches the invoice footer).
  static String qrSvg(
    String data, {
    double width = 72,
    double height = 72,
  }) {
    if (data.trim().isEmpty) return '';
    try {
      return Barcode.qrCode().toSvg(
        data,
        width: width,
        height: height,
        drawText: false,
        color: 0xFF2B2A6B,
      );
    } catch (_) {
      return '';
    }
  }

  /// Code128 barcode SVG for document refs like `INV-001`.
  static String code128Svg(
    String data, {
    double width = 160,
    double height = 36,
  }) {
    final value = data.trim();
    if (value.isEmpty) return '';
    try {
      return Barcode.code128().toSvg(
        value,
        width: width,
        height: height,
        drawText: false,
        color: 0xFF2B2A6B,
      );
    } catch (_) {
      return '';
    }
  }
}
