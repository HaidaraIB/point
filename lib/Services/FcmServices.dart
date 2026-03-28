import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:path_provider/path_provider.dart';
import 'package:point/Services/push_notification_sound.dart';
// import 'package:mohmacash/Services/googleApis.dart';
import 'package:http/http.dart' as http;

// import 'package:mohmacash/view/Screens/Tasks/TaskDetails.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Future<void>? _initFuture;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  // تهيئة كل حاجة (idempotent)
  Future<void> init() {
    _initFuture ??= () async {
      if (_isInitialized) return;
      _isInitialized = true;

      await _configureForegroundPresentation();
      await _initLocalNotifications();
      await _setupInteractedMessage();
      _listenToForegroundMessages();
    }();
    return _initFuture!;
  }

  Future<void> _configureForegroundPresentation() async {
    // iOS does not show foreground banners by default.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // تهيئة flutter_local_notifications
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@drawable/ic_launcher_monochrome');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    await _ensureAndroidNotificationChannels();
  }

  Future<void> _ensureAndroidNotificationChannels() async {
    if (!Platform.isAndroid) return;
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

  // لما المستخدم يضغط على الإشعار
  void _onNotificationResponse(NotificationResponse response) {
    log('Notification clicked with payload: ${response.data}');
    final payload = response.payload;
    if (payload != null) {
      // TODO: Handle the notification response
    }
  }

  // عرض الإشعار محليًا
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
      notification?.hashCode ?? title.hashCode,
      title,
      body ?? '',
      notificationDetails,
      payload: jsonEncode(message.data), // optional
    );
  }

  /// Local notification helper for testing.
  Future<void> showTestLocalNotification({
    required String title,
    required String body,
  }) async {
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
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(<String, String>{
        'type': 'local_test',
      }),
    );
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final response = await http.get(Uri.parse(url));
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  // الرسائل وقت ما التطبيق شغال
  void _listenToForegroundMessages() {
    _foregroundSub ??= FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Received a message in foreground: ${message.notification?.title}');
      // On iOS, if FCM includes `notification`, the system banner is already shown.
      // Skip local display to avoid duplicate notifications.
      if (Platform.isIOS && message.notification != null) return;
      _showLocalNotification(message);
    });
  }

  // لما المستخدم يفتح التطبيق من الإشعار (background أو terminated)
  Future<void> _setupInteractedMessage() async {
    // التطبيق مفتوح من إشعار والرسالة كانت background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log(
        'App opened from background notification: ${message.notification?.title}',
      );
      // اعمل هنا التنقل أو حاجة حسب الداتا
    });

    // أول مرة يتفتح التطبيق من terminated بالحالة دي
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      log(
        'App opened from terminated state with message: ${initialMessage.notification?.title}',
      );
      // اعمل معالجة للرسالة هنا
    }
  }
}
