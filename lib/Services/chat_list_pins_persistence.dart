import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local pinned chat IDs per user (list order = top to bottom, newest pin first).
class ChatListPinsPersistence {
  static const _keyPrefix = 'point_chat_list_pins_v1';

  static String _key(String userId) => '$_keyPrefix|$userId';

  static Future<List<String>> loadPinnedChatIds(String userId) async {
    if (userId.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(String userId, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(ids));
  }

  /// Pinned chats appear first; newest pin wins the top slot among pins.
  static Future<List<String>> pinChat(
    String userId,
    List<String> currentOrder,
    String chatId,
  ) async {
    final next = List<String>.from(currentOrder)..remove(chatId);
    next.insert(0, chatId);
    await _save(userId, next);
    return next;
  }

  static Future<List<String>> unpinChat(
    String userId,
    List<String> currentOrder,
    String chatId,
  ) async {
    final next = List<String>.from(currentOrder)..remove(chatId);
    await _save(userId, next);
    return next;
  }
}
