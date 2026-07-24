/// ثوابت عامة للتطبيق.
///
/// احتياطي لعرض الإصدار (خصوصاً على الويب) إذا تعذّر جلب `version.json` أو [PackageInfo].
/// يُفضّل مطابقته لحقل `version` في `pubspec.yaml` (مثلاً `2.0.4+45` → إصدار `2.0.4` وبناء `45`).
const String kAppVersionFallback = '2.0.4';
const String kAppBuildFallback = '45';

/// صورة افتراضية للملف الشخصي عند عدم وجود صورة للمستخدم.
/// استخدام ui-avatars.com يقلل أخطاء CORS على الويب مقارنة بمصادر أخرى.
const String kDefaultAvatarUrl =
    'https://ui-avatars.com/api/?name=User&background=999999&color=fff&size=128';
