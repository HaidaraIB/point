import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/local_notifications_host.dart';
import 'package:point/Services/notifications/ChatStore.dart';
import 'package:point/Services/notifications/Models.dart';
import 'package:point/Services/push_notification_sound.dart';
import 'package:point/Services/push_permissions_helper.dart';
import 'package:point/Utils/app_log.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const Duration _debounceDuration = Duration(milliseconds: 450);
  static const Set<String> _legacyUnreadDigestTitles = <String>{
    // Old unread-digest local notification used id = title.hashCode.
    'Point',
  };

  final ChatStore _chatStore = ChatStore.instance;
  final Map<String, Timer> _debounceByChat = <String, Timer>{};

  /// One in-flight handler chain per chat so Hive load/append/save stays atomic
  /// when Android delivers several data messages close together.
  static final Map<String, Future<void>> _incomingChainByChat =
      <String, Future<void>>{};
  static bool _legacyDigestCleanupDone = false;

  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> init() {
    _initFuture ??= _initInternal();
    return _initFuture!;
  }

  Future<void> _initInternal() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    await ensureAppLocalNotificationsInitialized();
    await _chatStore.init();
    await _ensureAndroidChannel();
  }

  Future<void> handleIncomingMessage(RemoteMessage msg) async {
    final payload = _parsePayload(msg);
    if (payload == null) return;
    final key = payload.chatId.trim();
    if (key.isEmpty) return;

    final previous = _incomingChainByChat[key] ?? Future<void>.value();
    late final Future<void> current;
    current = previous
        .catchError((_) {})
        .then((_) => _handleIncomingMessageImpl(msg, payload));
    _incomingChainByChat[key] = current;
    try {
      await current;
    } finally {
      if (identical(_incomingChainByChat[key], current)) {
        _incomingChainByChat.remove(key);
      }
    }
  }

  Future<void> _handleIncomingMessageImpl(
    RemoteMessage msg,
    _ParsedPayload payload,
  ) async {
    appLog(
      'ChatPush incoming chat_id=${payload.chatId} message_id=${payload.message.messageId}',
    );

    try {
      await _clearLegacyUnreadDigestNotifications();
      final buffer = await _chatStore.loadBuffer(payload.chatId);
      final isDuplicate = buffer.messages.any(
        (m) => m.messageId == payload.message.messageId,
      );
      if (isDuplicate) {
        appLog(
          'ChatPush duplicate ignored chat_id=${payload.chatId} message_id=${payload.message.messageId}',
        );
        return;
      }

      final next = _chatStore.appendMessage(
        buffer: buffer,
        message: payload.message,
        chatTitle: payload.chatTitle,
        isGroupChat: payload.isGroupChat,
      );
      await _chatStore.saveBuffer(next);
      appLog(
        'ChatPush stored chat_id=${payload.chatId} message_id=${payload.message.messageId} buffer_size=${next.messages.length}',
      );
      _scheduleNotification(payload.chatId);
    } catch (e, st) {
      appLog(
        'ChatPush handleIncomingMessage failed chat_id=${payload.chatId} message_id=${payload.message.messageId}: $e\n$st',
      );
    }
  }

  Future<void> _clearLegacyUnreadDigestNotifications() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_legacyDigestCleanupDone) return;
    try {
      for (final title in _legacyUnreadDigestTitles) {
        await appLocalNotificationsPlugin.cancel(id: title.hashCode);
      }
      _legacyDigestCleanupDone = true;
      appLog('ChatPush cleared legacy unread-digest local notifications');
    } catch (e, st) {
      appLog('ChatPush legacy unread-digest clear failed: $e\n$st');
    }
  }

  Future<void> showConversationNotification(String chatId) async {
    if (kIsWeb) return;
    final normalized = chatId.trim();
    if (normalized.isEmpty) return;

    try {
      await init();
      if (Platform.isAndroid) {
        final allowed =
            await PushPermissionsHelper.androidPostNotificationsGranted();
        if (!allowed) {
          appLog(
            'ChatPush: skip show (Android POST_NOTIFICATIONS not granted) chat_id=$normalized',
          );
          return;
        }
      }
      final buffer = await _chatStore.loadBuffer(normalized);
      if (buffer.messages.isEmpty) {
        await appLocalNotificationsPlugin.cancel(
          id: normalized.hashCode,
          tag: androidChatNotificationTag(normalized),
        );
        return;
      }

      final sorted = List<StoredMessage>.from(buffer.messages)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final latest = sorted.last;
      final count = sorted.length;
      final displayName = buffer.chatTitle.trim().isNotEmpty
          ? buffer.chatTitle.trim()
          : (_humanChatLabel(normalized));
      final collapsedSubtitle = count > 1
          ? _tr(
              AppLocaleKeys.chatNNewWithPreview,
              {'count': '$count', 'text': latest.text},
            )
          : latest.text.trim();

      var inboxLines = sorted
          .map((m) => m.text.trim())
          .where((t) => t.isNotEmpty)
          .toList(growable: false);
      if (inboxLines.isEmpty) {
        inboxLines = <String>['…'];
      }

      final soundBase = pushSoundBaseForNotificationType('chat_message');
      final androidChannelId = pushChannelIdForSoundBase(soundBase);
      final androidChannelName = soundBase != null
          ? 'Point: $soundBase'
          : _tr(AppLocaleKeys.notificationsChannelChat);

      // InboxStyle: message text only (no per-line sender). MessagingStyle would
      // always show Person avatars + names on Android.
      final StyleInformation? androidStyle =
          Platform.isAndroid && inboxLines.length > 1
          ? InboxStyleInformation(
              inboxLines,
              contentTitle: displayName,
              summaryText: count > 1
                  ? _tr(AppLocaleKeys.chatNNew, {'count': '$count'})
                  : null,
            )
          : null;

      final androidDetails = AndroidNotificationDetails(
        androidChannelId,
        androidChannelName,
        channelDescription: 'Conversation chat notifications',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        tag: androidChatNotificationTag(normalized),
        styleInformation: androidStyle,
      );

      final iOSDetails = DarwinNotificationDetails(
        threadIdentifier: normalized,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: iosPushSoundFile(soundBase),
      );

      await appLocalNotificationsPlugin.show(
        id: normalized.hashCode,
        title: displayName,
        body: collapsedSubtitle,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: iOSDetails,
        ),
        payload: jsonEncode(<String, String>{
          'notificationType': 'chat_message',
          'chatId': normalized,
          'chatTitle': displayName,
          'isGroup': buffer.isGroupChat ? '1' : '0',
        }),
      );
      appLog(
        'ChatPush notification triggered chat_id=$normalized buffer_size=$count',
      );
    } catch (e, st) {
      appLog(
        'ChatPush showConversationNotification failed chat_id=$chatId: $e\n$st',
      );
    }
  }

  Future<void> clearConversation(String chatId) async {
    final normalized = chatId.trim();
    if (normalized.isEmpty || kIsWeb) return;
    try {
      _debounceByChat.remove(normalized)?.cancel();
      await _chatStore.clearChat(normalized);
      await appLocalNotificationsPlugin.cancel(
        id: normalized.hashCode,
        tag: androidChatNotificationTag(normalized),
      );
      appLog('ChatPush cleared chat_id=$normalized');
    } catch (e, st) {
      appLog('ChatPush clearConversation failed chat_id=$normalized: $e\n$st');
    }
  }

  void _scheduleNotification(String chatId) {
    final key = chatId.trim();
    if (key.isEmpty) return;
    _debounceByChat[key]?.cancel();
    _debounceByChat[key] = Timer(_debounceDuration, () {
      _debounceByChat.remove(key);
      appLog('ChatPush debounce fired chat_id=$key');
      unawaited(showConversationNotification(key));
    });
    appLog('ChatPush debounce scheduled chat_id=$key');
  }

  _ParsedPayload? _parsePayload(RemoteMessage msg) {
    final data = msg.data;
    // FCM base payload uses type=internal; chat pushes set notificationType=chat_message.
    final notificationType =
        (data['notificationType'] ?? data['notification_type'])
            ?.toString()
            .trim() ??
        '';
    final legacyType = data['type']?.toString().trim() ?? '';
    final isChatPush =
        notificationType == 'chat_message' || legacyType == 'chat_message';
    final chatId =
        (_ciGet(data, 'chat_id') ?? _ciGet(data, 'chatId'))?.trim() ?? '';
    final text =
        (_ciGet(data, 'text') ?? _ciGet(data, 'body'))?.toString() ?? '';
    final senderResolved = _resolveSenderName(data);
    final timestampMs = _parseTimestampMs(
      data['timestamp'] ?? data['created_at'],
    );
    final messageId = _resolveMessageId(data, chatId, text, timestampMs);

    if (!isChatPush) {
      appLog(
        'ChatPush rejected: not a chat_message '
        '(notificationType=$notificationType type=$legacyType)',
      );
      return null;
    }
    if (chatId.isEmpty || text.trim().isEmpty) {
      appLog(
        'ChatPush rejected malformed payload chat_id=$chatId text_empty=${text.trim().isEmpty}',
      );
      return null;
    }

    final conversationTitle = _resolveConversationTitle(data, chatId);
    final isGroupChat = _parseIsGroupFlag(data);
    return _ParsedPayload(
      chatId: chatId,
      chatTitle: conversationTitle,
      isGroupChat: isGroupChat,
      message: StoredMessage(
        messageId: messageId,
        text: text,
        sender: senderResolved,
        timestamp: timestampMs,
      ),
    );
  }

  int _parseTimestampMs(Object? raw) {
    if (raw == null) return DateTime.now().millisecondsSinceEpoch;
    final s = raw.toString().trim();
    if (s.isEmpty) return DateTime.now().millisecondsSinceEpoch;
    final asInt = int.tryParse(s);
    if (asInt != null) {
      // Heuristic: 13+ digits → already milliseconds; 10 digits → seconds.
      return asInt >= 1000000000000 ? asInt : asInt * 1000;
    }
    final asDate = DateTime.tryParse(s);
    return asDate?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;
  }

  String _resolveMessageId(
    Map<String, dynamic> data,
    String chatId,
    String text,
    int timestampMs,
  ) {
    final raw =
        (data['message_id'] ??
                data['messageId'] ??
                data['requestId'] ??
                data['request_id'])
            ?.toString()
            .trim() ??
        '';
    if (raw.isNotEmpty) return raw;
    return 'synth_${chatId}_${timestampMs}_${text.hashCode}';
  }

  Future<void> _ensureAndroidChannel() async {
    if (!Platform.isAndroid) return;
    final android = appLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    final soundBase = pushSoundBaseForNotificationType('chat_message');
    final channelId = pushChannelIdForSoundBase(soundBase);
    final channelName = soundBase != null
        ? 'Point: $soundBase'
        : _tr(AppLocaleKeys.notificationsChannelChat);
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: _tr(AppLocaleKeys.notificationsChannelChatDescription),
        importance: Importance.max,
        playSound: true,
        sound: soundBase == null
            ? null
            : RawResourceAndroidNotificationSound(soundBase),
      ),
    );
  }

  static String? _ciGet(Map<String, dynamic> data, String key) {
    final want = key.toLowerCase();
    for (final e in data.entries) {
      if (e.key.toLowerCase() == want) {
        return e.value?.toString();
      }
    }
    return null;
  }

  static bool _looksLikeInternalChatId(String value) {
    final t = value.trim();
    if (t.length < 24) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      caseSensitive: false,
    ).hasMatch(t);
  }

  /// GetX translations are unavailable in the FCM background isolate.
  static String _tr(String key, [Map<String, String>? params]) {
    try {
      if (Get.translations.isNotEmpty) {
        return params == null || params.isEmpty
            ? key.tr
            : key.trParams(params);
      }
    } catch (_) {}
    var s = _arabicFallback[key] ?? key;
    params?.forEach((k, v) {
      s = s.replaceAll('@$k', v);
    });
    return s;
  }

  static const Map<String, String> _arabicFallback = {
    AppLocaleKeys.chatFallbackTitle: 'محادثة',
    AppLocaleKeys.chatNNew: '@count جديدة',
    AppLocaleKeys.chatNNewWithPreview: '@count جديدة · @text',
    AppLocaleKeys.notificationsChannelChat: 'رسائل الدردشة',
    AppLocaleKeys.notificationsChannelChatDescription:
        'إشعارات محادثات الدردشة',
  };

  static String _humanChatLabel(String chatId) {
    final t = chatId.trim();
    if (t.isEmpty) return _tr(AppLocaleKeys.chatFallbackTitle);
    if (_looksLikeInternalChatId(t)) {
      return _tr(AppLocaleKeys.chatFallbackTitle);
    }
    return t;
  }

  static String _resolveConversationTitle(
    Map<String, dynamic> data,
    String chatId,
  ) {
    // For 1:1, `chatDisplayName` is often the peer label from the *sender's* UI
    // (the recipient's own name on their device). Prefer sender fields first so
    // the notification title shows who wrote the message, not the receiver.
    final isGroup = _parseIsGroupFlag(data);
    final keys = isGroup
        ? const <String>[
            'chatDisplayName',
            'chat_display_name',
            'conversationTitle',
            'conversation_name',
            'chatTitle',
            'chat_title',
            'senderName',
            'sender_name',
          ]
        : const <String>[
            'senderName',
            'sender_name',
            'chatTitle',
            'chat_title',
            'chatDisplayName',
            'chat_display_name',
            'conversationTitle',
            'conversation_name',
          ];
    for (final k in keys) {
      final v = _ciGet(data, k)?.trim() ?? '';
      if (v.isNotEmpty && !_looksLikeInternalChatId(v)) {
        return v;
      }
    }
    final pushTitle = _ciGet(data, 'title')?.trim() ?? '';
    final body = _ciGet(data, 'body')?.trim() ?? '';
    if (pushTitle.isNotEmpty &&
        pushTitle != body &&
        !_looksLikeInternalChatId(pushTitle)) {
      return pushTitle;
    }
    return _humanChatLabel(chatId);
  }

  static String _resolveSenderName(Map<String, dynamic> data) {
    const keys = <String>[
      'senderName',
      'sender_name',
      'senderDisplayName',
      'sender_display_name',
    ];
    for (final k in keys) {
      final v = _ciGet(data, k)?.trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    final t = _ciGet(data, 'title')?.trim() ?? '';
    final b = _ciGet(data, 'body')?.trim() ?? '';
    if (t.isNotEmpty && t != b) return t;
    return 'Unknown';
  }

  static bool _parseIsGroupFlag(Map<String, dynamic> data) {
    final raw = _ciGet(data, 'isGroup') ?? _ciGet(data, 'is_group') ?? '';
    final s = raw.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
}

class _ParsedPayload {
  const _ParsedPayload({
    required this.chatId,
    required this.message,
    required this.chatTitle,
    this.isGroupChat = false,
  });

  final String chatId;
  final String chatTitle;
  final bool isGroupChat;
  final StoredMessage message;
}
