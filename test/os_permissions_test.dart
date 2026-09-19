import 'package:flutter_test/flutter_test.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_module_ids.dart';

EmployeeModel _employee({
  required String role,
  List<String> osModuleAccess = const [],
}) {
  return EmployeeModel(
    name: 'Test',
    email: 'test@example.com',
    role: role,
    status: 'active',
    createdAt: DateTime(2024),
    osModuleAccess: osModuleAccess,
  );
}

void main() {
  group('OsPermissions', () {
    test('admin has full OS access', () {
      final admin = _employee(role: 'admin');
      expect(OsPermissions.canAccessOsSection(admin), isTrue);
      expect(OsPermissions.canAccessModule(admin, OsModuleIds.invoices), isTrue);
      expect(OsPermissions.canDeleteOsRecords(admin), isTrue);
      expect(OsPermissions.canAccessOsSettings(admin), isTrue);
      expect(OsPermissions.visibleModules(admin).length, greaterThan(0));
    });

    test('supervisor without modules has no OS access', () {
      final supervisor = _employee(role: 'supervisor');
      expect(OsPermissions.canAccessOsSection(supervisor), isFalse);
      expect(
        OsPermissions.canAccessModule(supervisor, OsModuleIds.crm),
        isFalse,
      );
      expect(OsPermissions.canDeleteOsRecords(supervisor), isFalse);
      expect(OsPermissions.canAccessOsSettings(supervisor), isFalse);
      expect(OsPermissions.visibleModules(supervisor), isEmpty);
    });

    test('supervisor with granted module can access it only', () {
      final supervisor = _employee(
        role: 'supervisor',
        osModuleAccess: [OsModuleIds.invoices, OsModuleIds.crm],
      );
      expect(OsPermissions.canAccessOsSection(supervisor), isTrue);
      expect(
        OsPermissions.canAccessModule(supervisor, OsModuleIds.invoices),
        isTrue,
      );
      expect(
        OsPermissions.canAccessModule(supervisor, OsModuleIds.crm),
        isTrue,
      );
      expect(
        OsPermissions.canAccessModule(supervisor, OsModuleIds.finance),
        isFalse,
      );
      expect(OsPermissions.canDeleteOsRecords(supervisor), isFalse);
      expect(OsPermissions.visibleModules(supervisor).length, 2);
    });

    test('employee has no OS access', () {
      final employee = _employee(role: 'employee');
      expect(OsPermissions.canAccessOsSection(employee), isFalse);
      expect(
        OsPermissions.canAccessModule(employee, OsModuleIds.invoices),
        isFalse,
      );
    });

    test('bank account read follows dependent modules', () {
      final supervisor = _employee(
        role: 'supervisor',
        osModuleAccess: [OsModuleIds.emailHub],
      );
      expect(OsPermissions.needsBankAccountsRead(supervisor), isTrue);
      expect(OsPermissions.needsBranchesRead(supervisor), isTrue);
      expect(OsPermissions.needsServicesRead(supervisor), isFalse);
    });
  });
}
