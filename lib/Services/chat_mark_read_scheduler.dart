import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/firestore/firestore_chat_api.dart';
import 'package:point/View/Chats/chat_scroll_to_latest_fab.dart';

/// Debounced mark-as-read so Firestore `isRead` updates do not re-stream on
/// every snapshot while the user scrolls through history.
class ChatMarkReadScheduler {
  ChatMarkReadScheduler._();

  static const _debounceMs = 800;
  static final _timers = <String, Timer>{};
  static final _pendingScrollControllers = <String, ScrollController>{};

  /// Chats where denormalized unread was confirmed 0 or successfully cleared
  /// this open session (avoids repeated peeks while sitting at latest).
  static final _confirmedCleared = <String>{};

  static bool _hasIncomingUnread(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String viewerUserId,
  ) {
    for (final doc in docs) {
      final d = doc.data();
      if (d['senderId'] != viewerUserId && d['isRead'] != true) {
        return true;
      }
    }
    return false;
  }

  static bool _isAtLatest(ScrollController? scrollController) {
    if (scrollController == null || !scrollController.hasClients) {
      return false;
    }
    return chatReverseListShowsLatestFromScroll(scrollController);
  }

  /// Peeks denormalized [unreadCount_<viewer>] when loaded messages already look
  /// read (common in groups: shared [isRead] flipped by another member).
  static Future<bool> _hasStuckDenormalizedUnread(
    String chatId,
    String viewerUserId,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      if (!snap.exists) return false;
      return FirestoreChatApi.unreadCountFromChatData(
            snap.data() ?? const <String, dynamic>{},
            viewerUserId,
          ) >
          0;
    } catch (_) {
      return false;
    }
  }

  /// Schedules a debounced read pass. Skips work when there is nothing unread
  /// or when [onlyWhenAtLatest] and the viewport is not at the newest end.
  static void scheduleFromSnapshot({
    required String chatId,
    required String viewerUserId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ScrollController? scrollController,
    bool onlyWhenAtLatest = true,
  }) {
    if (docs.isEmpty) return;

    final hasMsgUnread = _hasIncomingUnread(docs, viewerUserId);
    if (!hasMsgUnread && _confirmedCleared.contains(chatId)) return;

    if (onlyWhenAtLatest && !_isAtLatest(scrollController)) {
      cancelForChat(chatId);
      return;
    }

    // Need a scroll controller to re-check "at latest" after debounce when gated.
    if (onlyWhenAtLatest && scrollController == null) return;

    _pendingScrollControllers[chatId] = scrollController!;
    _timers[chatId]?.cancel();
    _timers[chatId] = Timer(const Duration(milliseconds: _debounceMs), () {
      _timers.remove(chatId);
      final controller = _pendingScrollControllers.remove(chatId);
      if (onlyWhenAtLatest && !_isAtLatest(controller)) return;
      unawaited(
        _runMarkReadPass(
          chatId: chatId,
          viewerUserId: viewerUserId,
          hasMsgUnread: hasMsgUnread,
        ),
      );
    });
  }

  static Future<void> _runMarkReadPass({
    required String chatId,
    required String viewerUserId,
    required bool hasMsgUnread,
  }) async {
    if (!hasMsgUnread) {
      final stuck = await _hasStuckDenormalizedUnread(chatId, viewerUserId);
      if (!stuck) {
        _confirmedCleared.add(chatId);
        return;
      }
    }
    await FirestoreServices.markIncomingMessagesReadInChat(
      chatId,
      viewerUserId,
    );
    _confirmedCleared.add(chatId);
  }

  static void cancelForChat(String chatId) {
    _timers[chatId]?.cancel();
    _timers.remove(chatId);
    _pendingScrollControllers.remove(chatId);
    _confirmedCleared.remove(chatId);
  }

  static void cancelAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _pendingScrollControllers.clear();
    _confirmedCleared.clear();
  }
}
