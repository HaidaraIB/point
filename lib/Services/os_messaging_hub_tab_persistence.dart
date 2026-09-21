import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OsMessagingHubTabPersistence {
  OsMessagingHubTabPersistence._();

  static const prefsKey = StorageKeys.prefsOsMessagingHubTabKey;
  static const send = 'send';
  static const invoices = 'invoices';
  static const logs = 'logs';
  static const names = [send, invoices, logs];

  static int get logsIndex => names.indexOf(logs);

  static Future<int> loadSavedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(prefsKey);
    if (raw == null) return 0;
    return raw.clamp(0, names.length - 1);
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
