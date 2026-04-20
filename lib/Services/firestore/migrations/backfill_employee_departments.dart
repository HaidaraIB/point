import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/app_log.dart';

/// One-shot migration: `employees.department` (string) → `employees.departments` (array)
/// and sync `authRoles.departments` for each uid. Gated by [metaDocId] completion flag.
///
/// Auth updates use `employees.authUid` → `authRoles/{uid}` so we never need a
/// collection-wide `authRoles` query (avoids list permission + duplicate listener noise).
class BackfillEmployeeDepartments {
  static const String metaCollection = 'meta';
  static const String metaDocId = 'employee_departments_v1';

  static DocumentReference<Map<String, dynamic>> get _metaRef =>
      FirebaseFirestore.instance.collection(metaCollection).doc(metaDocId);

  /// Ensures concurrent [runIfNeeded] calls (e.g. double `applyEmployeeSession`) share one run.
  static Future<void>? _migrationFuture;

  /// Call after sign-in when the current user is a manager (admin or supervisor).
  static Future<void> runIfNeeded({required bool isManager}) {
    if (!isManager) return Future<void>.value();
    return _migrationFuture ??=
        _executeMigration().whenComplete(() => _migrationFuture = null);
  }

  static Future<void> _executeMigration() async {
    try {
      final meta = await _metaRef.get();
      if (meta.exists && meta.data()?['completed'] == true) return;

      final db = FirebaseFirestore.instance;
      final employeesSnap = await db.collection('employees').get();

      final idToDepartments = <String, List<String>>{};

      for (final doc in employeesSnap.docs) {
        final data = doc.data();
        final role = data['role']?.toString().trim().toLowerCase() ?? '';
        final rawList = data['departments'];
        List<String> fromList = const [];
        if (rawList is List && rawList.isNotEmpty) {
          fromList = StorageKeys.normalizeDepartments(
            rawList.map((e) => e?.toString()),
          );
        }
        final legacy = StorageKeys.normalizeDepartment(
          data['department']?.toString(),
        );
        final merged = fromList.isNotEmpty
            ? fromList
            : (legacy.isNotEmpty ? <String>[legacy] : <String>[]);
        final depts =
            (role == 'admin' || role == 'supervisor') ? <String>[] : merged;
        idToDepartments[doc.id] = depts;
      }

      final employeeOps =
          <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>>[];
      for (final e in idToDepartments.entries) {
        final legacyDepartment = e.value.isEmpty ? '' : e.value.first;
        employeeOps.add(
          MapEntry(
            db.collection('employees').doc(e.key),
            <String, dynamic>{
              'departments': e.value,
              // Keep legacy key temporarily for old app builds.
              'department': legacyDepartment,
            },
          ),
        );
      }
      await _batchedUpdates(db, employeeOps);

      final authOps =
          <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>>[];
      final seenAuthUids = <String>{};
      for (final doc in employeesSnap.docs) {
        final data = doc.data();
        final authUid = data['authUid']?.toString().trim();
        if (authUid == null || authUid.isEmpty) continue;
        if (!seenAuthUids.add(authUid)) continue;
        final depts = idToDepartments[doc.id];
        if (depts == null) continue;
        authOps.add(
          MapEntry(
            db.collection('authRoles').doc(authUid),
            <String, dynamic>{
              'departments': depts,
              // Keep legacy key temporarily for old app builds.
              'department': depts.isEmpty ? '' : depts.first,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          ),
        );
      }

      var authOk = true;
      if (authOps.isNotEmpty) {
        try {
          await _batchedUpdates(db, authOps);
        } catch (e, s) {
          authOk = false;
          appLog(
            '⚠️ BackfillEmployeeDepartments: authRoles updates failed '
            '(employees already migrated; will retry next launch): $e',
          );
          appLog('$s');
        }
      }

      if (!authOk) return;

      await _metaRef.set({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      });
      appLog('✅ BackfillEmployeeDepartments: completed');
    } catch (e, s) {
      appLog('❌ BackfillEmployeeDepartments: $e');
      appLog('$s');
    }
  }

  static Future<void> _batchedUpdates(
    FirebaseFirestore db,
    List<MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>> items,
  ) async {
    if (items.isEmpty) return;
    var batch = db.batch();
    var n = 0;
    for (final item in items) {
      batch.update(item.key, item.value);
      n++;
      if (n >= 450) {
        await batch.commit();
        batch = db.batch();
        n = 0;
      }
    }
    if (n > 0) {
      await batch.commit();
    }
  }
}
