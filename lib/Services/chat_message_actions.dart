import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Services/firestore/firestore_chat_api.dart';
import 'package:point/Utils/app_log.dart';

/// Firestore writes for chat message edit, soft delete, and chat list preview sync.
class ChatMessageActions {
  ChatMessageActions._();

  static Future<void> syncChatLastMessageFromLatest(
    FirebaseFirestore fs,
    String chatId,
  ) async {
    try {
      final preview = await FirestoreChatApi.fetchLatestMessagePreviewForChat(
        fs,
        chatId,
      );
      if (preview == null || preview.isEmpty) return;
      await fs.collection('chats').doc(chatId).update({
        'lastMessage': preview,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      appLog('syncChatLastMessageFromLatest $chatId: $e\n$st');
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
    await syncChatLastMessageFromLatest(fs, chatId);
  }

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
    });
    await syncChatLastMessageFromLatest(fs, chatId);
  }
}
