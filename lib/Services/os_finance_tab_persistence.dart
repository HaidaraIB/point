import 'package:get/get.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the Finance page tab across navigations.
///
/// Prefers an explicit route `tab` query (`overview` | `accounts` | `vouchers`
/// or `0`–`2`), otherwise restores the last saved preference.
class OsFinanceTabPersistence {
  OsFinanceTabPersistence._();

  static const prefsKey = StorageKeys.prefsOsFinanceTabKey;
  static const overview = 'overview';
  static const accounts = 'accounts';
  static const vouchers = 'vouchers';
  static const names = [overview, accounts, vouchers];

  static int indexFromName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return -1;
    final key = raw.trim().toLowerCase();
    final byName = names.indexOf(key);
    if (byName >= 0) return byName;
    final n = int.tryParse(key);
    if (n != null && n >= 0 && n < names.length) return n;
    return -1;
  }

  /// Synchronous route-only resolve (safe for [TabController] init).
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
