import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/config/app_config.dart';

/// نتيجة قراءة إصدار التطبيق (للعرض في الواجهة).
class AppVersionInfo {
  const AppVersionInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

/// Display version for the running app.
///
/// Priority: CI dart-defines → [PackageInfo] (mobile) → `version.json` (web) →
/// placeholder fallbacks (never meant to track releases).
Future<AppVersionInfo> loadAppVersionInfo() async {
  if (bool.hasEnvironment('APP_VERSION') ||
      bool.hasEnvironment('APP_BUILD_NUMBER')) {
    final v = AppConfig.appVersion.trim();
    final b = AppConfig.appBuildNumber.trim();
    if (v.isNotEmpty && b.isNotEmpty) {
      return AppVersionInfo(version: v, buildNumber: b);
    }
  }

  if (!kIsWeb) {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersionInfo(
        version: info.version,
        buildNumber: info.buildNumber,
      );
    } catch (_) {
      // fall through
    }
  } else {
    try {
      final uri = Uri.base.resolve('version.json');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final v = map['version']?.toString().trim() ?? '';
        final b = map['build_number']?.toString().trim() ?? '';
        if (v.isNotEmpty && b.isNotEmpty) {
          return AppVersionInfo(version: v, buildNumber: b);
        }
      }
    } catch (_) {
      // fall through
    }
  }

  return const AppVersionInfo(
    version: kAppVersionFallback,
    buildNumber: kAppBuildFallback,
  );
}
