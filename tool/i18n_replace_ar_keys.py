# One-off: replace Arabic literal .tr keys with English namespace keys.
from pathlib import Path

REPLS = [
    ("'اضافة مهمة'.tr", "'tasks.form.add_title'.tr"),
    ("'تعديل المهمة'.tr", "'tasks.form.edit_title'.tr"),
    ("'من فضلك قم بادخال بيانات المهمه'.tr", "'tasks.form.fill_required'.tr"),
    ("'عميل آخر'.tr", "'tasks.other_client'.tr"),
    ("'عنوان التصميم'.tr", "'tasks.form.design_title_label'.tr"),
    ("'اكتب اسم التصميم'.tr", "'tasks.form.design_name_hint'.tr"),
    ("'المنفذ'.tr", "'content.dialog.executor'.tr"),
    ("'نوع المهمه'.tr", "'tasks.form.task_type_label'.tr"),
    ("'اسم العميل'.tr", "'tasks.form.client_name_label'.tr"),
    ("'اكتب اسم العميل'.tr", "'tasks.form.client_name_hint'.tr"),
    ("'نوع التصميم'.tr", "'tasks.form.design_type_label'.tr"),
    ("'عدد التصاميم'.tr", "'task_details.design_count'.tr"),
    ("'القياسات'.tr", "'task_details.dimensions'.tr"),
    ("'اكتب القياسات'.tr", "'tasks.form.write_dimensions_hint'.tr"),
    ("'سجل الملاحظات'.tr", "'tasks.form.notes_log'.tr"),
    ("'عنوان المهمة'.tr", "'task_details.task_title'.tr"),
    ("'اكتب العنوان'.tr", "'tasks.form.write_title_hint'.tr"),
    ("'اختر المنفذ'.tr", "'tasks.form.select_executor'.tr"),
    ("'رابط المحتوى'.tr", "'task_details.content_link'.tr"),
    ("'اكتب رابط الملفات'.tr", "'task_details.files_link_hint'.tr"),
    ("'عنوان الفيديو'.tr", "'tasks.form.video_title_label'.tr"),
    ("'مدة الفديو'.tr", "'tasks.form.video_duration_label'.tr"),
    ("'اكتب مدة الفديو'.tr", "'tasks.form.video_duration_hint'.tr"),
    ("' رابط الملفات'.tr", "'tasks.form.files_link_hint'.tr"),
    ("'اختر المقاسات'.tr", "'tasks.form.select_size'.tr"),
    ("'التصنيف'.tr", "'task_details.category'.tr"),
    ("'عنوان التصوير'.tr", "'tasks.form.shooting_title_label'.tr"),
    ("'اختر المصور'.tr", "'tasks.form.select_photographer'.tr"),
    ("'مكان التصوير'.tr", "'tasks.form.shooting_place'.tr"),
    ("'نوع التصوبر'.tr", "'tasks.form.photography_shooting_type'.tr"),
    ("'عدد الصور'.tr", "'task_details.photo_count'.tr"),
    ("'عدد الصور او الفيديو'.tr", "'task_details.photo_video_count'.tr"),
    ("'مده التصوبر'.tr", "'tasks.form.photography_duration_label'.tr"),
    ("'اكتب مدة التصوير'.tr", "'tasks.form.photography_duration_hint'.tr"),
    ("'عنوان المنشور'.tr", "'tasks.form.post_title_label'.tr"),
    ("'رابط الملفات'.tr", "'task_details.files_link'.tr"),
    ("'حفظ'.tr", "'common.save'.tr"),
    ("'إلغاء'.tr", "'common.cancel'.tr"),
    ("'العميل'.tr", "'content.dialog.client'.tr"),
    ("'الأولوية'.tr", "'task_details.task_priority'.tr"),
    ("'تاريخ البداية'.tr", "'startat'.tr"),
    ("'تاريخ النهاية'.tr", "'endat'.tr"),
    ("'اختر التاريخ'.tr", "'common.select_date'.tr"),
    ("'ملاحظات'.tr", "'notes'.tr"),
    ("'ملاحظات (اختياري)'.tr", "'tasks.form.notes_optional_hint'.tr"),
    ("'اكتب عنوان المهمة'.tr", "'tasks.form.write_task_title_hint'.tr"),
    ("'المدة'.tr", "'task_details.duration'.tr"),
    ("'مدة الحملة'.tr", "'promotion.campaign_duration_hint'.tr"),
    ("'الدول'.tr", "'task_details.countries'.tr"),
    ("'الاهتمامات'.tr", "'task_details.interests'.tr"),
    ("'المدن'.tr", "'task_details.cities'.tr"),
    ("'الفئات العمرية'.tr", "'task_details.age_ranges'.tr"),
    ("'التخصصات'.tr", "'task_details.specializations'.tr"),
    ("'نوع التصوير'.tr", "'task_details.shooting_type'.tr"),
    ("'موقع التصوير'.tr", "'task_details.shooting_location'.tr"),
    ("'نوع المحتوى'.tr", "'task_details.content_type'.tr"),
    ("'رابط المرفقات'.tr", "'task_details.attachment_link'.tr"),
    ("'عنوان'.tr", "'tasks.form.title_short'.tr"),
    ("'البلد'.tr", "'task_details.country'.tr"),
    ("'الاعمار'.tr", "'promotion.age_label'.tr"),
    ("'من-الى'.tr", "'promotion.age_range_hint'.tr"),
    ("'ادارة المهام'.tr", "'tasks'.tr"),
    ("'ادارة المحتوى'.tr", "'managecontent'.tr"),
    ("'اجمالي المهام'.tr", "'employee.dashboard.total_tasks'.tr"),
    ("'قيد التنفيذ'.tr", "'status_processing'.tr"),
    ("'قيد المراجعة'.tr", "'status_under_revision'.tr"),
    ("'مكتملة'.tr", "'employee.dashboard.completed'.tr"),
    ("'ملغاة'.tr", "'employee.dashboard.cancelled'.tr"),
    ("'المهام المرسلة'.tr", "'tasks.summary.sent_tasks'.tr"),
    ("'المهام المسندة اليك'.tr", "'employee.dashboard.tasks_assigned_to_you'.tr"),
    ("'❌ يرجى اختيار عميل قبل إضافة محتوى جديد.'.tr", "'content.form.select_client_first'.tr"),
    ("'تاريخ النشر'.tr", "'publish_date'.tr"),
    ("'ادراج رابط'.tr", "'content.form.insert_link'.tr"),
    ("'تمت اضافة المحتوى بنجاح'.tr", "'content.add_success'.tr"),
    ("'تعديل المحتوى'.tr", "'content.form.edit_title'.tr"),
    ("'ليس لديك الصلاحيه'.tr", "'errors.no_permission'.tr"),
    ("'القسم'.tr", "'employees.department'.tr"),
    ("'اختر القسم '.tr", "'history.select_department'.tr"),
    ("'تم القبول بنجاح'.tr", "'client.accept_success'.tr"),
]

# Order matters: longer strings first where they share prefixes.
REPLS.sort(key=lambda x: -len(x[0]))

def main():
    root = Path("lib")
    for path in root.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        orig = text
        for old, new in REPLS:
            text = text.replace(old, new)
        if text != orig:
            path.write_text(text, encoding="utf-8")
            print("updated", path)

if __name__ == "__main__":
    main()
