import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Electronic stamp config used on OS vouchers / invoices (mirrors point_os).
class OsStampSettingsController extends GetxController {
  final stampText = 'وكالة نقطة - قسم الحسابات'.obs;
  final stampColorHex = '#1e1b4b'.obs;
  final stampEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    stampText.value = prefs.getString(StorageKeys.prefsOsStampText) ??
        stampText.value;
    stampColorHex.value = prefs.getString(StorageKeys.prefsOsStampColor) ??
        stampColorHex.value;
    stampEnabled.value =
        prefs.getBool(StorageKeys.prefsOsStampEnabled) ?? true;
  }

  Color get stampColor {
    final raw = stampColorHex.value.trim().replaceFirst('#', '');
    if (raw.length == 6) {
      final v = int.tryParse(raw, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return const Color(0xFF1e1b4b);
  }

  Future<void> setStampText(String value) async {
    stampText.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.prefsOsStampText, value);
  }

  Future<void> setStampColorHex(String value) async {
    var hex = value.trim();
    if (!hex.startsWith('#')) hex = '#$hex';
    stampColorHex.value = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.prefsOsStampColor, hex);
  }

  Future<void> setStampEnabled(bool value) async {
    stampEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.prefsOsStampEnabled, value);
  }
}
