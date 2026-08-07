# scheduled-notifications

دالة Supabase Edge مجدولة (Cron) لتنفيذ إشعارات التذكير بدون Firebase Blaze.

## ما الذي ترسله؟

- **مهام**:
  - ⏳ تذكير للموظف المعيّن مرة واحدة عند دخول المهمة نافذة **24 ساعة** متبقية، ومرة عند نافذة **6 ساعات** (مع حقول `dueSoonNotifiedAt24h` / `dueSoonNotifiedAt6h` لمنع التكرار؛ يُفضّل تشغيل الكرون **كل ساعة**).
  - ⚠️ مهمة متأخرة (للإدارة: admin + supervisor)، مع استبعاد المهام المنتهية (`status_task_completed`، `status_promotion_finished`، موافَق عليها، منشورة، مرفوضة، ونصوص قديمة مكافئة).
- **محتوى**:
  - 🕐 محتوى بانتظار مراجعة العميل منذ أكثر من 24 ساعة (للعميل).
- **النشر**:
  - ⏰ تذكير منشور خلال ١٥ دقيقة (لمنفذ المحتوى أو لأحد فريق النشر؛ يتخطّى `status_published` ويمنع التكرار عبر `publishSoonNotifiedAt`).
  - ⚠️ لا توجد منشورات مجدولة ليوم غد (لفريق النشر + الإدارة).

## المتطلبات (Secrets)

ضع هذه الأسرار في Supabase Edge Functions Secrets:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: JSON حساب خدمة **مشروع الإنتاج** (`project_id` = الإنتاج، سطر واحد).
- `FIREBASE_SERVICE_ACCOUNT_JSON_TEST`: (اختياري لكن مطلوب لتشغيل الكرون ضد مشروع الاختبار) JSON حساب خدمة **مشروع الاختبار** — نفس الشكل.
- `RESEND_API_KEY`: مفتاح Resend (موجود عندك أصلاً لدالة `send-notification-email`).
- `CRON_SECRET`: سر بسيط لتأمين الاستدعاء من cron (اختياري لكنه مُستحسن).

### ترويسات HTTP (مهم: بوابة Supabase)

لا تضع `CRON_SECRET` وحده في `Authorization`: البوابة تتوقع JWT صالحاً (مثل **مفتاح anon** العام).

**الموصى به للكرون و`curl`:**

| الترويسة | القيمة |
|----------|--------|
| `Authorization` | `Bearer <SUPABASE_ANON_KEY>` |
| `apikey` | نفس **anon key** |
| `x-cron-secret` | نفس **`CRON_SECRET`** المخزّن في Secrets |
| `Content-Type` | `application/json` |

**للتوافق مع الإعداد القديم:** `Authorization: Bearer <CRON_SECRET>` فقط — قد يعمل محلياً وقد يُرفض من البوابة على الرابط العام.

مثال `curl` (استبدل القيم ثم انسخ):

```bash
curl -sS -i -X POST \
  "https://YOUR_PROJECT_REF.supabase.co/functions/v1/scheduled-notifications" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "apikey: YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "x-cron-secret: YOUR_CRON_SECRET" \
  -d "{\"mode\":\"publish\",\"firebaseProjectId\":\"point-agency-production\"}"
```

في وظيفة Cron في لوحة Supabase أضف الترويسات الأربعة الأولى (مع body) كما في الجدول.

### جسم الطلب (HTTP body) واختيار مشروع Firebase

بالإضافة إلى `mode` يمكن إرسال **`firebaseProjectId`** (معرف مشروع Firebase كما في تطبيقك، مثل `point-agency-production` أو `point-f33cb`):

- يجب أن يكون المعرف **واحداً من المشاريع المعرّفة في الأسرار** أعلاه (قائمة بيضاء). أي قيمة أخرى تُرفض برسالة خطأ.
- إذا **لم** تُرسل `firebaseProjectId`، تُستخدم تلقائياً **`project_id` من `FIREBASE_SERVICE_ACCOUNT_JSON`** (سلوك متوافق مع الكرونات القديمة = الإنتاج).

مثال:

```json
{"mode":"publish","firebaseProjectId":"point-agency-production"}
```

```json
{"mode":"tasks","firebaseProjectId":"point-f33cb"}
```

## النشر

```bash
supabase functions deploy scheduled-notifications
```

## الجدولة (Cron)

من **Supabase Dashboard → Integrations → Cron → Create a new cron job**:

| الحقل | القيمة |
|--------|--------|
| **Type** | Supabase Edge Function |
| **Method** | POST |
| **Edge Function** | `scheduled-notifications` |
| **Timeout** | إذا الحد الأقصى عندك `5000ms` اتركه `5000` |
| **HTTP Headers** | انظر قسم «الترويسات» أدناه (بوابة Supabase + سر الكرون). |
| **HTTP Request Body** | JSON يتضمن `mode` واختيارياً `firebaseProjectId` (انظر أدناه) |

تأكد أن `CRON_SECRET` في Edge Function Secrets مطابق للقيمة في الهيدر إن استخدمته.

## ستة وظائف كرون مقترحة (3 أوضاع × مشروعان)

يمكنك إنشاء **6** وظائف Cron (أسماء فريدة لكل وظيفة)، أو الاكتفاء بثلاثة على بيئة الإنتاج فقط إن لم تحتج تشغيل الاختبار من نفس مشروع Supabase.

| المشروع | الوضع | مثال body |
|--------|--------|-----------|
| prod | publish | `{"mode":"publish","firebaseProjectId":"point-agency-production"}` |
| prod | tasks | `{"mode":"tasks","firebaseProjectId":"point-agency-production"}` |
| prod | content24h | `{"mode":"content24h","firebaseProjectId":"point-agency-production"}` |
| test | publish | `{"mode":"publish","firebaseProjectId":"point-f33cb"}` |
| test | tasks | `{"mode":"tasks","firebaseProjectId":"point-f33cb"}` |
| test | content24h | `{"mode":"content24h","firebaseProjectId":"point-f33cb"}` |

**ملاحظة:** استبدل المعرفات بقيم `projectId` الفعلية في `firebase_options.dart` و`firebase_options_test.dart` عندك إن اختلفت.

### جداول زمنية مقترحة (نفس التوصية السابقة)

مع timeout قصير، يُفضّل فصل `mode=all` إلى وظائف منفصلة:

1) **publish** (prod): كل ٥–١٠ دقائق — مثل `*/5 * * * *` — body prod أعلاه (نافذة التذكير ١٥ دقيقة؛ الكرون الساعي قد يفوّت المنشورات).  
2) **tasks** (prod): كل 6 ساعات — `0 */6 * * *`.  
3) **content24h** (prod): يومياً — `5 0 * * *`.  
4–6) نفس الجداول لـ **test** مع `firebaseProjectId` لمشروع الاختبار.

## توصية مع timeout=5000ms

بدلاً من Job واحد بـ `mode=all`، أنشئ وظائف منفصلة حسب `mode` (ومشروع Firebase إن لزم) كما في الجدول.
