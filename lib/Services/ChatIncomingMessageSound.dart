import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'AudioService.dart';

/// Listens to Firestore message snapshots and triggers [AudioService.playNotificationSound]
/// for newly added messages from other users (not [currentUserId]).
///
/// Skips the first emission so the initial full snapshot does not trigger sounds.
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
attachIncomingMessageSoundSubscription({
  required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
  required String chatId,
  required String currentUserId,
}) {
  var initialSnapshot = true;
  return stream.listen((snapshot) {
    if (initialSnapshot) {
      initialSnapshot = false;
      return;
    }
    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data();
      if (data == null) continue;
      if (data['senderId'] == currentUserId) continue;
      AudioService.instance.playNotificationSound(chatId: chatId);
    }
  });
}
