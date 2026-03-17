# سياسات تخزين Supabase (bucket point)

## المشاكل الشائعة

**1) عند رفع ملف:**  
`StorageException(message: new row violates row-level security policy, statusCode: 403, error: Unauthorized)`

**2) عند تنزيل ملف (فتح رابط المرفق):**  
في المتصفح يظهر: `{"statusCode": "404", "error": "Bucket not found", "message": "Bucket not found"}`

حتى لو كان الـ bucket `point` موجوداً ويظهر في لوحة Supabase، هذا الخطأ يظهر عادة عندما يكون الـ bucket **خاصاً (Private)**. روابط التحميل في التطبيق تستخدم المسار العام (`/object/public/point/...`) وهذا يعمل فقط إذا كان الـ bucket **Public**.

---

## الحل: إنشاء الـ bucket ثم تفعيل السياسات

### الخطوة 1: إنشاء الـ bucket (مهم لرفع وتنزيل الملفات)

1. افتح [Supabase Dashboard](https://supabase.com/dashboard) واختر مشروعك (نفس المشروع الذي فيه الرابط `*.supabase.co` المستخدم في التطبيق).
2. من القائمة الجانبية: **Storage**.
3. إذا لم يظهر bucket باسم **point**:
   - اضغط **New bucket**.
   - **Name:** اكتب `point` (بدون مسافات، أحرف صغيرة).
   - فعّل **Public bucket** حتى تعمل روابط التحميل العامة (`getPublicUrl`) دون تسجيل دخول.
   - اضغط **Create bucket**.
4. إذا كان الـ bucket موجوداً بالفعل ولكن التحميل يعطي "Bucket not found": ادخل على الـ bucket **point** → **Configuration** (أو الإعدادات) → غيّر **Public bucket** إلى مفعّل (On) واحفظ. بعدها روابط التحميل يجب أن تعمل.

### الخطوة 2: تفعيل سياسات RLS (لتفادي خطأ 403 عند الرفع)

1. من **Storage** اختر bucket **point**.
2. افتح **SQL Editor** → **New query**.
3. انسخ محتوى الملف `storage-policies-point-bucket.sql` والصقه في المحرر.
4. اضغط **Run** لتنفيذ الـ SQL.
5. جرّب من التطبيق: رفع ملف (إضافة مهمة → إدراج مرفق) ثم تنزيله (زر تنزيل في المرفقات).

### ملاحظة
إذا ظهر خطأ أن السياسة موجودة مسبقاً، احذف السياسة من **Storage → point → Policies** ثم شغّل الـ SQL مرة أخرى.
