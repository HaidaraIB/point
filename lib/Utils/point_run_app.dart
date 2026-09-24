import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:point/Utils/point_web_hot_restart.dart';

/// Starts the app on all platforms, including web after a dev hot restart.
///
/// On web hot restart the engine disposes Flutter views before [main] runs again,
/// but [initializeEngineUi] is not re-invoked, so [runApp] can fail with
/// "platform did not provide" an implicit view. We recover by attaching to an
/// existing [ui.FlutterView] or, in debug, reloading once.
void pointRunApp(Widget app) {
  if (!kIsWeb) {
    runApp(app);
    return;
  }

  final dispatcher = WidgetsFlutterBinding.ensureInitialized().platformDispatcher;
  final implicit = dispatcher.implicitView;
  if (implicit != null) {
    runApp(app);
    return;
  }

  final views = dispatcher.views;
  if (views.isNotEmpty) {
    runWidget(View(view: views.first, child: app));
    return;
  }

  if (tryReloadWebAfterHotRestart()) {
    return;
  }

  runApp(app);
}
