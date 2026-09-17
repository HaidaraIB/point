import 'package:get/get.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the Email Hub page tab across navigations.
class OsEmailHubTabPersistence {
  OsEmailHubTabPersistence._();

  static const prefsKey = StorageKeys.prefsOsEmailHubTabKey;
  static const invoices = 'invoices';
  static const quotations = 'quotations';
  static const payslips = 'payslips';
  static const appreciation = 'appreciation';
  static const penalties = 'penalties';
  static const logs = 'logs';
  static const settings = 'settings';
  static const names = [
    invoices,
    quotations,
    payslips,
    appreciation,
    penalties,
    logs,
    settings,
  ];

  static int indexFromName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return -1;
    final key = raw.trim().toLowerCase();
    final byName = names.indexOf(key);
    if (byName >= 0) return byName;
    final n = int.tryParse(key);
    if (n != null && n >= 0 && n < names.length) return n;
    return -1;
  }

  static int indexFromRoute() {
    final raw = Get.parameters['tab'];
    final idx = indexFromName(raw);
    return idx >= 0 ? idx : 0;
  }

  static bool hasRouteTab() => indexFromName(Get.parameters['tab']) >= 0;

  static Future<int> loadSavedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = indexFromName(prefs.getString(prefsKey));
    return idx >= 0 ? idx : 0;
  }

  static Future<void> saveIndex(int index) async {
    final safe = index.clamp(0, names.length - 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, names[safe]);
  }
}
