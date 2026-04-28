import 'package:point/Services/StorageKeys.dart';

/// يطابق [canReadTaskDoc] في firestore.rules: مهام القسم (`type`) أو المعيّنة للموظف.
String? taskTypeCodeForNormalizedDepartment(String normalizedDept) {
  switch (normalizedDept) {
    case StorageKeys.departmentPromotion:
      return '0';
    case StorageKeys.departmentDesign:
      return '1';
    case StorageKeys.departmentPhotography:
      return '2';
    case StorageKeys.departmentContentWriting:
      return '3';
    case StorageKeys.departmentMontage:
      return '4';
    case StorageKeys.departmentPublishing:
      return '5';
    case StorageKeys.departmentProgramming:
      return '6';
    case StorageKeys.departmentAdministration:
      return '7';
    default:
      return null;
  }
}
