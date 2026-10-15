import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Services/firestore/firestore_fcm_api.dart';
import 'package:point/Services/firestore/firestore_chat_api.dart';
import 'package:point/Utils/app_log.dart';

/// Firestore writes for chat message edit, soft delete, and chat list preview sync.
class ChatMessageActions {
  ChatMessageActions._();

  /// Re-derives `lastMessage` / `lastMessageMeta` when [messageId] is the
  /// chat's latest message. Leaves `lastUpdated` alone so an edit or delete
  /// does not reorder the chat list.
  static Future<void> syncChatLastMessageIfLatest(
    FirebaseFirestore fs,
    String chatId,
    String messageId,
  ) async {
    try {
      final latest = await FirestoreChatApi.fetchLatestMessageDoc(fs, chatId);
      if (latest == null || latest.id != messageId) return;
      final data = latest.data();
      await fs.collection('chats').doc(chatId).update({
        'lastMessage': FirestoreChatApi.chatListPreviewFromMessageData(data),
        'lastMessageMeta':
            FirestoreChatApi.lastMessageMetaMapFromMessageData(data),
      });
    } catch (e, st) {
      appLog('syncChatLastMessageIfLatest $chatId: $e\n$st');
    }
  }

  /// Silent push so recipients' tray notifications drop or re-text the message.
  static Future<void> _notifyParticipantsOfMutation({
    required FirebaseFirestore fs,
    required String chatId,
    required String messageId,
    required String notificationType,
    String? newText,
  }) async {
    try {
      final chat = await fs.collection('chats').doc(chatId).get();
      final participants = List<String>.from(
        chat.data()?['participants'] ?? const <String>[],
      );
      if (participants.isEmpty) return;
      await FirestoreFcmApi.sendFcmToEmployees(
        userIds: participants,
        title: '.',
        body: '.',
        notificationType: notificationType,
        silentDataOnly: true,
        fcmDataExtras: <String, String>{
          'chatId': chatId,
          'messageId': messageId,
          if (newText != null) 'text': newText,
        },
      );
    } catch (e, st) {
      appLog('$notificationType push failed chat_id=$chatId: $e\n$st');
    }
  }

  static Future<void> applyTextEdit({
    required FirebaseFirestore fs,
    required String chatId,
    required String messageId,
    required String previousText,
    required String newText,
    required String editedBy,
    required String editedByName,
    String? sentTranslation,
    String? sentTranslationLang,
    String? sentTranslationSourceHash,
    bool clearSentTranslation = false,
  }) async {
    final batch = fs.batch();
    final msgRef = fs
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    final editRef = msgRef.collection('edits').doc();
    batch.set(editRef, {
      'previousText': previousText,
      'editedAt': FieldValue.serverTimestamp(),
      'editedBy': editedBy,
      'editedByName': editedByName,
    });
    batch.update(msgRef, {
      'text': newText,
      'edited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    if (clearSentTranslation) {
      await msgRef.update({
        'sentTranslation': FieldValue.delete(),
        'sentTranslationLang': FieldValue.delete(),
        'sentTranslationSourceHash': FieldValue.delete(),
      });
    } else if (sentTranslation != null &&
        sentTranslationLang != null &&
        sentTranslationSourceHash != null) {
      await msgRef.update({
        'sentTranslation': sentTranslation,
        'sentTranslationLang': sentTranslationLang,
        'sentTranslationSourceHash': sentTranslationSourceHash,
      });
    }

    await syncChatLastMessageIfLatest(fs, chatId, messageId);
    unawaited(
      _notifyParticipantsOfMutation(
        fs: fs,
        chatId: chatId,
        messageId: messageId,
        notificationType: 'chat_message_edited',
        newText: newText,
      ),
    );
  }

  /// Content removed on admin delete; must match `messageSoftDeleteWipeKeys`
  /// in firestore.rules.
  static const List<String> _softDeleteWipeKeys = <String>[
    'text',
    'attachmentUrl',
    'fileName',
    'durationSec',
    'translations',
    'translationsSourceHash',
    'sentTranslation',
    'sentTranslationLang',
    'sentTranslationSourceHash',
    'replyPreview',
    'replyImageUrl',
    'replyVideoUrl',
    'replySenderName',
    'isPinned',
    'pinnedAt',
    'pinnedBy',
  ];

  static Future<void> softDeleteMessage({
    required FirebaseFirestore fs,
    required String chatId,
    required String messageId,
    required String deletedBy,
  }) async {
    final msgRef = fs
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    await msgRef.update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': deletedBy,
      for (final k in _softDeleteWipeKeys) k: FieldValue.delete(),
    });
    await syncChatLastMessageIfLatest(fs, chatId, messageId);
    unawaited(
      _notifyParticipantsOfMutation(
        fs: fs,
        chatId: chatId,
        messageId: messageId,
        notificationType: 'chat_message_deleted',
      ),
    );
    await _scrubReplyQuotesOf(fs: fs, chatId: chatId, messageId: messageId);
  }

  /// Replies store a copy of the quoted text/thumbnail; strip it after delete.
  static Future<void> _scrubReplyQuotesOf({
    required FirebaseFirestore fs,
    required String chatId,
    required String messageId,
  }) async {
    try {
      final replies = await fs
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('replyToMessageId', isEqualTo: messageId)
          .limit(450)
          .get();
      if (replies.docs.isEmpty) return;
      final batch = fs.batch();
      for (final doc in replies.docs) {
        batch.update(doc.reference, {
          'replyDeleted': true,
          'replyPreview': FieldValue.delete(),
          'replyImageUrl': FieldValue.delete(),
          'replyVideoUrl': FieldValue.delete(),
        });
      }
      await batch.commit();
    } catch (e, st) {
      appLog('scrubReplyQuotesOf $chatId/$messageId: $e\n$st');
    }
  }

  static Future<void> setMessagePinnedState({
    required FirebaseFirestore fs,
    required String chatId,
    required String messageId,
    required bool pinned,
    required String actorUserId,
  }) async {
    final msgRef = fs
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    if (pinned) {
      await msgRef.update({
        'isPinned': true,
        'pinnedAt': FieldValue.serverTimestamp(),
        'pinnedBy': actorUserId,
      });
      return;
    }
    await msgRef.update({
      'isPinned': false,
      'pinnedAt': FieldValue.delete(),
      'pinnedBy': FieldValue.delete(),
    });
  }

  static Future<void> saveMessageTranslations({
    required FirebaseFirestore fs,
    required String chatId,
    required String messageId,
    required Map<String, String> translations,
    required String sourceHash,
  }) async {
    await fs
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
          'translations': translations,
          'translationsSourceHash': sourceHash,
        });
  }
}
