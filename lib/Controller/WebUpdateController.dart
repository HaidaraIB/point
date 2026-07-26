import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:point/config/app_config.dart';
import 'package:point/Services/web_update_reload.dart';

/// Polls deployed `version.json` on web and flags when a newer build is live.
///
/// Running build comes from compile-time `--dart-define=APP_BUILD_NUMBER`
/// (see Hostinger workflow), not from a network fetch of the same file —
/// otherwise "current" and "remote" would always match.
class WebUpdateController extends GetxController with WidgetsBindingObserver {
  static const Duration pollInterval = Duration(minutes: 5);
  static const Duration _fetchTimeout = Duration(seconds: 8);

  final RxBool updateAvailable = false.obs;

  Timer? _pollTimer;
  bool _dismissed = false;
  bool _checking = false;

  /// Only CI / release web builds pass `--dart-define=APP_BUILD_NUMBER`.
  /// Without it, comparing [AppConfig.appBuildNumber] fallbacks to served
  /// `version.json` false-triggers the banner on every local `flutter run`.
  static const bool _hasBakedBuildNumber = bool.hasEnvironment(
    'APP_BUILD_NUMBER',
  );

  int get _runningBuild =>
      int.tryParse(AppConfig.appBuildNumber.trim()) ?? 0;

  @override
  void onInit() {
    super.onInit();
    if (!kIsWeb || !_hasBakedBuildNumber) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(checkForUpdate());
    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(checkForUpdate());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb || !_hasBakedBuildNumber) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(checkForUpdate());
    }
  }

  Future<void> checkForUpdate() async {
    if (!kIsWeb || !_hasBakedBuildNumber || _dismissed || _checking) return;
    _checking = true;
    try {
      final uri = Uri.base.resolve('version.json').replace(
        queryParameters: <String, String>{
          't': '${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      final response = await http.get(uri).timeout(_fetchTimeout);
      if (response.statusCode != 200) return;
      final map = jsonDecode(response.body);
      if (map is! Map) return;
      final remote = int.tryParse(
            (map['build_number'] ?? '').toString().trim(),
          ) ??
          0;
      if (remote > _runningBuild) {
        updateAvailable.value = true;
      }
    } catch (_) {
      // Ignore transient network / parse errors; try again on next poll.
    } finally {
      _checking = false;
    }
  }

  void dismiss() {
    _dismissed = true;
    updateAvailable.value = false;
  }

  void reload() {
    reloadWebPage();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (kIsWeb && _hasBakedBuildNumber) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.onClose();
  }
}
