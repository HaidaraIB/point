# إرسال إيميل الإشعار (Resend)

هذه الدالة ترسل الإيميل من السيرفر لتجنب CORS على الويب، وتستخدم قالب HTML يطابق ألوان تطبيق Point Agency عندما يكون المحتوى نصاً عادياً (`isHtml: false`).

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
- المحتوى المرسل من التطبيق (حقل `body`) مع **`isHtml: false` (الافتراضي)** يُوضَع داخل القالب تلقائياً ويُحوَّل الأسطر إلى فقرات.
- مع **`isHtml: true`** يُستخدم `body` كمستند HTML جاهز لحقل `html` في Resend، ويُبنى جزء `text` تلقائياً من نسخة نصية مبسّطة (حتى لا يظهر مصدر HTML في عارض النص العادي).
- لتعديل الشكل لرسائل النص العادي: عدّل `email-template.ts` ثم أعد نشر الدالة.

### 4. اختبار الإرسال

من Resend Dashboard → **Emails** يمكنك مراجعة الإيميلات المرسلة وحالة التسليم. للتجربة من التطبيق، استخدم أي مسار يطلق `EmailNotificationService.sendNotification(...)` وسيُرسل الإيميل عبر هذه الدالة.
