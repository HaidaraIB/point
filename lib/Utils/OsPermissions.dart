import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/View/Os/os_modules.dart';

/// Access control for the Point OS (agency back-office) section.
class OsPermissions {
  OsPermissions._();

  static String _role(EmployeeModel? e) => e?.role.trim().toLowerCase() ?? '';

  static bool _isAdmin(EmployeeModel? e) => _role(e) == 'admin';

  static bool _isSupervisor(EmployeeModel? e) => _role(e) == 'supervisor';

  /// OS hub when admin or supervisor with at least one granted module.
  static bool canAccessOsSection(EmployeeModel? e) {
    if (e == null) return false;
    if (_isAdmin(e)) return true;
    return _isSupervisor(e) && e.osModuleAccess.isNotEmpty;
  }

  /// Module-level access (view + create + edit).
  static bool canAccessModule(EmployeeModel? e, String moduleId) {
    if (e == null) return false;
    if (_isAdmin(e)) return true;
    if (!_isSupervisor(e)) return false;
    return e.osModuleAccess.contains(moduleId);
  }

  /// Record deletes in Point OS remain admin-only.
  static bool canDeleteOsRecords(EmployeeModel? e) => _isAdmin(e);

  static bool get canDeleteCurrentOsRecords {
    if (!Get.isRegistered<HomeController>()) return false;
    return canDeleteOsRecords(Get.find<HomeController>().effectiveEmployee);
  }

  /// `/os/settings` and secret credentials (Gemini, PayTabs, SMTP).
  static bool canAccessOsSettings(EmployeeModel? e) => _isAdmin(e);

  /// Live OS modules visible to [e] on hub cards and subpage nav.
  static List<OsModule> visibleModules(EmployeeModel? e) {
    if (!canAccessOsSection(e)) return const [];
    if (_isAdmin(e)) return osModules.where((m) => m.isLive).toList();
    return osModules
        .where((m) => m.isLive && canAccessModule(e, m.id))
        .toList();
  }

  /// Whether [e] may use OS AI features tied to [moduleId].
  static bool canUseOsAi(EmployeeModel? e, String moduleId) =>
      canAccessModule(e, moduleId);

  /// Read-only catalog data needed by granted modules.
  static bool needsBankAccountsRead(EmployeeModel? e) {
    if (_isAdmin(e)) return true;
    return canAccessModule(e, OsModuleIds.finance) ||
        canAccessModule(e, OsModuleIds.invoices) ||
        canAccessModule(e, OsModuleIds.quotations) ||
        canAccessModule(e, OsModuleIds.payroll) ||
        canAccessModule(e, OsModuleIds.emailHub);
  }

  static bool needsBranchesRead(EmployeeModel? e) {
    if (_isAdmin(e)) return true;
    return canAccessModule(e, OsModuleIds.branches) ||
        canAccessModule(e, OsModuleIds.expenses) ||
        canAccessModule(e, OsModuleIds.payroll) ||
        canAccessModule(e, OsModuleIds.invoices) ||
        canAccessModule(e, OsModuleIds.quotations) ||
        canAccessModule(e, OsModuleIds.emailHub);
  }

  static bool needsServicesRead(EmployeeModel? e) {
    if (_isAdmin(e)) return true;
    return canAccessModule(e, OsModuleIds.services) ||
        canAccessModule(e, OsModuleIds.invoices) ||
        canAccessModule(e, OsModuleIds.quotations);
  }
}
