import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

/// مساعدات الدردشة الثابتة (تحديثات المحادثة ومعاينات الرسائل).
class FirestoreChatApi {
  FirestoreChatApi._();

  /// يضع [isRead] = true لكل الرسائل الواردة (مرسل ليس [viewerUserId]) داخل [chatId].
  /// يُستدعى عند فتح المحادثة أو عند وصول تحديثات أثناء بقاء الشاشة مفتوحة.
  /// يحدّد المحادثة المفتوحة حالياً لموظف (لتخطّي FCM على الخادم عند الحاجة).
  static Future<void> syncEmployeeActiveChatId(
    String employeeId,
    String? chatId,
  ) async {
    try {
      final ref = FirebaseFirestore.instance.collection('employees').doc(employeeId);
      if (chatId == null || chatId.isEmpty) {
        await ref.update({
          'activeChatId': FieldValue.delete(),
          'activeChatUpdatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.update({
          'activeChatId': chatId,
          'activeChatUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      log('syncEmployeeActiveChatId: $e');
    }
  }

  static Future<void> markIncomingMessagesReadInChat(
    String chatId,
    String viewerUserId,
  ) async {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    try {
      final unreadMessages =
          await chatRef
              .collection('messages')
              .where('isRead', isEqualTo: false)
              .where('senderId', isNotEqualTo: viewerUserId)
              .get();

      for (final doc in unreadMessages.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      if (e.toString().contains('failed-precondition') ||
          e.toString().contains('index')) {
        final unreadSnapshot =
            await chatRef
                .collection('messages')
                .where('isRead', isEqualTo: false)
                .get();
        final toMark =
            unreadSnapshot.docs
                .where((d) => d.data()['senderId'] != viewerUserId)
                .toList();
        for (final doc in toMark) {
          await doc.reference.update({'isRead': true});
        }
      } else {
        rethrow;
      }
    }
  }

  /// نص معاينة لقائمة المحادثات من مستند في `chats/.../messages`.
  static String chatListPreviewFromMessageData(Map<String, dynamic> data) {
    final type = (data['messageType'] as String?)?.trim() ?? 'text';
    final text = (data['text'] ?? '') as String;
    switch (type) {
      case 'voice':
        return '🎤';
      case 'image':
        return '📷';
      case 'file':
        final fn = (data['fileName'] as String?)?.trim();
        return fn != null && fn.isNotEmpty ? '📎 $fn' : '📎';
      default:
        return text;
    }
  }

  /// آخر رسالة فعلية من المجموعة الفرعية (مصدر موثوق عند تعارض حقل المحادثة).
  static Future<String?> fetchLatestMessagePreviewForChat(
    FirebaseFirestore fs,
    String chatId,
  ) async {
    try {
      final q =
          await fs
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();
      if (q.docs.isEmpty) return null;
      return chatListPreviewFromMessageData(q.docs.first.data());
    } catch (e, st) {
      log('fetchLatestMessagePreviewForChat $chatId: $e\n$st');
      return null;
    }
  }

  /// جلب معاينات متوازية لعدة محادثات عند فتح القائمة أو تحديثها.
  static Future<Map<String, String?>> fetchLatestMessagePreviewsForChatIds(
    FirebaseFirestore fs,
    Iterable<String> chatIds,
  ) async {
    final ids = chatIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return {};
    final entries = await Future.wait(
      ids.map((id) async {
        final p = await fetchLatestMessagePreviewForChat(fs, id);
        return MapEntry(id, p);
      }),
    );
    return Map.fromEntries(entries);
  }

  /// مزامنة حقل [lastMessage] على مستند المحادثة إن كان فارغاً أو قديماً (بدون تعديل [lastUpdated]).
  static Future<void> patchChatLastMessageIfStale(
    FirebaseFirestore fs,
    String chatId,
    String previewFromMessages,
    String currentDocLastMessage,
  ) async {
    final a = previewFromMessages.trim();
    if (a.isEmpty) return;
    if (a == currentDocLastMessage.trim()) return;
    try {
      await fs.collection('chats').doc(chatId).update({'lastMessage': a});
    } catch (e) {
      log('patchChatLastMessageIfStale $chatId: $e');
    }
  }
}
