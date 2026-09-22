import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OsMessagingHubTabPersistence {
  OsMessagingHubTabPersistence._();

  static const prefsKey = StorageKeys.prefsOsMessagingHubTabKey;
  static const send = 'send';
  static const logs = 'logs';
  static const names = [send, logs];

  static int get logsIndex => names.indexOf(logs);

  /// Maps legacy 3-tab indices (`send` | `invoices` | `logs`) to the current
  /// 2-tab layout (`send` | `logs`).
  static int migrateLegacyIndex(int raw) {
    if (raw <= 0) return 0;
    if (raw == 1) return 0;
    return logsIndex;
  }

  static Future<int> loadSavedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(prefsKey);
    if (raw == null) return 0;
    final migrated = migrateLegacyIndex(raw);
    if (migrated != raw) {
      await saveIndex(migrated);
    }
    return migrated;
  }

  static Future<void> saveIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsKey, index.clamp(0, names.length - 1));
  }

  static String nameAt(int index) {
    final safe = index.clamp(0, names.length - 1);
    return names[safe];
  }
}
