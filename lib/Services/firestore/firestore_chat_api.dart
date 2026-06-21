import 'dart:async';

import 'package:point/Utils/app_log.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FcmServices.dart' as fcm_notifications;

import 'package:point/Services/firestore/firestore_query_limits.dart';

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

  static String unreadCountField(String userId) =>
      'unreadCount_${userId.trim()}';

  static String lastReadAtField(String userId) =>
      'lastReadAt_${userId.trim()}';

  static Map<String, dynamic> lastMessageMetaMapFromMessageData(
    Map<String, dynamic> data,
  ) {
    final meta = ChatListLastMessageMeta.fromMessageData(data);
    return <String, dynamic>{
      'previewText': meta.previewText,
      'subtitleLine': meta.subtitleLine,
      if (meta.imageThumbUrl != null) 'imageThumbUrl': meta.imageThumbUrl,
      if (meta.videoThumbUrl != null) 'videoThumbUrl': meta.videoThumbUrl,
    };
  }

  static ChatListLastMessageMeta? lastMessageMetaFromChatData(
    Map<String, dynamic>? chatData,
  ) {
    final raw = chatData?['lastMessageMeta'];
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final preview =
        (map['previewText'] ?? chatData?['lastMessage'] ?? '').toString();
    if (preview.trim().isEmpty) return null;
    return ChatListLastMessageMeta(
      previewText: preview,
      subtitleLine: (map['subtitleLine'] ?? preview).toString(),
      imageThumbUrl: map['imageThumbUrl']?.toString(),
      videoThumbUrl: map['videoThumbUrl']?.toString(),
    );
  }

  /// يضع [isRead] = true لكل الرسائل الواردة (مرسل ليس [viewerUserId]) داخل [chatId].
  /// يُستدعى عند فتح المحادثة أو عند وصول تحديثات أثناء بقاء الشاشة مفتوحة.
  static String? _activeChatSyncEmployeeId;
  static String? _activeChatSyncChatId;

  /// يحدّد المحادثة المفتوحة حالياً لموظف. الخادم ([send-fcm]) يتخطّى دفع [chat_message]
  /// لنفس المحادثة فقط إذا كان [activeChatUpdatedAt] حديثاً (بضع دقائق) — يقلّل الإشعارات المزدوجة
  /// دون إسقاط الدفع عند بقاء [activeChatId] قديماً بعد إغلاق التطبيق.
  static Future<void> syncEmployeeActiveChatId(
    String employeeId,
    String? chatId,
  ) async {
    final id = employeeId.trim();
    if (id.isEmpty) return;

    final nextChat = chatId?.trim();
    // Skip close-time writes; the next open overwrites activeChatId.
    if (nextChat == null || nextChat.isEmpty) {
      _activeChatSyncEmployeeId = id;
      _activeChatSyncChatId = null;
      return;
    }

    if (_activeChatSyncEmployeeId == id && _activeChatSyncChatId == nextChat) {
      return;
    }
    _activeChatSyncEmployeeId = id;
    _activeChatSyncChatId = nextChat;

    try {
      final ref =
          FirebaseFirestore.instance.collection('employees').doc(id);
      await ref.update({
        'activeChatId': nextChat,
        'activeChatUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      appLog('syncEmployeeActiveChatId: $e');
    }
  }

  static Future<void> markIncomingMessagesReadInChat(
    String chatId,
    String viewerUserId,
  ) async {
    final uid = viewerUserId.trim();
    if (uid.isEmpty) return;
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    try {
      await chatRef.update({
        unreadCountField(uid): 0,
        lastReadAtField(uid): FieldValue.serverTimestamp(),
      });
    } catch (e) {
      appLog('markIncomingMessagesReadInChat chat doc: $e');
    }

    try {
      QuerySnapshot<Map<String, dynamic>> unreadMessages;
      try {
        unreadMessages = await chatRef
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .where('senderId', isNotEqualTo: uid)
            .limit(500)
            .get();
      } catch (e) {
        if (!e.toString().contains('failed-precondition') &&
            !e.toString().contains('index')) {
          rethrow;
        }
        final unreadSnapshot = await chatRef
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .limit(500)
            .get();
        final toMark = unreadSnapshot.docs
            .where((d) => d.data()['senderId'] != uid)
            .toList();
        if (toMark.isEmpty) return;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in toMark) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
        unawaited(
          fcm_notifications.NotificationService()
              .dismissChatMessageNotification(chatId),
        );
        return;
      }

      if (unreadMessages.docs.isEmpty) {
        unawaited(
          fcm_notifications.NotificationService()
              .dismissChatMessageNotification(chatId),
        );
        return;
      }
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      appLog('markIncomingMessagesReadInChat messages batch: $e');
    }
    unawaited(
      fcm_notifications.NotificationService().dismissChatMessageNotification(
        chatId,
      ),
    );
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

  /// Older messages before [oldestLoaded] (descending order, same as live stream).
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchOlderChatMessages({
    required FirebaseFirestore fs,
    required String chatId,
    required QueryDocumentSnapshot<Map<String, dynamic>> oldestLoaded,
    int limit = FirestoreQueryLimits.chatMessagesPage,
  }) async {
    try {
      final snap = await fs
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(oldestLoaded)
          .limit(limit)
          .get();
      return snap.docs;
    } catch (e, st) {
      appLog('fetchOlderChatMessages $chatId: $e\n$st');
      return const [];
    }
  }

  /// Pinned messages for the chat bar — independent of the paginated live stream.
  static Query<Map<String, dynamic>> pinnedMessagesQuery(
    FirebaseFirestore fs,
    String chatId,
  ) {
    return fs
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isPinned', isEqualTo: true)
        .limit(FirestoreQueryLimits.pinnedMessages);
  }

  /// Live pinned list while a chat is open (~N reads per update, N = pin count).
  static Stream<QuerySnapshot<Map<String, dynamic>>> pinnedMessagesStream(
    FirebaseFirestore fs,
    String chatId,
  ) {
    return pinnedMessagesQuery(fs, chatId).snapshots();
  }

  /// Fetch a single message as [QueryDocumentSnapshot] (e.g. pin outside loaded window).
  static Future<QueryDocumentSnapshot<Map<String, dynamic>>?> fetchChatMessageById(
    FirebaseFirestore fs,
    String chatId,
    String messageId,
  ) async {
    final id = messageId.trim();
    if (id.isEmpty) return null;
    try {
      final snap = await fs
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where(FieldPath.documentId, isEqualTo: id)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first;
    } catch (e, st) {
      appLog('fetchChatMessageById $chatId/$messageId: $e\n$st');
      return null;
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
    Map<String, dynamic>? messageData,
    List<String>? participantIds,
  }) async {
    final chatRef = fs.collection('chats').doc(chatId);
    final actorId = actorParticipantId.trim();

    Future<void> writeLastMessage() {
      final data = <String, dynamic>{
        'lastMessage': lastMessagePreview,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (messageData != null) {
        data['lastMessageMeta'] =
            lastMessageMetaMapFromMessageData(messageData);
      }
      final recipients = participantIds ?? const <String>[];
      for (final id in recipients) {
        final pid = id.trim();
        if (pid.isEmpty || pid == actorId) continue;
        data[unreadCountField(pid)] = FieldValue.increment(1);
      }
      return chatRef.update(data);
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
