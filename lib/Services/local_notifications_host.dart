import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Single [FlutterLocalNotificationsPlugin] for the whole app.
///
/// Multiple plugin instances can cause duplicate tray entries even with the
/// same numeric [id]. All notification code should use this instance.
final FlutterLocalNotificationsPlugin appLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool _appLocalNotificationsInitialized = false;

void Function(NotificationResponse)? _onLocalNotificationResponse;

/// Set from the main isolate so tray taps can navigate. Background isolates
/// leave this null.
void setLocalNotificationTapHandler(
  void Function(NotificationResponse)? handler,
) {
  _onLocalNotificationResponse = handler;
}

/// Initializes local notifications once per isolate (main + background).
Future<void> ensureAppLocalNotificationsInitialized() async {
  if (kIsWeb || _appLocalNotificationsInitialized) return;
  _appLocalNotificationsInitialized = true;
  const androidInit = AndroidInitializationSettings(
    '@drawable/ic_launcher_monochrome',
  );
  const iosInit = DarwinInitializationSettings();
  const init = InitializationSettings(android: androidInit, iOS: iosInit);
  await appLocalNotificationsPlugin.initialize(
    settings: init,
    onDidReceiveNotificationResponse: (response) {
      _onLocalNotificationResponse?.call(response);
    },
  );
}

/// Same collapse rule as [supabase/functions/send-fcm] `androidChatCollapseTagFromData`.
String androidChatNotificationTag(String chatId) {
  final t = chatId.trim();
  if (t.isEmpty) return 'point_chat_unknown';
  final raw = 'point_chat_$t';
  return raw.length <= 64 ? raw : raw.substring(0, 64);
}
