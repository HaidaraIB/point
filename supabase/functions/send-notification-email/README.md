# إرسال إيميل الإشعار (Resend)

هذه الدالة ترسل الإيميل من السيرفر لتجنب CORS على الويب، وتستخدم قالب HTML موحّد لتطبيق Point Agency عندما يكون المحتوى نصاً عادياً (`isHtml: false`).

## النشر وإعداد المفتاح

1. **تثبيت Supabase CLI** (إن لم يكن مثبتاً):
   ```bash
   npm i -g supabase
   ```

2. **تسجيل الدخول وربط المشروع**:
   ```bash
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   ```
   (`YOUR_PROJECT_REF` من لوحة Supabase → Project Settings → General → Reference ID)

3. **تعيين مفتاح Resend**:
   ```bash
   supabase secrets set RESEND_API_KEY=re_xxxxxxxx
   ```
   استبدل `re_xxxxxxxx` بمفتاحك من [resend.com](https://resend.com).

4. **نشر الدالة** (بعد أي تعديل على الكود):
   ```bash
   supabase functions deploy send-notification-email
   ```

   إن كنت تستخدم أيضاً جدولة الإشعارات من دالة `scheduled-notifications` وغيّرت اسم المرسل، انشرها بنفس الأسلوب:
   ```bash
   supabase functions deploy scheduled-notifications
   ```

بدلاً من CLI يمكن تعيين المفتاح من **Dashboard → Project Settings → Edge Functions → Secrets**.

---

## إعداد Resend لعرض المرسل والدومين

### 1. إضافة الدومين (Domain)

1. ادخل إلى [Resend Dashboard](https://resend.com/domains) → **Domains** → **Add Domain**.
2. أدخل دومينك، مثلاً: `mail.point-iq.app`.
3. أضف سجلات DNS التي يعرضها Resend (SPF، DKIM، وأي سجلات إضافية) في لوحة إدارة الدومين (عند مزود الدومين أو Cloudflare وغيرها).
4. انتظر التحقق (Verify) — قد يستغرق دقائق حتى 48 ساعة حسب DNS.

### 2. عنوان المرسل (From)

الدالة مضبوطة مسبقاً لاستخدام:

- **الاسم المعروض:** Point Agency  
- **البريد:** no-reply@mail.point-iq.app  

يظهر في صندوق الوارد كـ: **Point Agency &lt;no-reply@mail.point-iq.app&gt;**.

لا تحتاج لتغيير شيء في الكود إن كان الدومين المضاف هو `mail.point-iq.app`. إن استخدمت دوميناً آخر، عدّل ثابت `FROM_EMAIL` في `index.ts`.

### 3. قالب الإيميل (HTML Template)

- القالب موجود في `email-template.ts` ويستخدم ألوان التطبيق:
  - **Primary:** `#6736AE` (بنفسجي)
  - **نص:** `#344054`
  - **خلفية فاتحة:** `#F2F3F5`
- **الوضع الموحّد الموصى به (Wrapper-first):**
  - أرسل الطلب بـ `isHtml: false` ليتم تطبيق قالب `email-template.ts` تلقائياً.
  - يدعم الطلب `language` (`ar` أو `en`) لتحديد اتجاه النص ولغة القالب بشكل صريح:
    - `ar` → `dir="rtl"`
    - `en` → `dir="ltr"`
- مع **`isHtml: true`** يُستخدم `body` كمستند HTML جاهز دون تطبيق القالب (مسار متوافق مع التدفقات القديمة فقط).
- لتعديل الشكل العام: عدّل `email-template.ts` ثم أعد نشر الدالة.

#### شكل الطلب (مختصر)

```json
{
  "toEmail": "user@example.com",
  "subject": "Notification",
  "body": "Plain text body",
  "isHtml": false,
  "language": "ar"
}
```

> في الإرسال الدفعي `messages[]` يمكن تمرير `language` لكل رسالة.

### 4. اختبار الإرسال

من Resend Dashboard → **Emails** يمكنك مراجعة الإيميلات المرسلة وحالة التسليم.

- للتجربة السريعة من التطبيق: استخدم أي مسار يطلق `EmailNotificationService.sendNotification(...)`.
- للتأكد من القالب الموحّد: اجعل الإرسال عبر `isHtml: false` (مع `language` عند الحاجة).
