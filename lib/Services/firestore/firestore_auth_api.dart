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

  /// يزامن مستند [authRoles] لـ Firebase Auth uid مع بيانات الموظف في Firestore.
  /// تُستخدم قواعد الأمان للتحقق من أن الحقول تطابق `employees/{employeeId}`.
  static Future<void> syncAuthRoleForEmployee(EmployeeModel employee) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final eid = employee.id?.trim();
    if (uid == null || uid.isEmpty || eid == null || eid.isEmpty) return;
    try {
      final normalizedDepartments = StorageKeys.normalizeDepartments(
        employee.departments,
      );
      await FirebaseFirestore.instance.collection(authRolesCollection).doc(uid).set(
        {
          'role': employee.role,
          'employeeId': eid,
          'clientId': null,
          'departments': normalizedDepartments,
          // Temporary compatibility for old clients still using singular key.
          'department':
              normalizedDepartments.isEmpty ? '' : normalizedDepartments.first,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, s) {
      appLog('⚠️ syncAuthRoleForEmployee failed: $e');
      appLog('$s');
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
}
