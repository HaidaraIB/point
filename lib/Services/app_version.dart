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
/// ثم [PackageInfo]، ثم [kAppVersionFallback] / [kAppBuildFallback].
///
/// على الويب، `package_info_plus` يعتمد على طلب HTTP قد يفشل أو يُرجع حقولاً فارغة
/// في وضع التطوير؛ لذلك نجرب `Uri.base.resolve('version.json')` أولاً.
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
  }

  try {
    final info = await PackageInfo.fromPlatform();
    final v = info.version.trim();
    final b = info.buildNumber.trim();
    if (v.isNotEmpty && b.isNotEmpty) {
      return AppVersionInfo(version: v, buildNumber: b);
    }
  } catch (_) {}

  return const AppVersionInfo(
    version: kAppVersionFallback,
    buildNumber: kAppBuildFallback,
  );
}
