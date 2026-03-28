# دليل صوت الإشعارات المخصّص (Push)

يعتمد المشروع على **اسم قاعدة واحد** (مثل `notification_foo`) يتكرر في عدة أماكن: الملفات `notification_foo.wav`، وFlutter، ودوال Supabase (`send-fcm`، `scheduled-notifications`).

---

## 1) إضافة صوت جديد

### أ) تسمية الملف

- استخدم **أحرف صغيرة وأرقام و`_` فقط** (شرط Android لـ `res/raw/`).
- مثال: `notification_my_event.wav`.

### ب) نسخ الملفات

1. ضع الأصل تحت **`assets/sounds/notification_my_event.wav`** (للأرشفة ولأي استخدام داخل Flutter لاحقاً).
2. انسخ **نفس الملف** إلى **`android/app/src/main/res/raw/notification_my_event.wav`**.
3. انسخ **نفس الملف** إلى **`ios/Runner/notification_my_event.wav`**.

### ج) ربط الملف في Xcode (iOS)

1. افتح **`ios/Runner.xcworkspace`** في Xcode.
2. اسحب `notification_my_event.wav` إلى مجموعة **Runner** (أو **Add Files to "Runner"…**).
3. فعّل **Copy items if needed** والهدف **Runner**.
4. تحقّق من **Build Phases → Copy Bundle Resources** أن الملف موجود (أو عدّل `ios/Runner.xcodeproj/project.pbxproj` يدوياً كما في المشروع إن كنت تفضّل ذلك).

### د) Flutter — `lib/Services/push_notification_sound.dart`

1. أضف القاعدة إلى **`kPushCustomSoundBases`**:  
   `'notification_my_event',`
2. في **`pushSoundBaseForNotificationType`**, اربط **`notificationType`** القادم من الخادم بالقاعدة:  
   `'some_notification_type': 'notification_my_event',`

بدون الخطوتين أعلاه لن تُنشأ **قناة Android** ولن يُحلّ الصوت في المقدّمة بشكل صحيح.

### هـ) الخادم — نفس الخريطة

عدّل **`soundBaseForNotificationType`** في:

- `supabase/functions/send-fcm/index.ts`
- `supabase/functions/scheduled-notifications/index.ts` (دالة `soundBaseForNotificationTypeCron`)

أضف نفس المفتاح → `"notification_my_event"`.

### و) إرسال النوع من التطبيق

في أي استدعاء **`FirestoreServices.sendFcm` / `sendFcmForClient` / `sendFcmToEmployees`**, مرّر:

`notificationType: 'some_notification_type'`

كما في `lib/Services/NotificationService.dart`.

### ز) النشر والبناء

- نشر الدوال: `supabase functions deploy send-fcm` (و`scheduled-notifications` إن استخدمت الأنواع هناك).
- أعد **بناء التطبيق** (ويفضّل إعادة تثبيت على الجهاز إن بقي صوت قديم بسبب قنوات Android).

---

## 2) تعديل صوت موجود (نفس السلوك، ملف جديد)

1. استبدل الملف **`assets/sounds/<الاسم>.wav`** بالنسخة الجديدة.
2. انسخ **نفس الاستبدال** إلى:
   - `android/app/src/main/res/raw/<الاسم>.wav`
   - `ios/Runner/<الاسم>.wav`
3. **لا تغيّر** اسم القاعدة إن لم تغيّر `notificationType` أو الخرائط.
4. أعد بناء التطبيق (واحذف التطبيق من الجهاز مرة إن لزم لتجديد قناة/كاش الصوت).

إذا غيّرت **اسم الملف/القاعدة** فهذا يعادل **إزالة القديم + إضافة جديد** (اتبع أقسام الإضافة والإزالة).

---

## 3) إزالة صوت مخصّص (العودة للافتراضي أو لصوت آخر)

1. **`lib/Services/push_notification_sound.dart`**
   - احذف القاعدة من **`kPushCustomSoundBases`**.
   - احذف السطر من **`pushSoundBaseForNotificationType`**، أو غيّر القيمة إلى قاعدة أخرى موجودة.
2. **`send-fcm/index.ts`** و **`scheduled-notifications/index.ts`**
   - احذف مفتاح `notificationType` من الخريطة، أو وجّهه لقاعدة أخرى؛ بدون تطابق يُستخدم صوت النظام **default**.
3. (اختياري) احذف الملفات من:
   - `assets/sounds/`
   - `android/app/src/main/res/raw/`
   - `ios/Runner/`
   - واحذف المراجع من **`project.pbxproj`** / Xcode إن أزلت ملف iOS.
4. أعد نشر الدوال وبناء التطبيق.

---

## 4) أين يظهر الصوت؟

| المكان | الدور |
|--------|--------|
| `res/raw` + حزمة iOS | صوت **FCM** في الخلفية/المغلق عندما يرسل الخادم `sound` + `channel_id` |
| `lib/Services/FcmServices.dart` + القنوات | صوت الإشعار **المحلي** عندما التطبيق في **المقدّمة** (خصوصاً Android) |
| Edge Functions | تختار `aps.sound` و`android.notification` بناءً على `notificationType` |

---

## 4.1) Android — ماذا تفعل حتى يعمل الصوت المخصّص؟

1. **الملف في المشروع**  
   - ضع **`اسم_القاعدة.wav`** تحت **`android/app/src/main/res/raw/`** (بدون أحرف كبيرة ولا شرطات؛ يطابق **`kPushCustomSoundBases`** بدون الامتداد).  
   - الخادم (`send-fcm`) يرسل **`android.notification.sound`** = **اسم المورد فقط** (مثل `notification_chat`) **بدون** `.wav` — وهذا يطابق اسم الملف في `res/raw`.

2. **قنوات الإشعارات (مهم جداً)**  
   - عند التشغيل، **`FcmServices`** (في `lib/Services/FcmServices.dart`) ينشئ قناة لكل عنصر في **`kPushCustomSoundBases`** ويربطها بـ **`RawResourceAndroidNotificationSound(base)`**.  
   - معرّف القناة في التطبيق والخادم هو: **`point_sound_<اسم_القاعدة>`** (انظر **`pushChannelIdForSoundBase`**).  
   - أي صوت **جديد**: أضف القاعدة إلى **`kPushCustomSoundBases`** ثم **أعد تثبيت التطبيق** وفتحه مرة (لإنشاء القناة). إن **غيّرت ملف WAV لقناة موجودة**، Android غالباً **لا يحدّث** صوت القناة عند المستخدم — الأفضل **حذف التطبيق وإعادة التثبيت** أو تغيير معرّف القناة (يتطلب تعديل كود + خادم معاً).

3. **مقدّمة التطبيق vs خلفية/مغلق**  
   - **مقدّمة**: يُعرض إشعار محلي عبر **`flutter_local_notifications`** باستخدام نفس **`channelId`** و**`pushSoundBase`** من `data`.  
   - **خلفية/مغلق**: يعتمد الصوت على حمولة FCM (**`channel_id`** + **`sound`**) كما يبنيها **`send-fcm`** — تأكد من **نشر الدالة** بعد تغيير الخريطة.

4. **إعدادات المستخدم على الجهاز**  
   - في **إعدادات التطبيق → الإشعارات**، تأكد أن القناة المعنية **غير مكتومة** وأن **الصوت مفعّل** لهذه القناة.

5. **بناء ونشر**  
   - **`flutter build apk/appbundle`** (أو تشغيل من IDE) بعد إضافة الملفات تحت `res/raw`.  
   - لا حاجة عادةً لتعديل **`AndroidManifest.xml`** لأجل اسم الصوت إذا كنت تستخدم FCM + القنوات البرمجية كما في المشروع.

---

## 4.2) iOS — ماذا تفعل حتى يعمل الصوت المخصّص؟

1. **الملف داخل حزمة التطبيق**  
   - انسخ **`اسم_القاعدة.wav`** إلى **`ios/Runner/`** وأضفه إلى هدف **Runner** في Xcode (**Copy Bundle Resources**).  
   - في الكود، اسم الصوت الممرّر لـ **`DarwinNotificationDetails`** و**`aps.sound`** هو **`اسم_القاعدة.wav`** (انظر **`iosPushSoundFile`** في `push_notification_sound.dart`).  
   - يجب أن **يطابق الاسم حرفياً** (بما في ذلك **`.wav`**) ما يظهر في الحزمة — أخطاء الإملاء أو الحالة تمنع التشغيل.

2. **ما يرسله الخادم**  
   - **`send-fcm`** يضبط **`aps.sound`** على نفس اسم الملف (مثل `notification_chat.wav`). لا حاجة لإدخال يدوي في `Info.plist` لكل ملف صوت إشعار إذا كان الملف داخل الـ bundle.

3. **مقدّمة التطبيق**  
   - **`setForegroundNotificationPresentationOptions(sound: true)`** مفعّل في **`FcmServices`** حتى تُسمَع الإشعارات في المقدّمة عند الحاجة.  
   - الإشعار المحلي يستخدم **`DarwinNotificationDetails(sound: ...)`** بنفس اسم الملف.

4. **متطلبات Apple الشائعة للصوت المخصّص**  
   - الملف يجب أن يكون ضمن **حزمة التطبيق** (ليس فقط تحت `assets` دون إدراج في Xcode).  
   - غالباً يُشترط أن يكون الطول **ضمن حدود معقولة** (Apple توصي تقنياً بعدم تجاوز ~30 ثانية للأصوات المخصّصة للإشعارات).  
   - الصيغ المدعومة تقليدياً تشمل **linear PCM** و**IMA4** و**µLaw** و**aLaw** في حاوية **CAF** أو ما يعادلها؛ **WAV** يعمل إذا كان الترميز متوافقاً. إن لم يُسمَع الصوت، جرّب إعادة تصدير الملف بإعدادات متوافقة أو تحويله إلى **CAF**.

5. **بناء ونشر**  
   - **`flutter build ipa`** أو الأرشفة من Xcode بعد التأكد من **Copy Bundle Resources**.  
   - اختبار **Push الحقيقي** يفضّل على **جهاز فعلي** (وليس الاعتماد على السيميوليتر فقط لسلوك الإشعارات الكامل).

6. **صلاحيات الإشعارات**  
   - يجب أن يمنح المستخدم التطبيق **إذن الإشعارات**؛ بدونها لن يظهر الإشعار ولا الصوت.

---

## 5) صوت داخل التطبيق فقط (ليس Push)

لتشغيل صوت عند حدث داخل الواجهة (مثل رسائل الدردشة المفتوحة)، يُستخدم **`lib/Services/AudioService.dart`** ومسار أصل في **`assets/sounds/`**. ذلك **مستقل** عن `push_notification_sound.dart` ما لم توحّد الملفات يدوياً.

---

## 6) ملاحظة عن التزامن

خرائط **`push_notification_sound.dart`** و**`send-fcm`** و**`scheduled-notifications`** يجب أن تبقى **متطابقة** لنفس أزواج `(notificationType → اسم القاعدة)`. أي اختلاف يسبب صوتاً خاطئاً أو افتراضياً على منصة دون الأخرى.

---

## 7) أداة «اختبار أنواع الإشعارات» (ميزة مرتبطة بالأصوات)

تسمح بإرسال **إشعار FCM تجريبي** لكل قيمة `notificationType` معروفة في المشروع، للتحقق من **الصوت** والقنوات والوصول، دون انتظار حدث حقيقي في النظام.

### من يستطيع فتح الأداة؟

- الأدوار: **`admin`**, **`supervisor`** (المقارنة غير حسّاسة لحالة الأحرف وبعد المسافات).
- المنطق: **`canOpenPushNotificationTester`** في `lib/Services/push_notification_test_catalog.dart`.
- زر الفتح في **الصفحة الرئيسية** `lib/View/Home/Home.dart` يعتمد على **`effectiveEmployee?.role`** (وليس `currentemployee` فقط) حتى تظهر الأداة بشكل صحيح عند اختلاف مصدر الجلسة.

### أين الواجهة والإرسال؟

| الملف | الغرض |
|--------|--------|
| `lib/View/Home/PushNotificationTestDialog.dart` | الحوار: اختيار النوع، الموظفين/العملاء، Push/بريد، زر الإرسال |
| `lib/Services/push_notification_test_catalog.dart` | قائمة الأنواع `kPushNotificationTestCatalog` + `sortedPushTestCatalog()` + `canOpenPushNotificationTester` |
| `lib/Services/FireStoreServices.dart` | `sendFcm` (موظف) و `sendFcmForClient` (عميل) — نفس `notificationType` في `data` |
| الترجمة | `AppLocaleKeys` / `AppTranslations` تحت المفتاح `push_test.*` |

### سلوك الإرسال (كما هو مطبّق حالياً)

- **أي نوع إشعار** يمكن إرساله إلى **أي مزيج** من الموظفين والعملاء المحددين:
  - كل موظف محدد → `sendFcm`.
  - كل عميل محدد → `sendFcmForClient`.
- حقل **`audience`** داخل تعريفات الكتالوج **تصنيف فقط** في القائمة؛ **لا يقيّد** من تُرسل لهم.
- إن لم يُختر أي موظف ولا أي عميل: يُغلق الحوار مع رسالة **عدم الإرسال** (`push_test.no_targets_closed`) — لا يُمنع الضغط على «إرسال» بسبب «نوع العميل/الموظف».
- زر **«إضافتي»** يستخدم **`effectiveEmployee?.id`** لإضافة المستخدم الحالي كموظف مستلم.

### ماذا تفعل بعد تغيير الأصوات أو الأنواع؟

1. أضف أو حدّث **`notificationType`** في الخرائط كما في الأقسام 1–3 (Flutter + Supabase).
2. **انشر** `send-fcm` و`scheduled-notifications` إن لمسّت خرائط الصوت هناك.
3. إن أردت ظهور النوع في قائمة الأداة: أضف مدخلاً في **`kPushNotificationTestCatalog`** في `push_notification_test_catalog.dart` (يمكن ترك `audience` كما يناسب التصنيف فقط).
4. أعد **بناء التطبيق** واختبر من الجهاز (خلفية/مقدّمة) مع الأداة.

### اختبار سريع للصوت

1. سجّل الدخول بدور مسموح (`admin` أو `supervisor`).
2. من الرئيسية: **اختبار أنواع الإشعارات**.
3. اختر **`notificationType`** المرتبط بالصوت في `pushSoundBaseForNotificationType`.
4. حدّد مستلمين (موظفين و/أو عملاء) وفعّل **إرسال Push**.
5. راقب الصوت على **Android/iOS** في المقدّمة والخلفية؛ راجع القسم 4 أعلاه لمسار الصوت.

---

## 8) المسؤولون (`admin`) وقائمة الموظفين (للتشغيل والاختبار)

لضمان ظهور **مسؤولي النظام** في شاشة الموظفين وفي قوائم المستلمين داخل أداة الاختبار:

- **`FirestoreServices.getEmployees()`** يعيد **جميع** مستندات مجموعة `employees`.
- نموذج **إضافة/تعديل موظف** يتضمن الأدوار **`supervisor`**, **`admin`**, **`employee`**: `EmployeesTable.dart` و `EmployeeFormMobilePage.dart`.
- عند الإنشاء/التحديث، يُعامل `admin` و`supervisor` مثل الأدوار العامة **بدون قسم** (`_globalRolesWithoutDepartment` في `FirestoreServices`) ويُضافون لمجموعات الدردشة من **`HomeController`** حيث ينطبق ذلك.

إن لم يظهر المستخدم في الأداة، تحقّق من وجوده في Firestore تحت **`employees`** ومن `role` المناسب (`admin` / `supervisor` / `employee`).

---

## 9) قائمة تحقق سريعة عند إطلاق ميزة جديدة (صوت + اختبار)

- [ ] مراجعة **§4.1 (Android)** و **§4.2 (iOS)** بعد أي تغيير على الملفات أو القنوات.
- [ ] ملف WAV في `assets/sounds/` + `android/.../res/raw/` + `ios/Runner/` (+ Xcode **Copy Bundle Resources** / `project.pbxproj` إن لزم).
- [ ] `push_notification_sound.dart`: `kPushCustomSoundBases` + `pushSoundBaseForNotificationType`.
- [ ] `send-fcm/index.ts` + `scheduled-notifications/index.ts`: نفس خريطة `notificationType → sound base`.
- [ ] استدعاءات الإنتاج: `notificationType` في `sendFcm` / `sendFcmForClient` / `NotificationService` حسب الحدث.
- [ ] `kPushNotificationTestCatalog`: إدخال اختياري لظهور النوع في أداة الاختبار.
- [ ] `supabase functions deploy send-fcm` (و`scheduled-notifications` إن لزم).
- [ ] بناء تطبيق جديد واختبار يدوي بالأداة على جهاز حقيقي.
