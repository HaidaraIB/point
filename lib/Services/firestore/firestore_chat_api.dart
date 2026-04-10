import 'package:point/Utils/app_log.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';

/// Last row for chat list: sync string + optional image/video thumb URLs.
class ChatListLastMessageMeta {
  const ChatListLastMessageMeta({
    required this.previewText,
    required this.subtitleLine,
    this.imageThumbUrl,
    this.videoThumbUrl,
  });

  /// Same as [FirestoreChatApi.chatListPreviewFromMessageData] — `chats.lastMessage`.
  final String previewText;

  /// Text beside the thumbnail (caption / reply); may be empty if only media is shown.
  final String subtitleLine;

  final String? imageThumbUrl;
  final String? videoThumbUrl;

  factory ChatListLastMessageMeta.fromMessageData(Map<String, dynamic> data) {
    final previewText = FirestoreChatApi.chatListPreviewFromMessageData(data);
    if (data['deleted'] == true) {
      return ChatListLastMessageMeta(
        previewText: previewText,
        subtitleLine: previewText,
      );
    }
    final type = (data['messageType'] as String?)?.trim() ?? 'text';
    final text = (data['text'] ?? '').toString().trim();
    final replyId = (data['replyToMessageId'] as String?)?.trim();
    final hasReply = replyId != null && replyId.isNotEmpty;

    String? imageThumbUrl;
    String? videoThumbUrl;
    if (type == 'image') {
      final u = (data['attachmentUrl'] as String?)?.trim();
      if (u != null && u.isNotEmpty) imageThumbUrl = u;
    } else if (type == 'video') {
      final u = (data['attachmentUrl'] as String?)?.trim();
      if (u != null && u.isNotEmpty) videoThumbUrl = u;
    }

    final hasMediaThumb = imageThumbUrl != null || videoThumbUrl != null;
    var subtitleLine = previewText;

    if (hasMediaThumb) {
      String caption = '';
      if (type == 'image') {
        if (text.isNotEmpty && text != '📷') caption = text;
      } else if (type == 'video') {
        if (text.isNotEmpty && text != '🎬') caption = text;
      }
      if (hasReply) {
        if (caption.isNotEmpty) {
          subtitleLine = '↩ $caption';
        } else {
          subtitleLine =
              type == 'image'
                  ? '↩ ${AppLocaleKeys.chatReplyMediaPhoto.tr}'
                  : '↩ ${AppLocaleKeys.chatReplyMediaVideo.tr}';
        }
      } else {
        subtitleLine = caption;
      }
    }

    return ChatListLastMessageMeta(
      previewText: previewText,
      subtitleLine: subtitleLine,
      imageThumbUrl: imageThumbUrl,
      videoThumbUrl: videoThumbUrl,
    );
  }
}

/// مساعدات الدردشة الثابتة (تحديثات المحادثة ومعاينات الرسائل).
class FirestoreChatApi {
  FirestoreChatApi._();

  /// يضع [isRead] = true لكل الرسائل الواردة (مرسل ليس [viewerUserId]) داخل [chatId].
  /// يُستدعى عند فتح المحادثة أو عند وصول تحديثات أثناء بقاء الشاشة مفتوحة.
  /// يحدّد المحادثة المفتوحة حالياً لموظف. الخادم ([send-fcm]) يتخطّى دفع [chat_message]
  /// لنفس المحادثة فقط إذا كان [activeChatUpdatedAt] حديثاً (بضع دقائق) — يقلّل الإشعارات المزدوجة
  /// دون إسقاط الدفع عند بقاء [activeChatId] قديماً بعد إغلاق التطبيق.
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
      appLog('syncEmployeeActiveChatId: $e');
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
    if (data['deleted'] == true) {
      return '🗑';
    }
    final type = (data['messageType'] as String?)?.trim() ?? 'text';
    final text = (data['text'] ?? '') as String;
    String inner;
    switch (type) {
      case 'voice':
        inner = '🎤';
        break;
      case 'image':
        inner = '📷';
        break;
      case 'video':
        inner = '🎬';
        break;
      case 'file':
        final fn = (data['fileName'] as String?)?.trim();
        inner = fn != null && fn.isNotEmpty ? '📎 $fn' : '📎';
        break;
      default:
        inner = text;
    }
    final replyId = (data['replyToMessageId'] as String?)?.trim();
    if (replyId != null && replyId.isNotEmpty) {
      return '↩ $inner';
    }
    return inner;
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
      appLog('fetchLatestMessagePreviewForChat $chatId: $e\n$st');
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

  /// Rich last-message meta (preview + optional media thumbs) for chat list rows.
  static Future<ChatListLastMessageMeta?> fetchLatestMessageMetaForChat(
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
      return ChatListLastMessageMeta.fromMessageData(q.docs.first.data());
    } catch (e, st) {
      appLog('fetchLatestMessageMetaForChat $chatId: $e\n$st');
      return null;
    }
  }

  static Future<Map<String, ChatListLastMessageMeta?>>
  fetchLatestMessageMetaForChatIds(
    FirebaseFirestore fs,
    Iterable<String> chatIds,
  ) async {
    final ids = chatIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return {};
    final entries = await Future.wait(
      ids.map((id) async {
        final p = await fetchLatestMessageMetaForChat(fs, id);
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
      appLog('patchChatLastMessageIfStale $chatId: $e');
    }
  }

  /// Updates `chats/{chatId}` metadata after sending a message.
  ///
  /// In some department group flows, an employee may send before being added
  /// to `participants`. If `lastMessage/lastUpdated` is denied, we join the
  /// actor first (allowed by rules), then retry.
  static Future<void> updateChatAfterMessageSend({
    required FirebaseFirestore fs,
    required String chatId,
    required String actorParticipantId,
    required String lastMessagePreview,
  }) async {
    final chatRef = fs.collection('chats').doc(chatId);

    Future<void> writeLastMessage() {
      return chatRef.update({
        'lastMessage': lastMessagePreview,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    try {
      await writeLastMessage();
      return;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;

      final snap = await chatRef.get();
      final data = snap.data();
      if (data == null) rethrow;

      final isGroup = data['isGroup'] == true;
      final participants = List<String>.from(data['participants'] ?? const []);
      if (!isGroup || participants.contains(actorParticipantId)) {
        rethrow;
      }

      await chatRef.update({
        'participants': [...participants, actorParticipantId],
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await writeLastMessage();
    }
  }
}
