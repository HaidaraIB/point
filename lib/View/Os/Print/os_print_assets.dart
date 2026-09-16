import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads Point brand images once and exposes them as `data:` URIs for print HTML.
///
/// Print windows use `blob:` URLs, so relative asset paths cannot resolve.
class OsPrintAssets {
  OsPrintAssets._();

  static const headerBrandAsset = 'assets/print/brand.png';
  static const headerInfoAsset = 'assets/print/info.png';
  static const headerSloganAsset = 'assets/print/slogan.png';
  static const watermarkAsset = 'assets/print/watermark.png';
  static const watermarkLogoAsset = 'assets/print/watermark_logo.png';
  static const sealAsset = 'assets/print/seal.png';
  static const voucherBrandAsset = 'assets/print/voucher_brand.png';
  static const voucherInfoAsset = 'assets/print/voucher_info.png';

  static String? _headerBrandDataUri;
  static String? _headerInfoDataUri;
  static String? _headerSloganDataUri;
  static String? _watermarkDataUri;
  static String? _watermarkLogoDataUri;
  static String? _sealDataUri;
  static String? _voucherBrandDataUri;
  static String? _voucherInfoDataUri;
  static Future<void>? _loading;
  static bool _ready = false;

  static String get headerBrandDataUri => _headerBrandDataUri ?? '';
  static String get headerInfoDataUri => _headerInfoDataUri ?? '';
  static String get headerSloganDataUri => _headerSloganDataUri ?? '';
  static String get watermarkDataUri => _watermarkDataUri ?? '';
  static String get watermarkLogoDataUri => _watermarkLogoDataUri ?? '';
  static String get sealDataUri => _sealDataUri ?? '';
  static String get voucherBrandDataUri => _voucherBrandDataUri ?? '';
  static String get voucherInfoDataUri => _voucherInfoDataUri ?? '';

  static bool get isLoaded => _ready;

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

  static Future<void> _load() async {
    try {
      _headerBrandDataUri = await _pngDataUri(headerBrandAsset);
    } catch (_) {
      _headerBrandDataUri = '';
    }

    try {
      _headerInfoDataUri = await _pngDataUri(headerInfoAsset);
    } catch (_) {
      _headerInfoDataUri = '';
    }

    try {
      _headerSloganDataUri = await _pngDataUri(headerSloganAsset);
    } catch (_) {
      _headerSloganDataUri = '';
    }

    try {
      _watermarkDataUri = await _pngDataUri(watermarkAsset);
    } catch (_) {
      _watermarkDataUri = '';
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

    _ready = true;
  }

  static Future<void> _loadVoucherAssets() async {
    try {
      _voucherBrandDataUri = await _pngDataUri(voucherBrandAsset);
    } catch (_) {
      _voucherBrandDataUri = '';
    }

    try {
      _voucherInfoDataUri = await _pngDataUri(voucherInfoAsset);
    } catch (_) {
      _voucherInfoDataUri = '';
    }
  }
}
