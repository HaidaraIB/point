import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/fcm_token_cache.dart';
import 'package:point/Services/local_notifications_host.dart';
import 'package:point/Services/notifications/NotificationService.dart'
    as chat_notifications;
import 'package:point/Services/push_permissions_helper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/push_notification_sound.dart';
import 'package:point/Utils/app_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  StreamSubscription<RemoteMessage>? _foregroundSub;
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
    await chat_notifications.NotificationService.instance.init();
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    _foregroundSub ??= FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      unawaited(_handleForegroundMessage(message));
    });
  }

  Future<void> onAppResumed() async {
    if (kIsWeb) return;
    await _consumePendingPushSyncPrefs();
    await FcmTokenCache.resyncIfChanged();
    await _pollMissedInAppNotificationsOnResume();
  }

  Future<void> dismissChatMessageNotification(String chatId) {
    return chat_notifications.NotificationService.instance.clearConversation(chatId);
  }

  Future<void> showTestLocalNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await ensureAppLocalNotificationsInitialized();
    const androidDetails = AndroidNotificationDetails(
      'debug_local_notification',
      'Debug local notification',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await appLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: jsonEncode(<String, String>{'type': 'local_test'}),
    );
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = _stringDataMap(message);
    if (_isSilentPushData(data)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(StorageKeys.prefsPendingPushSync, true);
      _notifyControllersRefreshAfterSilentPush();
      return;
    }

    if (_isChatMessage(message)) {
      if (_suppressForegroundChatNotification(message)) return;
      await chat_notifications.NotificationService.instance.handleIncomingMessage(
        message,
      );
      return;
    }
    await _showLocalNotification(message);
  }

  bool _isChatMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString().trim();
    final notificationType = data['notificationType']?.toString().trim();
    return type == 'chat_message' || notificationType == 'chat_message';
  }

  bool _suppressForegroundChatNotification(RemoteMessage message) {
    final incoming =
        (message.data['chat_id'] ?? message.data['chatId'])
            ?.toString()
            .trim() ??
        '';
    if (incoming.isEmpty) return false;
    final suppress =
        ChatAudioFocus.shouldSuppressForegroundFcmForChat(incoming);
    if (suppress) {
      appLog(
        'FCM foreground: suppress chat_message tray for chatId=$incoming '
        '(${ChatAudioFocus.describeForLog()})',
      );
    } else if (kDebugMode) {
      appLog(
        'FCM foreground: show chat_message for chatId=$incoming '
        '(${ChatAudioFocus.describeForLog()})',
      );
    }
    return suppress;
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      final allowed =
          await PushPermissionsHelper.androidPostNotificationsGranted();
      if (!allowed) {
        appLog(
          'FCM foreground: skipping local notification (Android POST_NOTIFICATIONS not granted)',
        );
        return;
      }
    }
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title']?.toString().trim() ?? '';
    if (title.isEmpty) return;
    final body =
        notification?.body ?? message.data['body']?.toString().trim() ?? '';

    final rawFromData = message.data['pushSoundBase']?.toString();
    final notificationType = message.data['notificationType']?.toString();
    final soundBase = (rawFromData != null && rawFromData.isNotEmpty)
        ? rawFromData
        : pushSoundBaseForNotificationType(notificationType);
    final channelId = pushChannelIdForSoundBase(soundBase);
    final channelName =
        soundBase != null ? 'Point: $soundBase' : 'General Notifications';
    final iosSoundFile = iosPushSoundFile(soundBase);

    if (Platform.isAndroid) {
      final android = appLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            channelId,
            channelName,
            description: 'Point push notifications',
            importance: Importance.high,
            playSound: true,
            sound: soundBase == null
                ? null
                : RawResourceAndroidNotificationSound(soundBase),
          ),
        );
      }
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Point push notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_launcher_monochrome',
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: iosSoundFile,
    );

    await appLocalNotificationsPlugin.show(
      id: notification?.hashCode ?? title.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: jsonEncode(message.data.map((k, v) => MapEntry(k, '$v'))),
    );
    appLog('Foreground non-chat local notification shown type=$notificationType');
  }

  bool _isSilentPushData(Map<String, String> data) {
    final v = data['silentSync'] ?? data['fcmSilentSync'];
    if (v == null) return false;
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  Map<String, String> _stringDataMap(RemoteMessage message) {
    return {
      for (final e in message.data.entries)
        e.key: e.value?.toString() ?? '',
    };
  }

  Future<void> _consumePendingPushSyncPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(StorageKeys.prefsPendingPushSync) != true) return;
    await prefs.setBool(StorageKeys.prefsPendingPushSync, false);
    _notifyControllersRefreshAfterSilentPush();
  }

  void _notifyControllersRefreshAfterSilentPush() {
    try {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().refreshAfterSilentPush();
      }
    } catch (_) {}
    try {
      if (Get.isRegistered<ClientController>()) {
        Get.find<ClientController>().refreshAfterSilentPush();
      }
    } catch (_) {}
  }

  int? _parseNotificationCreatedAtMs(Object? v) {
    if (v == null) return null;
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is int) return v;
    if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch;
    return null;
  }

  Future<void> _pollMissedInAppNotificationsOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(StorageKeys.prefsFcmTokenUserId)?.trim() ?? '';
    if (userId.isEmpty) return;

    final lastMs = prefs.getInt(StorageKeys.prefsNotificationsResumeCursorMs) ?? 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .limit(50)
          .get();

      var maxMs = lastMs;
      var hasNewerUnread = false;
      for (final doc in snap.docs) {
        final ms = _parseNotificationCreatedAtMs(doc.data()['createdAt']) ?? 0;
        if (ms > lastMs) hasNewerUnread = true;
        if (ms > maxMs) maxMs = ms;
      }
      if (hasNewerUnread) {
        _notifyControllersRefreshAfterSilentPush();
      }
      if (maxMs > lastMs) {
        await prefs.setInt(StorageKeys.prefsNotificationsResumeCursorMs, maxMs);
      }
    } catch (e, st) {
      appLog('resume in-app notifications poll: $e\n$st');
    }
  }
}
