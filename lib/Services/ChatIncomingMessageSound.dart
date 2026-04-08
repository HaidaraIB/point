import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'AudioService.dart';

/// Listens to Firestore message snapshots and triggers [AudioService.playNotificationSound]
/// for newly added messages from other users (not [currentUserId]) — **web only**;
/// على الموبايل يُعتمد على صوت Push / الإشعار المحلي.
///
/// Skips the first emission so the initial full snapshot does not trigger sounds.
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
attachIncomingMessageSoundSubscription({
  required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
  required String chatId,
  required String currentUserId,
}) {
  // Temporary web safeguard: avoid known cloud_firestore web assertion path
  // seen in production traces around QuerySnapshot conversions.
  if (kIsWeb) return null;

  var initialSnapshot = true;
  final seenMessageIds = <String>{};
  return stream.listen((snapshot) {
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
      AudioService.instance.playNotificationSound(chatId: chatId);
    }
  });
}
