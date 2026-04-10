import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/View/Chats/chat_scroll_to_latest_fab.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serializable scroll anchor for a reverse [ScrollablePositionedList] (newest at index 0).
class ChatScrollSnapshot {
  final int index;
  /// Leading-edge alignment in viewport (see [ItemScrollController.jumpTo]).
  final double alignment;

  const ChatScrollSnapshot({required this.index, required this.alignment});

  Map<String, dynamic> toJson() => {'i': index, 'a': alignment};

  static ChatScrollSnapshot? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>?;
      if (m == null) return null;
      final i = m['i'];
      final a = m['a'];
      if (i is! int || a is! num) return null;
      return ChatScrollSnapshot(index: i, alignment: a.toDouble());
    } catch (_) {
      return null;
    }
  }
}

/// Picks the visible row with the smallest index (newest side in a reverse chat list).
ChatScrollSnapshot? chatScrollSnapshotFromItemPositions(
  Iterable<ItemPosition> positions,
) {
  if (positions.isEmpty) return null;
  ItemPosition? chosen;
  var minIdx = 1 << 30;
  for (final p in positions) {
    if (p.index < minIdx) {
      minIdx = p.index;
      chosen = p;
    }
  }
  if (chosen == null) return null;
  return ChatScrollSnapshot(
    index: chosen.index,
    alignment: chosen.itemLeadingEdge,
  );
}

class ChatScrollPersistence {
  static const _keyPrefix = 'point_chat_list_scroll_v1';

  static String _storageKey(String userId, String chatId) =>
      '$_keyPrefix|$userId|$chatId';

  static Future<void> saveSnapshot({
    required String userId,
    required String chatId,
    required ChatScrollSnapshot snapshot,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(userId, chatId), jsonEncode(snapshot.toJson()));
  }

  static Future<void> save({
    required String userId,
    required String chatId,
    required Iterable<ItemPosition> positions,
  }) async {
    final snap = chatScrollSnapshotFromItemPositions(positions);
    if (snap == null) return;
    await saveSnapshot(userId: userId, chatId: chatId, snapshot: snap);
  }

  static Future<ChatScrollSnapshot?> load(String userId, String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    return ChatScrollSnapshot.fromJsonString(
      prefs.getString(_storageKey(userId, chatId)),
    );
  }
}

/// Resolves initial list scroll: restored snapshot if valid, else last-read anchor.
({int index, double alignment}) resolveChatOpenScroll({
  required int itemCount,
  required String currentUserId,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ChatScrollSnapshot? persisted,
  bool usePersisted = true,
}) {
  final lastRead = itemCount == 0 || docs.isEmpty
      ? 0
      : chatReverseListAnchorIndexLastRead(
          docs: docs,
          currentUserId: currentUserId,
        );
  final maxIdx = itemCount > 0 ? itemCount - 1 : 0;
  if (!usePersisted ||
      persisted == null ||
      persisted.index < 0 ||
      persisted.index >= itemCount) {
    return (index: lastRead.clamp(0, maxIdx), alignment: 1.0);
  }
  final a = persisted.alignment;
  return (
    index: persisted.index.clamp(0, maxIdx),
    alignment: a.clamp(0.0, 1.0),
  );
}
