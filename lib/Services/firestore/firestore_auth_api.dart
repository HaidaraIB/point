import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/EmployeeModel.dart';

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
      await FirebaseFirestore.instance.collection(authRolesCollection).doc(uid).set(
        {
          'role': employee.role,
          'employeeId': eid,
          'clientId': null,
          'department': employee.department,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, s) {
      log('⚠️ syncAuthRoleForEmployee failed: $e');
      log('$s');
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
          'department': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, s) {
      log('⚠️ syncAuthRoleForClient failed: $e');
      log('$s');
    }
  }
}
