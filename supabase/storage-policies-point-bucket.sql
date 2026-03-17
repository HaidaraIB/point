-- سياسات RLS لـ bucket "point" في Supabase Storage
-- تشغيل هذا الملف من: Supabase Dashboard → SQL Editor → New query → Paste → Run
-- يحل خطأ: StorageException(message: new row violates row-level security policy, statusCode: 403)

-- 1) السماح برفع ملفات (INSERT) للمفتاح العام (anon)
CREATE POLICY "Allow anon uploads to point bucket"
ON storage.objects
FOR INSERT
TO anon
WITH CHECK (bucket_id = 'point');

-- 2) السماح بقراءة ملفات (SELECT) لعرض الروابط العامة
CREATE POLICY "Allow public read point bucket"
ON storage.objects
FOR SELECT
TO anon
USING (bucket_id = 'point');
