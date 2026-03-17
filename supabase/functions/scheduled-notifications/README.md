# scheduled-notifications

دالة Supabase Edge مجدولة (Cron) لتنفيذ إشعارات التذكير بدون Firebase Blaze.

## ما الذي ترسله؟

- **مهام**:
  - ⏳ اقتراب موعد التسليم خلال 24 ساعة (للموظف المعيّن).
  - ⚠️ مهمة متأخرة (للإدارة: admin + supervisor).
- **محتوى**:
  - 🕐 محتوى بانتظار مراجعة العميل منذ أكثر من 24 ساعة (للعميل).
- **النشر**:
  - ⏰ تذكير منشور خلال ساعة (لمنفذ المحتوى أو لأحد فريق النشر).
  - ⚠️ لا توجد منشورات مجدولة ليوم غد (لفريق النشر + الإدارة).

## المتطلبات (Secrets)

ضع هذه الأسرار في Supabase Edge Functions Secrets:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: نفس القيمة التي تستخدمها في Flutter تحت `FIREBASE_SERVICE_ACCOUNT_JSON` (سطر واحد).
- `RESEND_API_KEY`: مفتاح Resend (موجود عندك أصلاً لدالة `send-notification-email`).
- `CRON_SECRET`: سر بسيط لتأمين الاستدعاء من cron (اختياري لكنه مُستحسن).

## النشر

```bash
supabase functions deploy scheduled-notifications
```

## الجدولة (Cron)

من **Supabase Dashboard → Integrations → Cron → Create a new cron job**:

| الحقل | القيمة |
|--------|--------|
| **Name** | `scheduled-notifications-hourly` (لا يمكن تغييره لاحقاً) |
| **Schedule** | `0 * * * *` (كل ساعة على الدقيقة 0) أو "Every hour" إن وُجد |
| **Type** | Supabase Edge Function |
| **Method** | POST |
| **Edge Function** | `scheduled-notifications` |
| **Timeout** | إذا الحد الأقصى عندك `5000ms` اتركه `5000` |
| **HTTP Headers** | `Authorization` = `Bearer <CRON_SECRET>` (نفس القيمة المُخزّنة في Secrets) |
| **HTTP Request Body** | ضع `{\"mode\":\"publish\"}` أو `{\"mode\":\"tasks\"}` أو `{\"mode\":\"content24h\"}` |

ثم اضغط **Create cron job**. تأكد أن `CRON_SECRET` في Edge Function Secrets مطابق للقيمة في الهيدر.

## توصية مع timeout=5000ms

بدلاً من Job واحد بـ `mode=all`، أنشئ 3 Jobs:

1) **publish**: كل ساعة  
Schedule: `0 * * * *`  
Body: `{\"mode\":\"publish\"}`

2) **tasks**: كل 6 ساعات  
Schedule: `0 */6 * * *`  
Body: `{\"mode\":\"tasks\"}`

3) **content24h**: يومياً مرة  
Schedule: `5 0 * * *`  
Body: `{\"mode\":\"content24h\"}`

