import 'package:point/Models/EmployeeModel.dart';

/// Library access: managers implicitly; employees when admin grants [libraryAccess].
class LibraryPermissions {
  LibraryPermissions._();

  static bool _isManager(EmployeeModel? e) {
    if (e == null) return false;
    final r = e.role.trim().toLowerCase();
    return r == 'admin' || r == 'supervisor';
  }

  static bool canAccessLibrary(EmployeeModel? e) {
    if (e == null) return false;
    if (_isManager(e)) return true;
    return e.role.trim().toLowerCase() == 'employee' && e.libraryAccess;
  }

  static bool canUploadToLibrary(EmployeeModel? e) => canAccessLibrary(e);

  static bool canDeleteLibraryFile(EmployeeModel? e) => canAccessLibrary(e);
}
