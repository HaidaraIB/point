/// ثوابت عامة للتطبيق.
///
/// احتياطي لعرض الإصدار (خصوصاً على الويب) إذا تعذّر جلب `version.json` أو [PackageInfo].
/// يُفضّل مطابقته لحقل `version` في `pubspec.yaml` (مثلاً `1.0.2+1` → إصدار `1.0.2` وبناء `1`).
const String kAppVersionFallback = '1.0.2';
const String kAppBuildFallback = '1';

/// صورة افتراضية للملف الشخصي عند عدم وجود صورة للمستخدم.
/// استخدام ui-avatars.com يقلل أخطاء CORS على الويب مقارنة بمصادر أخرى.
const String kDefaultAvatarUrl =
    'https://ui-avatars.com/api/?name=User&background=999999&color=fff&size=128';
