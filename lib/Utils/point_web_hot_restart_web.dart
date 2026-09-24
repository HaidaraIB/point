import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Debug web hot restart: reload once so [runApp] gets an implicit view again.
bool tryReloadWebAfterHotRestart() {
  if (!kDebugMode) return false;

  const reloadGuardKey = 'point_web_hot_restart_reload';
  final storage = web.window.sessionStorage;
  if (storage.getItem(reloadGuardKey) != '1') {
    storage.setItem(reloadGuardKey, '1');
    web.window.location.reload();
    return true;
  }
  storage.removeItem(reloadGuardKey);
  return false;
}
