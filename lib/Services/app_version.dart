import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:point/Utils/AppConstants.dart';

/// نتيجة قراءة إصدار التطبيق (للعرض في الواجهة).
class AppVersionInfo {
  const AppVersionInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

/// يقرأ الإصدار بشكل موثوق على **الويب** عبر `version.json` نسبةً إلى [Uri.base]،
/// ثم يستخدم القيم الاحتياطية [kAppVersionFallback] / [kAppBuildFallback].
///
/// على الويب قد يفشل طلب `version.json` في وضع التطوير؛ لذلك نحتفظ باحتياطي ثابت.
Future<AppVersionInfo> loadAppVersionInfo() async {
  if (kIsWeb) {
    try {
      final uri = Uri.base.resolve('version.json');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final v = map['version']?.toString().trim() ?? '';
        final b = map['build_number']?.toString().trim() ?? '';
        if (v.isNotEmpty && b.isNotEmpty) {
          return AppVersionInfo(version: v, buildNumber: b);
        }
      }
    } catch (_) {
      // ننتقل للاحتياطي أدناه
    }
  } else {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersionInfo(
        version: info.version,
        buildNumber: info.buildNumber,
      );
    } catch (_) {
      // ننتقل للاحتياطي أدناه
    }
  }

  return const AppVersionInfo(
    version: kAppVersionFallback,
    buildNumber: kAppBuildFallback,
  );
}
