import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:point/Utils/app_log.dart';

import 'AudioService.dart';
import 'ChatAudioFocus.dart';

void _debugIncomingSoundError(Object e, StackTrace st) {
  if (kDebugMode) {
    appDebugPrint('attachIncomingMessageSoundSubscription: $e\n$st');
  }
}

/// Listens to Firestore message snapshots for new messages from others:
/// - If this [chatId] is **not** in the foreground → [AudioService.playNotificationSound]
///   (same asset as background / other-tab incoming).
/// - If the user is **viewing** this chat → [AudioService.playActiveChatIncomingSound]
///   (distinct in-chat cue).
///
/// Skips the first emission so the initial full snapshot does not trigger sounds.
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
attachIncomingMessageSoundSubscription({
  required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
  required String chatId,
  required String currentUserId,
}) {
  var initialSnapshot = true;
  final seenMessageIds = <String>{};
  return stream.listen((snapshot) {
    try {
      if (initialSnapshot) {
        for (final doc in snapshot.docs) {
          seenMessageIds.add(doc.id);
        }
        initialSnapshot = false;
        return;
      }

      for (final doc in snapshot.docs) {
        final id = doc.id;
        if (seenMessageIds.contains(id)) continue;
        seenMessageIds.add(id);
        final data = doc.data();
        if (data['senderId'] == currentUserId) continue;
        if (ChatAudioFocus.incomingTreatAsInChat(chatId)) {
          unawaited(AudioService.instance.playActiveChatIncomingSound());
        } else {
          unawaited(
            AudioService.instance.playNotificationSound(chatId: chatId),
          );
        }
      }
    } catch (e, st) {
      _debugIncomingSoundError(e, st);
    }
  });
}
