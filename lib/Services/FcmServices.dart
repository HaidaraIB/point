import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:path_provider/path_provider.dart';
// import 'package:mohmacash/Services/googleApis.dart';
import 'package:http/http.dart' as http;

// import 'package:mohmacash/view/Screens/Tasks/TaskDetails.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // تهيئة كل حاجة
  Future<void> init() async {
    await _requestPermission();
    await _initLocalNotifications();
    await _setupInteractedMessage();
    _listenToForegroundMessages();
  }

  // طلب صلاحيات الإشعارات
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    log('User granted permission: ${settings.authorizationStatus}');
  }

  // تهيئة flutter_local_notifications
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  // لما المستخدم يضغط على الإشعار
  void _onNotificationResponse(NotificationResponse response) {
    log('Notification clicked with payload: ${response.data}');
    final payload = response.payload;
    if (payload != null) {

      // if (data['type'] == 'internal') {
      //   final id = data['id'];
      //   Get.to(() => TaskDetails(
      //         missionmodel: Get.find<HomeController>()
      //             .missions
      //             .firstWhere((a) => a.id == id),
      //       ));
      // } else if (data['type'] == 'external') {
      //   final url = data['url'];
      //   if (url != null) {
      //     launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      //   }
      // }
    }
  }

  // عرض الإشعار محليًا
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = notification?.android;

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

    if (notification != null && android != null) {
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'default_channel',
        'General Notifications',
        styleInformation: bigPicture,
        channelDescription: 'This channel is used for general notifications.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        notificationDetails,

        payload: jsonEncode(message.data), // optional
      );
    }
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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Received a message in foreground: ${message.notification?.title}');
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
