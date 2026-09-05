import 'package:point/Utils/app_log.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/StorageKeys.dart';

/// مزامنة مستندات [authRoles] مع ملفات الموظف/العميل.
class FirestoreAuthApi {
  FirestoreAuthApi._();

  static const String authRolesCollection = 'authRoles';

  /// Signature of the last successful employee sync; the cold-start path calls
  /// [syncAuthRoleForEmployee] several times with identical data, and each call
  /// is a blocking write round-trip on the splash screen.
  static String? _lastEmployeeSyncSignature;

  /// Drop the memo so the next sync writes again (call on sign-out).
  static void invalidateAuthRoleSyncCache() {
    _lastEmployeeSyncSignature = null;
  }

  /// يزامن مستند [authRoles] لـ Firebase Auth uid مع بيانات الموظف في Firestore.
  /// تُستخدم قواعد الأمان للتحقق من أن الحقول تطابق `employees/{employeeId}`.
  /// Returns `true` when the write succeeded.
  static Future<bool> syncAuthRoleForEmployee(EmployeeModel employee) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final eid = employee.id?.trim();
    if (uid == null || uid.isEmpty || eid == null || eid.isEmpty) return false;
    try {
      final normalizedDepartments = StorageKeys.normalizeDepartments(
        employee.departments,
      );
      final signature = [
        uid,
        eid,
        employee.role,
        employee.libraryAccess,
        normalizedDepartments.join(','),
      ].join('|');
      if (signature == _lastEmployeeSyncSignature) return true;
      await FirebaseFirestore.instance.collection(authRolesCollection).doc(uid).set(
        {
          'role': employee.role,
          'employeeId': eid,
          'clientId': null,
          'departments': normalizedDepartments,
          // Temporary compatibility for old clients still using singular key.
          'department':
              normalizedDepartments.isEmpty ? '' : normalizedDepartments.first,
          'libraryAccess': employee.libraryAccess,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _lastEmployeeSyncSignature = signature;
      return true;
    } catch (e, s) {
      appLog('⚠️ syncAuthRoleForEmployee failed: $e');
      appLog('$s');
      return false;
    }
  }

  /// يزامن [authRoles] لحساب عميل بعد تسجيل الدخول.
  static Future<void> syncAuthRoleForClient(ClientModel client) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cid = client.id?.trim();
    if (uid == null || uid.isEmpty || cid == null || cid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection(authRolesCollection).doc(uid).set(
        {
          'role': 'client',
          'employeeId': null,
          'clientId': cid,
          'departments': <String>[],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, s) {
      appLog('⚠️ syncAuthRoleForClient failed: $e');
      appLog('$s');
    }
  }

  /// Admin path: sync [libraryAccess] on target employee's authRoles doc.
  static Future<void> syncAuthRoleLibraryAccessForEmployee(
    EmployeeModel employee,
  ) async {
    final authUid = employee.authUid?.trim();
    if (authUid == null || authUid.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection(authRolesCollection)
          .doc(authUid)
          .set(
            {
              'libraryAccess': employee.libraryAccess,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    } catch (e, s) {
      appLog('⚠️ syncAuthRoleLibraryAccessForEmployee failed: $e');
      appLog('$s');
      rethrow;
    }
  }
}
