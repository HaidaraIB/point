import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/StorageKeys.dart';

/// خدمة مركزية لإرسال إشعارات Push و Email بنصوص عربية موحدة.
/// تستدعي FirestoreServices.sendFcm / sendFcmForClient / sendFcmToEmployees.
class NotificationService {
  NotificationService._();

  static const Map<String, String> _departmentNameAr = {
    'cat1': 'قسم الترويج',
    'cat2': 'قسم التصميم',
    'cat3': 'قسم التصوير',
    'cat4': 'قسم كتابة المحتوى',
    'cat5': 'قسم المونتاج',
    'cat6': 'قسم النشر',
    'cat7': 'قسم البرمجة',
  };

  static const Map<String, String> _statusLabelAr = {
    StorageKeys.status_not_start_yet: 'لم يبدأ بعد',
    StorageKeys.status_processing: 'قيد التنفيذ',
    StorageKeys.status_under_revision: 'قيد المراجعة',
    StorageKeys.status_in_edit: 'قيد التعديل',
    StorageKeys.status_edit_requested: 'طلب التعديل',
    StorageKeys.status_ready_to_publish: 'جاهز للنشر',
    StorageKeys.status_scheduled: 'مؤجلة / مجدولة',
    StorageKeys.status_approved: 'مكتملة / تمت الموافقة',
    StorageKeys.status_published: 'تم النشر',
    StorageKeys.status_rejected: 'مرفوضة',
  };

  /// نوع المهمة (0-6) → قسم عربي
  static String departmentNameFromTaskType(String type) {
    final idx = int.tryParse(type);
    if (idx == null || idx < 0 || idx > 6) return 'قسم غير محدد';
    return _departmentNameAr['cat${idx + 1}'] ?? 'قسم غير محدد';
  }

  static String statusLabelAr(String status) =>
      _statusLabelAr[status] ?? status;

  // ─── إشعارات الموظف (حسب القسم) ─────────────────────────────────────────

  /// ✅ تم تعيينك على مهمة جديدة (عنوان المهمة)
  static Future<void> notifyEmployeeAssignedToTask({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'تم تعيينك على مهمة جديدة',
      body: taskTitle,
    );
  }

  /// ⏳ اقتراب موعد التسليم — يُستدعى من Cloud Function
  static Future<void> notifyTaskDueSoon({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: '⏳ اقتراب موعد التسليم',
      body: 'المهمة: $taskTitle',
    );
  }

  /// طلب تعديل على المهمة (عنوان) من قبل الإدارة
  static Future<void> notifyEmployeeEditRequestedByManagement({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'طلب تعديل على المهمة من قبل الإدارة',
      body: taskTitle,
    );
  }

  /// مهمة مرفوضة — تم رفض المهمة (عنوان) من قبل الإدارة
  static Future<void> notifyEmployeeTaskRejected({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'مهمة مرفوضة',
      body: 'تم رفض المهمة ($taskTitle) من قبل الإدارة',
    );
  }

  /// 🛠 تم إعادة فتح مهمة لوجود ملاحظات
  static Future<void> notifyEmployeeTaskReopened({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'تم إعادة فتح مهمة لوجود ملاحظات',
      body: taskTitle,
    );
  }

  /// 📎 تم إرفاق ملفات جديدة بالمهمة
  static Future<void> notifyEmployeeNewAttachments({
    required String employeeId,
    required String taskTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'تم إرفاق ملفات جديدة بالمهمة',
      body: taskTitle,
    );
  }

  /// 🔁 تم تغيير حالة المهمة (إلى: ...)
  static Future<void> notifyEmployeeTaskStatusChanged({
    required String employeeId,
    required String taskTitle,
    required String newStatus,
  }) async {
    final label = statusLabelAr(newStatus);
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'تم تغيير حالة المهمة',
      body: '$taskTitle — إلى: $label',
    );
  }

  // ─── إشعارات المدير / الإدارة ───────────────────────────────────────────

  /// 🔁 تم استلام المهمة من قبل الموظف (اسم الموظف) وهي قيد التنفيذ الآن
  static Future<void> notifyManagersTaskReceivedByEmployee({
    required String employeeName,
    required String taskTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'تم استلام المهمة من قبل الموظف وهي قيد التنفيذ الآن',
      body: 'الموظف: $employeeName — المهمة: $taskTitle',
    );
  }

  /// 🔁 قام الموظف (اسم) بإنجاز المهمة (عنوان) يرجى الاطلاع والموافقة
  static Future<void> notifyManagersTaskCompletedByEmployee({
    required String employeeName,
    required String taskTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'قام الموظف بإنجاز المهمة يرجى الاطلاع والموافقة',
      body: 'الموظف: $employeeName — المهمة: $taskTitle',
    );
  }

  /// قام الموظف (اسم) بالتعديل على المهمة (عنوان) يرجى الاطلاع
  static Future<void> notifyManagersEmployeeEditedTask({
    required String employeeName,
    required String taskTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'قام الموظف بالتعديل على المهمة يرجى الاطلاع',
      body: 'الموظف: $employeeName — المهمة: $taskTitle',
    );
  }

  /// 📤 تم رفع محتوى جديد للمراجعة من قبل العميل (اسم العميل)
  static Future<void> notifyManagersContentSubmittedByClient({
    required String clientName,
    required String contentTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'تم رفع محتوى جديد للمراجعة من قبل العميل',
      body: 'العميل: $clientName — المحتوى: $contentTitle',
    );
  }

  /// ⚠️ مهمة متأخرة — تجاوزت موعد التسليم (المهمة) (الموظف)
  static Future<void> notifyManagersTaskOverdue({
    required String taskTitle,
    required String employeeName,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'مهمة متأخرة',
      body: 'تجاوزت موعد التسليم: $taskTitle — الموظف: $employeeName',
    );
  }

  /// 🆕 تم إنشاء مهمة جديدة في قسم (المونتاج / التصميم…)
  static Future<void> notifyManagersNewTaskInDepartment({
    required String taskTitle,
    required String departmentNameAr,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'تم إنشاء مهمة جديدة في قسم $departmentNameAr',
      body: taskTitle,
    );
  }

  /// 📩 استلام ملاحظات من العميل (اسم العميل) المحتوى (عنوان)
  static Future<void> notifyManagersClientNotesOnContent({
    required String clientName,
    required String contentTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'استلام ملاحظات من العميل',
      body: 'العميل: $clientName — المحتوى: $contentTitle',
    );
  }

  /// ✅ العميل (اسم) قام بالموافقة على المحتوى (عنوان)
  static Future<void> notifyManagersClientApprovedContent({
    required String clientName,
    required String contentTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'العميل قام بالموافقة على المحتوى',
      body: 'العميل: $clientName — المحتوى: $contentTitle',
    );
  }

  // ─── إشعارات العميل ────────────────────────────────────────────────────

  /// 📬 تم رفع (تصميم / فيديو جديد) بانتظار موافقتك
  static Future<void> notifyClientContentPendingApproval({
    required String clientId,
    required String contentTypeLabel,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'تم رفع $contentTypeLabel بانتظار موافقتك',
      body: 'يرجى الاطلاع والموافقة أو طلب التعديل',
    );
  }

  /// 🕐 لديك محتوى بانتظار المراجعة منذ أكثر من 24 ساعة
  static Future<void> notifyClientContentPendingOver24h({
    required String clientId,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'لديك محتوى بانتظار المراجعة منذ أكثر من 24 ساعة',
      body: contentTitle,
    );
  }

  /// ✅ شكراً! تمت الموافقة على التصميم من قبلك
  static Future<void> notifyClientApprovalConfirmed({
    required String clientId,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'شكراً! تمت الموافقة على التصميم من قبلك',
      body: 'تم تسجيل موافقتك بنجاح',
    );
  }

  /// ✏️ تم تنفيذ التعديلات التي طلبتها
  static Future<void> notifyClientEditsDone({
    required String clientId,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'تم تنفيذ التعديلات التي طلبتها',
      body: contentTitle,
    );
  }

  /// 🔁 محتوى جديد محدث بانتظار الموافقة
  static Future<void> notifyClientContentUpdatedForApproval({
    required String clientId,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'محتوى جديد محدث بانتظار الموافقة',
      body: contentTitle,
    );
  }

  /// 📅 تم جدولة المحتوى ليُنشر بتاريخ (DD/MM)
  static Future<void> notifyClientContentScheduled({
    required String clientId,
    required String contentTitle,
    required String dateFormatted,
  }) async {
    await FirestoreServices.sendFcmForClient(
      userId: clientId,
      title: 'تم جدولة المحتوى ليُنشر بتاريخ $dateFormatted',
      body: contentTitle,
    );
  }

  // ─── إشعارات قسم النشر (أدمن + موظف قسم النشر cat6) ───────────────────

  /// 📌 تمت إضافة محتوى جديد للعميل على منصة بتاريخ (DD/MM) الساعة (HH:MM)
  static Future<void> notifyPublishDeptContentAdded({
    required String clientName,
    required String platformLabel,
    required String dateFormatted,
    required String timeFormatted,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment('cat6');
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      title: 'تمت إضافة محتوى جديد للعميل على منصة',
      body: 'العميل: $clientName — المنصة: $platformLabel — $dateFormatted الساعة $timeFormatted',
    );
  }

  /// ✏️ قام العميل بطلب تعديل على المحتوى (عنوان)
  static Future<void> notifyPublishDeptClientEditRequest({
    required String contentTitle,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment('cat6');
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      title: 'قام العميل بطلب تعديل على المحتوى',
      body: contentTitle,
    );
  }

  /// 📤 وافق العميل (اسم) على المحتوى (عنوان)
  static Future<void> notifyPublishDeptClientApproved({
    required String clientName,
    required String contentTitle,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment('cat6');
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      title: 'وافق العميل على المحتوى',
      body: 'العميل: $clientName — المحتوى: $contentTitle',
    );
  }

  /// 🛑 تم رفض المحتوى (عنوان) من قبل العميل (اسم)
  static Future<void> notifyPublishDeptClientRejected({
    required String contentTitle,
    required String clientName,
  }) async {
    final adminIds = await FirestoreServices.getEmployeeIdsByRole(
      ['admin', 'supervisor'],
    );
    final deptIds = await FirestoreServices.getEmployeeIdsByDepartment('cat6');
    final all = <String>{...adminIds, ...deptIds};
    await FirestoreServices.sendFcmToEmployees(
      userIds: all.toList(),
      title: 'تم رفض المحتوى من قبل العميل',
      body: 'المحتوى: $contentTitle — العميل: $clientName',
    );
  }

  /// ⏰ تذكير: لديك منشور مجدول سيتم نشره خلال ساعة
  static Future<void> notifyPublishDeptPostInOneHour({
    required String employeeId,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'تذكير: لديك منشور مجدول سيتم نشره خلال ساعة',
      body: contentTitle,
    );
  }

  /// 📅 تنبيه: منشور مجدول اليوم ولم يتم تأكيده بعد
  static Future<void> notifyPublishDeptPostScheduledTodayNotConfirmed({
    required String employeeId,
    required String contentRef,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'تنبيه: منشور مجدول اليوم ولم يتم تأكيده بعد',
      body: 'المنشور: $contentRef',
    );
  }

  /// ⚠️ تنبيه: لا توجد منشورات مجدولة ليوم غد في حساب (العميل)
  static Future<void> notifyPublishDeptNoPostsTomorrow({
    required String employeeId,
    required String clientName,
  }) async {
    await FirestoreServices.sendFcm(
      userId: employeeId,
      title: 'تنبيه: لا توجد منشورات مجدولة ليوم غد',
      body: 'حساب العميل: $clientName',
    );
  }

  /// ✅ تم نشر المنشور بنجاح على منصة (XXX)
  static Future<void> notifyPublishDeptPostPublished({
    required List<String> recipientIds,
    required String platformLabel,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      title: 'تم نشر المنشور بنجاح على منصة $platformLabel',
      body: contentTitle,
    );
  }

  /// 🔗 تمت إضافة رابط المنشور
  static Future<void> notifyPublishDeptLinkAdded({
    required List<String> recipientIds,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      title: 'تمت إضافة رابط المنشور',
      body: contentTitle,
    );
  }

  /// 📝 تم إدخال الملاحظات بعد النشر من قبل الإدارة / العميل
  static Future<void> notifyPublishDeptNotesAfterPublish({
    required List<String> recipientIds,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      title: 'تم إدخال الملاحظات بعد النشر',
      body: contentTitle,
    );
  }

  /// ❌ تم إلغاء نشر منشور مجدول بناءً على طلب العميل
  static Future<void> notifyPublishDeptScheduledCancelled({
    required List<String> recipientIds,
    required String contentTitle,
  }) async {
    await FirestoreServices.sendFcmToEmployees(
      userIds: recipientIds,
      title: 'تم إلغاء نشر منشور مجدول بناءً على طلب العميل',
      body: contentTitle,
    );
  }

  // ─── إشعارات قسم الترويج ───────────────────────────────────────────────

  /// تم تغيير حالة المحتوى (اسم) إلى (قيد الترويج / انتهى الترويج) — للأدمن
  static Future<void> notifyAdminContentPromotionStatusChanged({
    required String contentTitle,
    required String promotionLabelAr,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByRole(['admin']);
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'تم تغيير حالة المحتوى',
      body: '$contentTitle — إلى: $promotionLabelAr',
    );
  }

  /// محتوى منشور جديد للعميل (اسم) يرجى الاطلاع وإضافته للحملة الإعلانية — لموظف الترويج
  static Future<void> notifyPromotionDeptNewPublishedContent({
    required String clientName,
    required String contentTitle,
  }) async {
    final ids = await FirestoreServices.getEmployeeIdsByDepartment('cat1');
    await FirestoreServices.sendFcmToEmployees(
      userIds: ids,
      title: 'محتوى منشور جديد للعميل يرجى الاطلاع وإضافته للحملة الإعلانية',
      body: 'العميل: $clientName — المحتوى: $contentTitle',
    );
  }
}
