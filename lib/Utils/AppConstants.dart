/// ثوابت عامة للتطبيق.
///
/// Last-resort display only when `version.json` / [PackageInfo] / dart-defines
/// are unavailable. Do **not** bump these when releasing — bump `pubspec.yaml`
/// (and run `dart run scripts/sync_web_version.dart`, or let CI do it).
const String kAppVersionFallback = '0.0.0';
const String kAppBuildFallback = '0';

/// صورة افتراضية للملف الشخصي عند عدم وجود صورة للمستخدم.
/// استخدام ui-avatars.com يقلل أخطاء CORS على الويب مقارنة بمصادر أخرى.
const String kDefaultAvatarUrl =
    'https://ui-avatars.com/api/?name=User&background=999999&color=fff&size=128';
