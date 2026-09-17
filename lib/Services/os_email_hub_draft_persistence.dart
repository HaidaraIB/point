import 'dart:convert';

import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists Email Hub dispatch form drafts across navigations.
class OsEmailHubDraftPersistence {
  OsEmailHubDraftPersistence._();

  static const prefsKey = StorageKeys.prefsOsEmailHubDraftKey;

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return Map<String, dynamic>.from(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(map));
  }
}
