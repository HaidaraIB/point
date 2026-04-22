import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/StorageKeys.dart';

/// صلاحيات محتوى الويب/الجدول: قسم الترويج vs قسم النشر vs الإدارة.
class ContentPermissions {
  ContentPermissions._();
  /// Publish section (Meta queue/settings) is manager-only for now.
  static bool canAccessPublishSection(EmployeeModel? e) {
    if (e == null) return false;
    final r = e.role.trim().toLowerCase();
    return r == 'admin' || r == 'supervisor';
  }


  static bool _isEmployee(EmployeeModel? e) => e?.role == 'employee';

  static bool isPromotionEmployee(EmployeeModel? e) {
    if (!_isEmployee(e)) return false;
    return e!.hasDepartment(StorageKeys.departmentPromotion);
  }

  static bool isPublishingEmployee(EmployeeModel? e) {
    if (!_isEmployee(e)) return false;
    return e!.hasDepartment(StorageKeys.departmentPublishing);
  }

  /// إضافة أو تعديل محتوى (نموذج كامل) — النشر والإدارة فقط.
  static bool canAddOrEditContent(EmployeeModel? e) {
    if (e == null) return false;
    final r = e.role.trim().toLowerCase();
    if (r == 'admin' || r == 'supervisor') return true;
    return isPublishingEmployee(e);
  }

  static bool canDeleteContent(EmployeeModel? e) {
    if (e == null) return false;
    final r = e.role.trim().toLowerCase();
    return r == 'admin' || r == 'supervisor';
  }

  /// تغيير حقل الترويج (organic / قيد الترويج …) — الترويج والإدارة فقط.
  static bool canChangePromotionField(EmployeeModel? e) {
    if (e == null) return false;
    final r = e.role.trim().toLowerCase();
    if (r == 'admin' || r == 'supervisor') return true;
    return isPromotionEmployee(e);
  }

  /// تغيير حالة البوست (status) — النشر والإدارة فقط (ليس قسم الترويج وحده).
  static bool canChangePostStatus(EmployeeModel? e) {
    if (e == null) return false;
    final r = e.role.trim().toLowerCase();
    if (r == 'admin' || r == 'supervisor') return true;
    return isPublishingEmployee(e);
  }

  /// موظف قسم الترويج فقط (بدون نشر) — يُخفى عنه واجهة الحالة وتاريخ النشر.
  static bool _employeePromotionOnly(EmployeeModel? e) {
    if (!_isEmployee(e)) return false;
    return isPromotionEmployee(e) && !isPublishingEmployee(e);
  }

  /// موظف قسم النشر فقط (بدون ترويج) — يُخفى عنه واجهة الترويج.
  static bool _employeePublishingOnly(EmployeeModel? e) {
    if (!_isEmployee(e)) return false;
    return isPublishingEmployee(e) && !isPromotionEmployee(e);
  }

  /// عرض عمود/بطاقة **حالة البوست** في إدارة المحتوى (موظف الترويج فقط لا يملكها).
  static bool showContentStatusUi(EmployeeModel? e) {
    if (e == null) return true;
    final r = e.role.trim().toLowerCase();
    if (r != 'employee') return true;
    return !_employeePromotionOnly(e);
  }

  /// عرض عمود/بطاقة **الترويج** (موظف النشر فقط لا يملك تغيير الترويج).
  static bool showContentPromotionUi(EmployeeModel? e) {
    if (e == null) return true;
    final r = e.role.trim().toLowerCase();
    if (r != 'employee') return true;
    return !_employeePublishingOnly(e);
  }

  /// عرض **تاريخ النشر** (من صلاحيات النشر؛ موظف الترويج فقط يُخفى عنه).
  static bool showContentPublishDateUi(EmployeeModel? e) {
    if (e == null) return true;
    final r = e.role.trim().toLowerCase();
    if (r != 'employee') return true;
    return !_employeePromotionOnly(e);
  }
}
