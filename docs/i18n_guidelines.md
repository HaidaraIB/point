# i18n guidelines

## قواعد أساسية
- أي نص يظهر للمستخدم يجب أن يمر عبر مفتاح ترجمة (`.tr`).
- يمنع إضافة نصوص ثابتة داخل `lib/View`.
- يجب إضافة كل مفتاح جديد في اللغتين `ar` و `en` بنفس الاسم.

## نمط التسمية
- استخدم أسماء واضحة بنطاقات:
  - `common.*`
  - `auth.*`
  - `home.*`
  - `chat.*`
  - `errors.*`

## إدارة اللغة
- استخدم `LanguageController` لتغيير اللغة وحفظها.
- لا تغيّر `Get.updateLocale` مباشرة خارج الـ controller.

## التعامل مع الأخطاء
- واجهات المستخدم لا تعرض `error.toString()` الخام.
- استخدم طبقة mapping إلى مفاتيح `errors.*`.
- خدمات الباك إند ترجع `errorCode` ثابتة بدل رسائل خام.

## اتجاه النص (محتوى المستخدم)
- نصوص الواجهة من مفاتيح الترجمة (`.tr`) تتبع لغة التطبيق (RTL للعربية).
- النصوص الحرة أو المخزّنة (وصف مهمة، ملاحظات، محتوى عميل، معاينة رسائل): استخدم `ContentText` / `ContentSelectableText` أو `LinkifiedText` أو حقول `typedDirectionTextField` — لا تستخدم `Text(متغير)` بدون اتجاه من المحتوى (`contentParagraphTextDirection`).

## فحوصات الجودة
- شغّل:
  - `dart run tool/i18n_audit.dart`
  - `flutter test test/i18n_translations_parity_test.dart`

