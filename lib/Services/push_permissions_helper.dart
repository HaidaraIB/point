import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// طلب إذن الإشعارات (FCM) ثم اقتراح استثناء البطارية على Android.
class PushPermissionsHelper {
  PushPermissionsHelper._();

  static Future<NotificationSettings> requestFirebaseNotificationPermission() {
    return FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static bool isNotificationAllowed(NotificationSettings settings) {
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// يُستدعى بعد منح إذن الإشعارات.
  static Future<void> maybeSuggestAndroidBatteryExemption() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (await Permission.ignoreBatteryOptimizations.isGranted) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(StorageKeys.prefsBatteryOptPromptShown) == true) {
      return;
    }
    await prefs.setBool(StorageKeys.prefsBatteryOptPromptShown, true);

    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) {
      await Permission.ignoreBatteryOptimizations.request();
      return;
    }

    final open = await Get.dialog<bool>(
      AlertDialog(
        title: Text('notify.battery_opt.title'.tr),
        content: Text('notify.battery_opt.body'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('notify.battery_opt.later'.tr),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text('notify.battery_opt.open_settings'.tr),
          ),
        ],
      ),
      barrierDismissible: true,
    );

    if (open == true) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  /// طلب الإشعار ثم اقتراح البطارية على Android.
  static Future<NotificationSettings> ensurePushPermissionsFlow() async {
    final settings = await requestFirebaseNotificationPermission();
    if (isNotificationAllowed(settings)) {
      await maybeSuggestAndroidBatteryExemption();
    }
    return settings;
  }

  /// Android 13+ runtime permission for posting local notifications.
  static Future<bool> androidPostNotificationsGranted() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final status = await Permission.notification.status;
    return status.isGranted;
  }
}
