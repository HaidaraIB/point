import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists CRM list vs kanban view across navigations.
class OsCrmViewPersistence {
  OsCrmViewPersistence._();

  static const kanban = 'kanban';
  static const list = 'list';

  static Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.prefsOsCrmViewKey);
    if (raw == list) return list;
    return kanban;
  }

  static Future<void> save(String view) async {
    final safe = view == list ? list : kanban;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.prefsOsCrmViewKey, safe);
  }
}
