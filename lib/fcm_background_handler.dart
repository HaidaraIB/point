import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:point/Services/local_notifications_host.dart';
import 'package:point/Services/notifications/NotificationService.dart'
    as chat_notifications;
import 'package:point/Services/push_notification_sound.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/firebase_app_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: FirebaseAppOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (!e.code.contains('duplicate-app')) rethrow;
    }
  }

  appLog('FCM background rx message_id=${message.messageId}');
  final data = message.data;
  final silentRaw = data['silentSync'] ?? data['fcmSilentSync'];
  final silent = _isTruthy(silentRaw);
  if (silent) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.prefsPendingPushSync, true);
    return;
  }

  // Base FCM data uses type=internal; chat pushes use notificationType=chat_message.
  final notificationType =
      data['notificationType']?.toString().trim() ?? '';
  final legacyType = data['type']?.toString().trim() ?? '';
  if (notificationType == 'chat_message' || legacyType == 'chat_message') {
    await chat_notifications.NotificationService.instance.init();
    await chat_notifications.NotificationService.instance.handleIncomingMessage(
      message,
    );
    return;
  }

  final title = data['title']?.toString().trim() ?? '';
  if (title.isEmpty) return;
  final body = data['body']?.toString().trim() ?? '';

  await ensureAppLocalNotificationsInitialized();
  final android = appLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;

  final rawFromData = data['pushSoundBase']?.toString();
  final soundBase = (rawFromData != null && rawFromData.isNotEmpty)
      ? rawFromData
      : pushSoundBaseForNotificationType(
          notificationType.isEmpty ? null : notificationType,
        );
  final channelId = pushChannelIdForSoundBase(soundBase);
  final channelName = soundBase != null ? 'Point: $soundBase' : 'General Notifications';
  await android.createNotificationChannel(
    AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'Point push notifications',
      importance: Importance.high,
      playSound: true,
      sound: soundBase == null ? null : RawResourceAndroidNotificationSound(soundBase),
    ),
  );

  final androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: 'Point push notifications',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@drawable/ic_launcher_monochrome',
  );
  await appLocalNotificationsPlugin.show(
    id: title.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(android: androidDetails),
  );
}

bool _isTruthy(Object? v) {
  if (v == null) return false;
  final s = v.toString().trim().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}
