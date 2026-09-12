import 'package:point/Models/EmployeeModel.dart';

/// Access control for the Point OS (agency back-office) section.
class OsPermissions {
  OsPermissions._();

  /// OS hub and future finance/HR modules are admin-only for now.
  static bool canAccessOsSection(EmployeeModel? e) {
    if (e == null) return false;
    return e.role.trim().toLowerCase() == 'admin';
  }
}
