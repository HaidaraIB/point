import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/chat_push_notification_ids.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/fcm_token_cache.dart';
import 'package:point/Services/push_notification_sound.dart';
import 'package:point/Services/push_permissions_helper.dart';
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

  static const Duration _kChatForegroundDebounce = Duration(milliseconds: 450);
  final Map<String, Timer> _chatForegroundDebounceTimers = {};
  final Map<String, List<String>> _chatForegroundLineBuffers = {};
  final Map<String, Map<String, String>> _chatForegroundLatestData = {};

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

  /// Clears the tray slot for [chatId] and any pending foreground merge buffer.
  Future<void> dismissChatMessageNotification(String chatId) async {
    if (kIsWeb) return;
    final c = chatId.trim();
    if (c.isEmpty) return;
    _clearChatForegroundDebounce(c);
    try {
      await init();
      await _localNotificationsPlugin.cancel(
        id: localNotificationIdForChat(c),
      );
    } catch (e, st) {
      appLog('dismissChatMessageNotification: $e\n$st');
    }
  }

  void _clearChatForegroundDebounce(String chatId) {
    _chatForegroundDebounceTimers.remove(chatId)?.cancel();
    _chatForegroundLineBuffers.remove(chatId);
    _chatForegroundLatestData.remove(chatId);
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
    // iOS: لا نعرض تنبيهاً مزدوجاً — العرض في المقدّمة عبر الإشعار المحلي فقط
    // (نفس مسار Android). Badge من النظام؛ الصوت من تفاصيل الإشعار المحلي.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
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

    final chatIdForSlot = message.data['chatId']?.toString().trim();
    final notifTypeTrim = message.data['notificationType']?.toString().trim();
    final int notificationId =
        (notifTypeTrim == 'chat_message' &&
                chatIdForSlot != null &&
                chatIdForSlot.isNotEmpty)
            ? localNotificationIdForChat(chatIdForSlot)
            : (notification?.hashCode ?? title.hashCode);
    final String? iosThreadId =
        (notifTypeTrim == 'chat_message' &&
                chatIdForSlot != null &&
                chatIdForSlot.isNotEmpty)
            ? chatIdForSlot
            : null;

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
      threadIdentifier: iosThreadId,
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body ?? '',
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _enqueueForegroundChatNotification(
    RemoteMessage message,
    Map<String, String> data,
    String chatId,
  ) async {
    final notification = message.notification;
    final title = notification?.title ?? data['title'] ?? '';
    final body = notification?.body ?? data['body'] ?? '';
    var line = '${title.trim()}: ${body.trim()}'.trim();
    if (line.isEmpty) line = body.trim();
    if (line.length > 140) {
      line = '${line.substring(0, 137)}...';
    }

    _chatForegroundLineBuffers.putIfAbsent(chatId, () => []).add(line);
    _chatForegroundLatestData[chatId] = Map<String, String>.from(data);

    _chatForegroundDebounceTimers[chatId]?.cancel();
    _chatForegroundDebounceTimers[chatId] = Timer(_kChatForegroundDebounce, () {
      _chatForegroundDebounceTimers.remove(chatId);
      unawaited(_flushForegroundChatBuffer(chatId));
    });
  }

  Future<void> _flushForegroundChatBuffer(String chatId) async {
    final lines = _chatForegroundLineBuffers.remove(chatId) ?? [];
    final latest = _chatForegroundLatestData.remove(chatId);
    if (lines.isEmpty || latest == null) return;
    await _showMergedChatLocalNotification(
      chatId: chatId,
      lines: lines,
      latestData: latest,
    );
  }

  Future<void> _showMergedChatLocalNotification({
    required String chatId,
    required List<String> lines,
    required Map<String, String> latestData,
  }) async {
    if (Platform.isAndroid) {
      final allowed =
          await PushPermissionsHelper.androidPostNotificationsGranted();
      if (!allowed) {
        appLog(
          'FCM foreground: skip merged chat notification (Android POST_NOTIFICATIONS not granted)',
        );
        return;
      }
    }

    final displayLines =
        lines.length > 5 ? lines.sublist(lines.length - 5) : List<String>.from(lines);
    final summaryCount = lines.length;
    final title = (latestData['title'] ?? '').trim().isEmpty
        ? 'Point'
        : (latestData['title']!.trim());
    final singleBody =
        lines.length == 1 ? (latestData['body'] ?? '').trim() : '';

    final rawFromData = latestData['pushSoundBase'];
    final notificationType = latestData['notificationType'];
    final soundBase = (rawFromData != null && rawFromData.isNotEmpty)
        ? rawFromData
        : pushSoundBaseForNotificationType(notificationType);
    final channelId = pushChannelIdForSoundBase(soundBase);
    final channelName =
        soundBase != null ? 'Point: $soundBase' : 'General Notifications';
    final iosSoundFile = iosPushSoundFile(soundBase);

    final summaryText =
        summaryCount > 1 ? '$summaryCount new messages' : null;

    final StyleInformation? androidStyle = displayLines.length <= 1
        ? null
        : InboxStyleInformation(
            displayLines,
            contentTitle: title,
            summaryText: summaryText,
          );

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      styleInformation: androidStyle,
      channelDescription: 'Point push notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_launcher_monochrome',
    );

    final resolvedBody = lines.length == 1
        ? (singleBody.isNotEmpty ? singleBody : displayLines.first)
        : (Platform.isAndroid ? displayLines.last : displayLines.join('\n'));
    final clippedBody = resolvedBody.length > 350
        ? '${resolvedBody.substring(0, 347)}...'
        : resolvedBody;

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: iosSoundFile,
      threadIdentifier: chatId,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      id: localNotificationIdForChat(chatId),
      title: title,
      body: clippedBody,
      notificationDetails: notificationDetails,
      payload: jsonEncode(latestData),
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
    final suppress =
        ChatAudioFocus.shouldSuppressForegroundFcmForChat(incoming);
    if (suppress) {
      appLog(
        'FCM foreground: suppress chat_message tray for chatId=$incoming '
        '(${ChatAudioFocus.describeForLog()}) dataKeys=${message.data.keys.toList()}',
      );
    } else if (kDebugMode) {
      appLog(
        'FCM foreground: show chat_message for chatId=$incoming '
        '(${ChatAudioFocus.describeForLog()})',
      );
    }
    return suppress;
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

    final type = data['notificationType']?.trim() ?? '';
    final chatId = data['chatId']?.trim() ?? '';
    if (type == 'chat_message' && chatId.isNotEmpty) {
      unawaited(_enqueueForegroundChatNotification(message, data, chatId));
      return;
    }

    // iOS وAndroid: في المقدّمة العرض عبر الإشعار المحلي (تفادي الاعتماد على تنبيه النظام على iOS).
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
      final title = message.notification?.title ?? message.data['title'];
      appLog(
        'FCM onMessage foreground title=$title '
        'notificationType=${message.data['notificationType']} '
        'chatId=${message.data['chatId']}',
      );
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
