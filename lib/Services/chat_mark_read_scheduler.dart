import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/View/Chats/chat_scroll_to_latest_fab.dart';

/// Debounced mark-as-read so Firestore `isRead` updates do not re-stream on
/// every snapshot while the user scrolls through history.
class ChatMarkReadScheduler {
  ChatMarkReadScheduler._();

  static const _debounceMs = 800;
  static final _timers = <String, Timer>{};
  static final _pendingScrollControllers = <String, ScrollController>{};

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

  /// Schedules a debounced read pass. Skips work when there is nothing unread
  /// or when [onlyWhenAtLatest] and the viewport is not at the newest end.
  static void scheduleFromSnapshot({
    required String chatId,
    required String viewerUserId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ScrollController? scrollController,
    bool onlyWhenAtLatest = true,
  }) {
    if (docs.isEmpty || !_hasIncomingUnread(docs, viewerUserId)) return;

    if (onlyWhenAtLatest && !_isAtLatest(scrollController)) {
      cancelForChat(chatId);
      return;
    }

    _pendingScrollControllers[chatId] = scrollController!;
    _timers[chatId]?.cancel();
    _timers[chatId] = Timer(const Duration(milliseconds: _debounceMs), () {
      _timers.remove(chatId);
      final controller = _pendingScrollControllers.remove(chatId);
      if (onlyWhenAtLatest && !_isAtLatest(controller)) return;
      unawaited(
        FirestoreServices.markIncomingMessagesReadInChat(chatId, viewerUserId),
      );
    });
  }

  static void cancelForChat(String chatId) {
    _timers[chatId]?.cancel();
    _timers.remove(chatId);
    _pendingScrollControllers.remove(chatId);
  }

  static void cancelAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _pendingScrollControllers.clear();
  }
}
