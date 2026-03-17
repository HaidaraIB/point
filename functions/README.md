# Point — إشعارات مجدولة (Cloud Functions)

دوال Firebase المجدولة ترسل إشعارات Push (FCM) وبريداً (عبر Supabase Edge Function) في الأوقات التالية:

- **scheduledTaskReminders** (كل 6 ساعات): اقتراب موعد تسليم المهمة، ومهام متأخرة.
- **scheduledContentPendingOver24h** (يومياً 00:00): محتوى بانتظار مراجعة العميل منذ أكثر من 24 ساعة.
- **scheduledPublishReminders** (كل ساعة): تذكير منشور خلال ساعة، وتنبيه لا منشورات غداً لحساب العميل.

## المتطلبات

- Node.js 18+
- مشروع Firebase مربوط (مثل `point-f33cb`).

## إعداد المتغيرات

قبل النشر، ضبط عنوان Supabase ومفتاح anon لاستدعاء دالة البريد:

```bash
firebase functions:config:set supabase.url="https://YOUR_PROJECT.supabase.co" supabase.anon_key="YOUR_ANON_KEY"
```

أو استخدم معلمات الدوال (v2):

```bash
firebase functions:secrets:set SUPABASE_URL
firebase functions:secrets:set SUPABASE_ANON_KEY
```

وربطها في الكود عبر `defineString` من `firebase-functions/params` إذا لزم.

## التثبيت والنشر

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

## الفهارس

استعلامات Firestore المستخدمة:

- `employees`: `role` in, `department` ==
- `contents`: `status` ==, `publishDate` (للتصفية في الذاكرة)
- `tasks`: قراءة كاملة ثم تصفية حسب `toDate` في الذاكرة

إذا زاد عدد المهام/المحتويات يمكن إضافة فهارس مركبة واستعلامات where مناسبة.
