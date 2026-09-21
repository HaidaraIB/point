import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads Point brand images once and exposes them as `data:` URIs for print HTML.
///
/// Print windows use `blob:` URLs, so relative asset paths cannot resolve.
class OsPrintAssets {
  OsPrintAssets._();

  static const headerBrandAsset = 'assets/print/brand.png';
  static const headerSloganAsset = 'assets/print/slogan.png';
  static const watermarkLogoAsset = 'assets/print/watermark_logo.png';
  static const sealAsset = 'assets/print/seal.png';
  static const voucherBrandAsset = 'assets/print/voucher_brand.png';
  static const paymentCardAsset = 'assets/images/card.png';
  static const paymentQiCardAsset = 'assets/images/qicard.png';
  static const paymentZainCashAsset = 'assets/images/zaincash.png';
  static const paymentFibAsset = 'assets/images/fib.png';
  static const almaraiRegularAsset = 'assets/fonts/Almarai-Regular.ttf';
  static const almaraiBoldAsset = 'assets/fonts/Almarai-Bold.ttf';

  static String? _headerBrandDataUri;
  static String? _headerSloganDataUri;
  static String? _watermarkLogoDataUri;
  static String? _sealDataUri;
  static String? _voucherBrandDataUri;
  static List<String> _paymentMethodDataUris = const [];
  static String? _almaraiRegularDataUri;
  static String? _almaraiBoldDataUri;
  static Future<void>? _loading;
  static bool _ready = false;

  static String get headerBrandDataUri => _headerBrandDataUri ?? '';
  static String get headerSloganDataUri => _headerSloganDataUri ?? '';
  static String get watermarkLogoDataUri => _watermarkLogoDataUri ?? '';
  static String get sealDataUri => _sealDataUri ?? '';
  static String get voucherBrandDataUri => _voucherBrandDataUri ?? '';
  static List<String> get paymentMethodDataUris => _paymentMethodDataUris;

  static bool get isLoaded => _ready;

  static bool get hasEmbeddedAlmarai =>
      _almaraiRegularDataUri != null &&
      _almaraiRegularDataUri!.isNotEmpty &&
      _almaraiBoldDataUri != null &&
      _almaraiBoldDataUri!.isNotEmpty;

  /// Inlined Almarai for PDF capture (no Google Fonts network / CORS in iframe).
  static String get embeddedAlmaraiFontFaceCss {
    final reg = _almaraiRegularDataUri;
    final bold = _almaraiBoldDataUri;
    if (reg == null || reg.isEmpty || bold == null || bold.isEmpty) {
      return '';
    }
    return '''
@font-face {
  font-family: 'Almarai';
  font-style: normal;
  font-weight: 300;
  font-display: block;
  src: url($reg) format('truetype');
}
@font-face {
  font-family: 'Almarai';
  font-style: normal;
  font-weight: 400;
  font-display: block;
  src: url($reg) format('truetype');
}
@font-face {
  font-family: 'Almarai';
  font-style: normal;
  font-weight: 700;
  font-display: block;
  src: url($bold) format('truetype');
}
@font-face {
  font-family: 'Almarai';
  font-style: normal;
  font-weight: 800;
  font-display: block;
  src: url($bold) format('truetype');
}
''';
  }

  /// Prefetch header comps + seal. Safe to call multiple times.
  static Future<void> ensureLoaded() async {
    if (!_ready) {
      await (_loading ??= _load());
    }
    if (_voucherBrandDataUri == null) {
      await _loadVoucherAssets();
    }
  }

  static Future<String> _pngDataUri(String asset) async {
    final bytes = await rootBundle.load(asset);
    return 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
  }

  static Future<String> _ttfDataUri(String asset) async {
    final bytes = await rootBundle.load(asset);
    return 'data:font/ttf;base64,${base64Encode(bytes.buffer.asUint8List())}';
  }

  static Future<void> _loadAlmaraiFonts() async {
    try {
      _almaraiRegularDataUri = await _ttfDataUri(almaraiRegularAsset);
    } catch (_) {
      _almaraiRegularDataUri = '';
    }
    try {
      _almaraiBoldDataUri = await _ttfDataUri(almaraiBoldAsset);
    } catch (_) {
      _almaraiBoldDataUri = '';
    }
  }

  static Future<void> _load() async {
    try {
      _headerBrandDataUri = await _pngDataUri(headerBrandAsset);
    } catch (_) {
      _headerBrandDataUri = '';
    }

    try {
      _headerSloganDataUri = await _pngDataUri(headerSloganAsset);
    } catch (_) {
      _headerSloganDataUri = '';
    }


    try {
      _watermarkLogoDataUri = await _pngDataUri(watermarkLogoAsset);
    } catch (_) {
      _watermarkLogoDataUri = '';
    }

    try {
      _sealDataUri = await _pngDataUri(sealAsset);
    } catch (_) {
      _sealDataUri = '';
    }

    await _loadVoucherAssets();
    await _loadPaymentMethodAssets();
    await _loadAlmaraiFonts();

    _ready = true;
  }

  static Future<void> _loadPaymentMethodAssets() async {
    final assets = [
      paymentCardAsset,
      paymentQiCardAsset,
      paymentZainCashAsset,
      paymentFibAsset,
    ];
    final uris = <String>[];
    for (final asset in assets) {
      try {
        uris.add(await _pngDataUri(asset));
      } catch (_) {
        // Skip missing payment icons; footer still prints.
      }
    }
    _paymentMethodDataUris = uris;
  }

  static Future<void> _loadVoucherAssets() async {
    try {
      _voucherBrandDataUri = await _pngDataUri(voucherBrandAsset);
    } catch (_) {
      _voucherBrandDataUri = '';
    }
  }
}
