import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/fcm_token_cache.dart';
import 'package:point/Services/push_notification_sound.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/app_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Future<void>? _initFuture;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  Future<void> init() {
    _initFuture ??= () async {
      if (_isInitialized) return;
      _isInitialized = true;

      if (!kIsWeb) {
        await _configureForegroundPresentation();
        await _logNotificationSettings();
        await _initLocalNotifications();
      }

      await _setupInteractedMessage();
      _listenToForegroundMessages();
    }();
    return _initFuture!;
  }

  /// بعد استئناف التطبيق: استهلاك طلبات المزامنة الصامتة ومقارنة توكن FCM.
  Future<void> onAppResumed() async {
    if (kIsWeb) return;
    await _consumePendingPushSyncPrefs();
    await FcmTokenCache.resyncIfChanged();
    await _pollMissedInAppNotificationsOnResume();
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

  /// سحب إشعارات الوارد غير المقروءة أحدث من آخر استطلاع — يعيد تحميل القوائم إن وُجدت جديدة.
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

  Future<void> _logNotificationSettings() async {
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      appLog('FCM getNotificationSettings: ${s.authorizationStatus}');
    } catch (e) {
      appLog('FCM getNotificationSettings failed: $e');
    }
  }

  Future<void> _configureForegroundPresentation() async {
    // iOS: عرض أصلي في المقدّمة (alert/sound/badge). الإشعار المحلي يُستخدم على Android
    // وعلى iOS لرسائل data-only التي تحمل title في data.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@drawable/ic_launcher_monochrome');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    await _ensureAndroidNotificationChannels();
  }

  Future<void> _ensureAndroidNotificationChannels() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final android = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        kPushDefaultChannelId,
        'إشعارات عامة',
        description: 'صوت النظام الافتراضي',
        importance: Importance.max,
        playSound: true,
      ),
    );

    for (final base in kPushCustomSoundBases) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          pushChannelIdForSoundBase(base),
          'Point: $base',
          description: 'صوت مخصص للتطبيق',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(base),
        ),
      );
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    appLog('Notification clicked with payload: ${response.data}');
    final payload = response.payload;
    if (payload != null) {
      // TODO: Handle the notification response
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();

    if (title == null || title.isEmpty) return;

    final rawFromData = message.data['pushSoundBase']?.toString();
    final notificationType = message.data['notificationType']?.toString();
    final soundBase = (rawFromData != null && rawFromData.isNotEmpty)
        ? rawFromData
        : pushSoundBaseForNotificationType(notificationType);

    final channelId = pushChannelIdForSoundBase(soundBase);
    final channelName =
        soundBase != null ? 'Point: $soundBase' : 'General Notifications';
    final iosSoundFile = iosPushSoundFile(soundBase);

    final imageUrl = notification?.android?.imageUrl ?? message.data['image'];

    BigPictureStyleInformation? bigPicture;
    if (imageUrl != null) {
      bigPicture = BigPictureStyleInformation(
        FilePathAndroidBitmap(
          await _downloadAndSaveFile(imageUrl, 'notif_img.jpg'),
        ),
        contentTitle: notification?.title,
        summaryText: notification?.body,
      );
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      styleInformation: bigPicture,
      channelDescription: 'Point push notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_launcher_monochrome',
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: iosSoundFile,
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      id: notification?.hashCode ?? title.hashCode,
      title: title,
      body: body ?? '',
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> showTestLocalNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      return;
    }

    await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      kPushDefaultChannelId,
      'General Notifications',
      channelDescription: 'This channel is used for general notifications.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_launcher_monochrome',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: jsonEncode(<String, String>{
        'type': 'local_test',
      }),
    );
  }

  bool _suppressForegroundChatNotification(RemoteMessage message) {
    final type = message.data['notificationType']?.toString().trim();
    if (type != 'chat_message') return false;
    final incoming =
        message.data['chatId']?.toString().trim() ?? '';
    if (incoming.isEmpty) return false;
    return ChatAudioFocus.incomingTreatAsInChat(incoming);
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

  Future<void> _handleForegroundPush(RemoteMessage message) async {
    final data = _stringDataMap(message);
    if (_isSilentPushData(data)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(StorageKeys.prefsPendingPushSync, true);
      _notifyControllersRefreshAfterSilentPush();
      return;
    }

    if (Platform.isIOS) {
      if (message.notification != null) {
        return;
      }
      final title = data['title']?.toString();
      if (title != null && title.trim().isNotEmpty) {
        await _showLocalNotification(message);
      }
      return;
    }

    // Android: رسائل تحمل كتلة notification من FCM قد تُعرض عبر مسار النظام؛
    // تجنّب الإشعار المحلي المزدوج بعد إضافة notification على جذر الرسالة في الخادم.
    if (Platform.isAndroid && message.notification != null) {
      return;
    }

    await _showLocalNotification(message);
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final response = await http.get(Uri.parse(url));
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  void _listenToForegroundMessages() {
    _foregroundSub ??= FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      appLog('Received a message in foreground: ${message.notification?.title}');
      if (_suppressForegroundChatNotification(message)) return;
      if (!kIsWeb) {
        unawaited(_handleForegroundPush(message));
      }
    });
  }

  Future<void> _setupInteractedMessage() async {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      appLog(
        'App opened from background notification: ${message.notification?.title}',
      );
    });

    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      appLog(
        'App opened from terminated state with message: ${initialMessage.notification?.title}',
      );
    }
  }
}
