import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  final data = message.data;
  appLog(
    'FCM background rx: os=${Platform.operatingSystem} '
    'messageId=${message.messageId} hasFcmNotification=${message.notification != null} '
    'silentSync=${_isTruthy(data['silentSync'] ?? data['fcmSilentSync'])} '
    'notificationType=${data['notificationType']}',
  );

  final silent = _isTruthy(data['silentSync'] ?? data['fcmSilentSync']);
  if (silent) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.prefsPendingPushSync, true);
    return;
  }

  // رسالة data-only بعنوان (بدون كتلة notification من FCM) — عرض محلي على Android.
  if (Platform.isAndroid) {
    final hasFcmNotification = message.notification != null;
    if (!hasFcmNotification) {
      final title = data['title']?.toString();
      final body = data['body']?.toString();
      if (title != null && title.trim().isNotEmpty) {
        await _showAndroidDataOnlyHeadsUp(message, title, body ?? '');
      }
    }
  }
}

bool _isTruthy(Object? v) {
  if (v == null) return false;
  final s = v.toString().trim().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

Future<void> _showAndroidDataOnlyHeadsUp(
  RemoteMessage message,
  String title,
  String body,
) async {
  try {
    const androidInit = AndroidInitializationSettings(
      '@drawable/ic_launcher_monochrome',
    );
    const initSettings = InitializationSettings(android: androidInit);
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(initSettings);
    final android = plugin.resolvePlatformSpecificImplementation<
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

    final rawFromData = message.data['pushSoundBase']?.toString();
    final notificationType = message.data['notificationType']?.toString();
    final soundBase = (rawFromData != null && rawFromData.isNotEmpty)
        ? rawFromData
        : pushSoundBaseForNotificationType(notificationType);
    final channelId = pushChannelIdForSoundBase(soundBase);
    final channelName =
        soundBase != null ? 'Point: $soundBase' : 'إشعارات عامة';

    if (soundBase != null && soundBase.isNotEmpty) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          channelName,
          description: 'صوت مخصص للتطبيق',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundBase),
        ),
      );
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Point push notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_launcher_monochrome',
    );
    await plugin.show(
      title.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(message.data),
    );
  } catch (e, st) {
    appLog('background data-only notif: $e\n$st');
  }
}
