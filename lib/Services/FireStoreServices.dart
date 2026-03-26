import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Models/ChatMetaData.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/EmailNotificationService.dart';
import 'package:point/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FirestoreServices {
  static Future<void> logClientDiagnosticError({
    required String source,
    required String code,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('app_error_logs').add({
        'source': source,
        'code': code,
        'message': error.toString(),
        'errorType': error.runtimeType.toString(),
        'stackTrace': stackTrace?.toString(),
        'uid': currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        if (extra != null) 'extra': extra,
      });
    } catch (e, s) {
      log('⚠️ logClientDiagnosticError failed: $e');
      log('StackTrace: $s');
    }
  }

  static const Set<String> _globalRolesWithoutDepartment = {
    'admin',
    'supervisor',
  };

  EmployeeModel _normalizeEmployeeDepartmentByRole(EmployeeModel employee) {
    if (_globalRolesWithoutDepartment.contains(employee.role)) {
      return employee.copyWith(department: null);
    }
    return employee;
  }

  /// On web, Firebase often returns [invalid-credential] instead of [user-not-found].
  /// If the Firestore profile has no [authUid] yet, we must still allow first-time
  /// [createUserWithEmailAndPassword] even when [authStatus] is already `active`
  /// (common with migrated data or admin-created rows).
  ///
  /// If the email is already registered, we catch [email-already-in-use] and retry
  /// [signInWithEmailAndPassword] once.
  Future<UserCredential> _signInOrLinkNewAuthUser({
    required FirebaseAuth auth,
    required String normalizedEmail,
    required String password,
    required bool profileHasAuthUid,
    required bool authPendingOrNotActive,
  }) async {
    try {
      return await auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      final needsFirstTimeLink = !profileHasAuthUid;
      final mayTryCreate =
          e.code == 'user-not-found' ||
          (e.code == 'invalid-credential' &&
              (authPendingOrNotActive || needsFirstTimeLink)) ||
          (e.code == 'wrong-password' &&
              (authPendingOrNotActive || needsFirstTimeLink));

      if (!mayTryCreate) rethrow;

      try {
        return await auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
      } on FirebaseAuthException catch (ce) {
        if (ce.code == 'email-already-in-use') {
          return await auth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
        }
        rethrow;
      }
    }
  }

  Future<void> _updateAuthFieldsWithRetry({
    required DocumentReference docRef,
    required String uid,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await docRef.update({'authUid': uid, 'authStatus': 'active'});
        return;
      } catch (e, s) {
        log(
          '⚠️ _updateAuthFieldsWithRetry attempt ${attempt + 1}/$maxAttempts failed: $e',
        );
        log('StackTrace: $s');
        if (attempt == maxAttempts - 1) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
  }

  static Future<void> _sendFcmViaFunction({
    String? token,
    String? topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    String _maskFcmToken(String t) {
      if (t.length <= 12) return '***';
      return '${t.substring(0, 6)}...${t.substring(t.length - 4)}';
    }

    final targetLabel = token != null
        ? 'token=${_maskFcmToken(token)}'
        : 'topic=${topic ?? "(null)"}';

    final firebaseIdToken =
        await FirebaseAuth.instance.currentUser?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw StateError('FirebaseAuth session required to send FCM.');
    }

    log(
      '➡️ FCM invoke start. target=$targetLabel title="$title" bodyLen=${body.length}',
    );

    final res = await Supabase.instance.client.functions.invoke(
      'send-fcm',
      // IMPORTANT: keep `authorization` for Supabase; pass Firebase token via a
      // dedicated header so the Edge Function can verify it.
      headers: <String, String>{
        'x-firebase-id-token': 'Bearer $firebaseIdToken',
      },
      body: <String, dynamic>{
        if (token != null) 'token': token,
        if (topic != null) 'topic': topic,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
      },
    );

    if (res.status != 200) {
      final responseData = res.data as Map<String, dynamic>?;
      final code = responseData?['errorCode']?.toString();
      log(
        '❌ FCM invoke failed. target=$targetLabel status=${res.status} errorCode=$code details=${responseData?['details']}',
      );
      switch (code) {
        case 'ERR_METHOD_NOT_ALLOWED':
          throw StateError(AppLocaleKeys.errorsMethodNotAllowed);
        case 'ERR_UNAUTHORIZED':
          throw StateError(AppLocaleKeys.errorsUnauthorized);
        case 'ERR_FORBIDDEN':
          throw StateError(AppLocaleKeys.errorsForbidden);
        case 'ERR_MISSING_TOKEN':
          throw StateError(AppLocaleKeys.errorsMissingToken);
        case 'ERR_INVALID_DATA':
          throw StateError(AppLocaleKeys.errorsInvalidData);
        default:
          throw StateError(AppLocaleKeys.errorsServer);
      }
    } else {
      log(
        '✅ FCM invoke success. target=$targetLabel status=${res.status} data=${res.data}',
      );
    }
  }

  // static get currentUser => '1';

  var db = FirebaseFirestore.instance;
  final CollectionReference _employeeCollection = FirebaseFirestore.instance
      .collection("employees");

  Future<bool> isEmailUsedInEmployees(
    String email, {
    String? excludeEmployeeId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return false;
    final snap =
        await _employeeCollection
            .where("email", isEqualTo: normalizedEmail)
            .limit(5)
            .get();
    for (final doc in snap.docs) {
      if (excludeEmployeeId != null && doc.id == excludeEmployeeId) continue;
      return true;
    }
    return false;
  }

  Future<bool> isEmailUsedInClients(
    String email, {
    String? excludeClientId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return false;
    final snap =
        await _clientCollection
            .where("email", isEqualTo: normalizedEmail)
            .limit(5)
            .get();
    for (final doc in snap.docs) {
      if (excludeClientId != null && doc.id == excludeClientId) continue;
      return true;
    }
    return false;
  }

  Future<bool> isEmailUsedAcrossUsers(
    String email, {
    String? excludeEmployeeId,
    String? excludeClientId,
  }) async {
    final inEmployees = await isEmailUsedInEmployees(
      email,
      excludeEmployeeId: excludeEmployeeId,
    );
    if (inEmployees) return true;
    return await isEmailUsedInClients(email, excludeClientId: excludeClientId);
  }

  Future<bool> createEmployeeWithAuth({
    required EmployeeModel employee,
    required String password,
  }) async {
    final normalizedEmployee = _normalizeEmployeeDepartmentByRole(employee);
    final email = normalizedEmployee.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      log('❌ createEmployeeWithAuth: email is required');
      return false;
    }
    try {
      await _employeeCollection
          .doc(normalizedEmployee.id)
          .set(
            normalizedEmployee.copyWith(
              authStatus: normalizedEmployee.authStatus ?? 'pendingActivation',
            ).toJson(),
          );
      log("✅ createEmployeeWithAuth: ${normalizedEmployee.name}");
      return true;
    } catch (e, s) {
      log("❌ createEmployeeWithAuth error: $e");
      log("StackTrace: $s");
      return false;
    }
  }

  Future<bool> updateEmployeeWithAuth({
    required EmployeeModel existing,
    required EmployeeModel updated,
    String? newPassword,
  }) async {
    final normalizedUpdated = _normalizeEmployeeDepartmentByRole(updated);
    try {
      final current = FirebaseAuth.instance.currentUser;
      final isEditingSelf =
          current != null &&
          existing.authUid != null &&
          existing.authUid == current.uid;

      // البريد وكلمة المرور في Auth يغيّرها صاحب الحساب فقط؛ المسؤول يحدّث بقية الحقول.
      final merged = normalizedUpdated.copyWith(
        email: isEditingSelf ? normalizedUpdated.email : existing.email,
        authUid: existing.authUid ?? normalizedUpdated.authUid,
        authStatus: existing.authStatus ?? normalizedUpdated.authStatus,
      );
      await _employeeCollection.doc(merged.id).update(merged.toJson());

      if (newPassword != null &&
          newPassword.trim().isNotEmpty &&
          isEditingSelf) {
        try {
          await current.updatePassword(newPassword.trim());
        } on FirebaseAuthException catch (e) {
          log(
            "⚠️ updateEmployeeWithAuth password update skipped: code=${e.code}, message=${e.message}",
          );
        }
      }
      log("✅ updateEmployeeWithAuth (table-only): ${merged.id}");
      return true;
    } catch (e, s) {
      log("❌ updateEmployeeWithAuth error: $e");
      log("StackTrace: $s");
      return false;
    }
  }

  // 🟢 إضافة موظف
  Future<bool> addEmployee(EmployeeModel employee) async {
    try {
      final normalizedEmployee = _normalizeEmployeeDepartmentByRole(employee);
      await _employeeCollection
          .doc(normalizedEmployee.id)
          .set(normalizedEmployee.toJson());
      log("✅ تم إضافة الموظف بنجاح: ${normalizedEmployee.name}");
      return true;
    } catch (e, s) {
      log("❌ خطأ أثناء إضافة الموظف: $e");
      log("StackTrace: $s");
      return false;
    }
  }

  // 🟡 تحديث موظف
  Future<bool> updateEmployee(EmployeeModel employee) async {
    try {
      final normalizedEmployee = _normalizeEmployeeDepartmentByRole(employee);
      if (normalizedEmployee.id == null) {
        throw Exception("معرف الموظف (id) مفقود!");
      }
      await _employeeCollection
          .doc(normalizedEmployee.id)
          .update(normalizedEmployee.toJson());
      log("✅ تم تحديث الموظف: ${normalizedEmployee.id}");
      return true;
    } catch (e, s) {
      log("❌ خطأ أثناء تحديث الموظف: $e");
      log("StackTrace: $s");
      return false;
    }
  }

  // 🔴 حذف موظف
  Future<bool> deleteEmployee(String id) async {
    try {
      await _employeeCollection.doc(id).delete();
      log("✅ تم حذف الموظف: $id");
      return true;
    } catch (e, s) {
      log("❌ خطأ أثناء حذف الموظف: $e");
      log("StackTrace: $s");
      return false;
    }
  }

  // 🔍 قراءة موظف واحد
  Future<EmployeeModel?> getEmployeeById(String id) async {
    try {
      final doc = await _employeeCollection.doc(id).get();
      if (!doc.exists) {
        log("⚠️ لا يوجد موظف بهذا الـ ID: $id");
        return null;
      }
      log("✅ تم جلب بيانات الموظف: $id");
      return EmployeeModel.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e, s) {
      log("❌ خطأ أثناء جلب الموظف: $e");
      log("StackTrace: $s");
      return null;
    }
  }

  Future<EmployeeModel?> loginEmployee(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      // 1) Fetch profile from Firestore by email.
      final query =
          await _employeeCollection
              .where("email", isEqualTo: normalizedEmail)
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        log("❌ loginEmployee: no employee record for $normalizedEmail");
        return null;
      }

      final doc = query.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      var employee = EmployeeModel.fromJson(data).copyWith(id: doc.id);

      // 2) Auth-first: sign in, and only allow first-time account activation when pending.
      final auth = FirebaseAuth.instance;
      final profileHasAuthUid =
          employee.authUid != null && employee.authUid!.trim().isNotEmpty;
      final authPendingOrNotActive =
          (employee.authStatus ?? 'pendingActivation') != 'active';

      final cred = await _signInOrLinkNewAuthUser(
        auth: auth,
        normalizedEmail: normalizedEmail,
        password: password,
        profileHasAuthUid: profileHasAuthUid,
        authPendingOrNotActive: authPendingOrNotActive,
      );

      final uid = cred.user?.uid;
      if (uid == null || uid.isEmpty) return null;

      if (employee.authUid != null &&
          employee.authUid!.isNotEmpty &&
          employee.authUid != uid) {
        log("❌ loginEmployee: authUid mismatch for ${employee.id}");
        throw StateError('AUTH_UID_MISMATCH');
      }

      await _updateAuthFieldsWithRetry(docRef: doc.reference, uid: uid);
      employee = employee.copyWith(authUid: uid, authStatus: 'active');
      return employee;
    } on FirebaseAuthException catch (e, s) {
      log(
        "❌ loginEmployee FirebaseAuthException code=${e.code}, message=${e.message}",
      );
      log("StackTrace: $s");
      throw StateError('FIREBASE_AUTH_${e.code.toUpperCase()}');
    } catch (e, s) {
      log("❌ loginEmployee error: $e\n$s");
      rethrow;
    }
  }

  /// إضافة حساب اختباري point@accountholder.app إن لم يكن موجوداً (للتطوير فقط).
  /// كلمة المرور تُمرّر عبر `--dart-define` في وضع التطوير فقط.
  static const String _kTestAccountholderEmail = 'point@accountholder.app';
  static const String _kTestAccountholderId = 'accountholder-test';

  String get _testAccountholderPassword => AppConfig.testAccountholderPassword;

  Future<void> ensureAccountholderTestUser() async {
    // Safety: never auto-create a test user unless explicitly enabled.
    if (!const bool.fromEnvironment(
      'ENABLE_TEST_ACCOUNTHOLDER',
      defaultValue: false,
    )) {
      return;
    }
    if (_testAccountholderPassword.isEmpty) {
      log(
        '⚠️ TEST_ACCOUNTHOLDER_PASSWORD غير معرّف — تخطي إنشاء الحساب الاختباري',
      );
      return;
    }
    try {
      final existing =
          await _employeeCollection
              .where("email", isEqualTo: _kTestAccountholderEmail)
              .limit(1)
              .get();
      if (existing.docs.isNotEmpty) {
        log("✅ حساب point@accountholder.app موجود مسبقاً");
        return;
      }
      final employee = EmployeeModel(
        id: _kTestAccountholderId,
        name: 'Point Test (Accountholder)',
        email: _kTestAccountholderEmail,
        phone: null,
        role: 'accountholder',
        department: null,
        fcmToken: null,
        onesignal: null,
        hireDate: null,
        status: 'active',
        createdAt: DateTime.now(),
        authStatus: 'active',
        image: null,
      );
      await _employeeCollection.doc(employee.id).set(employee.toJson());
      log(
        "✅ تم إضافة الحساب الاختباري point@accountholder.app إلى قاعدة البيانات",
      );

      // تأكد من وجود حساب مطابق في FirebaseAuth بنفس البريد وكلمة المرور.
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _kTestAccountholderEmail,
          password: _testAccountholderPassword,
        );
        log(
          '✅ FirebaseAuth session/creation successful for test accountholder',
        );
      } on FirebaseAuthException catch (e, s) {
        log(
          '❌ ensureAccountholderTestUser FirebaseAuthException code=${e.code}, message=${e.message}',
        );
        log('StackTrace: $s');
      } catch (e, s) {
        log('❌ ensureAccountholderTestUser unexpected error: $e');
        log('StackTrace: $s');
      }
      return;
    } catch (e) {
      log("❌ ensureAccountholderTestUser: $e");
      return;
    }
  }

  // 📡 قراءة كل الموظفين (Stream)
  Stream<List<EmployeeModel>> getEmployees() {
    try {
      return _employeeCollection.snapshots().map((snapshot) {
        return snapshot.docs.where((a) => a['role'] != 'accountholder').map((
          doc,
        ) {
          final raw = doc.data();
          final map = Map<String, dynamic>.from(raw as Map);
          return EmployeeModel.fromJson(map);
        }).toList();
      });
    } catch (e, s) {
      log("❌ خطأ أثناء جلب كل الموظفين: $e");
      log("StackTrace: $s");
      return const Stream.empty();
    }
  }

  final _clientCollection = FirebaseFirestore.instance.collection("clients");

  Future<bool> createClientWithAuth({
    required ClientModel client,
    required String password,
  }) async {
    final email = client.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      log('❌ createClientWithAuth: email is required');
      return false;
    }
    try {
      await _clientCollection
          .doc(client.id)
          .set(client.copyWith(authStatus: client.authStatus ?? 'pendingActivation').toJson());
      log("✅ createClientWithAuth: ${client.name}");
      return true;
    } catch (e, s) {
      log("❌ createClientWithAuth error: $e");
      log("StackTrace: $s");
      return false;
    }
  }

  Future<bool> updateClientWithAuth({
    required ClientModel existing,
    required ClientModel updated,
    String? newPassword,
  }) async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      final isEditingSelf =
          current != null &&
          existing.authUid != null &&
          existing.authUid == current.uid;

      final merged = updated.copyWith(
        email: isEditingSelf ? updated.email : existing.email,
        authUid: existing.authUid ?? updated.authUid,
        authStatus: existing.authStatus ?? updated.authStatus,
      );
      await _clientCollection.doc(merged.id).update(merged.toJson());

      if (newPassword != null &&
          newPassword.trim().isNotEmpty &&
          isEditingSelf) {
        try {
          await current.updatePassword(newPassword.trim());
        } on FirebaseAuthException catch (e) {
          log(
            "⚠️ updateClientWithAuth password update skipped: code=${e.code}, message=${e.message}",
          );
        }
      }
      log("✅ updateClientWithAuth (table-only): ${merged.id}");
      return true;
    } catch (e, s) {
      log("❌ updateClientWithAuth error: $e");
      log("StackTrace: $s");
      return false;
    }
  }

  Future<ClientModel?> loginClient(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      // 1) Fetch profile from Firestore by email.
      final query =
          await _clientCollection
              .where("email", isEqualTo: normalizedEmail)
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        log("❌ loginClient: no client record for $normalizedEmail");
        return null;
      }

      final doc = query.docs.first;
      final data = doc.data();
      var client = ClientModel.fromJson(data, doc.id);

      // 2) Auth-first: sign in, and allow activation by owner on first login.
      final auth = FirebaseAuth.instance;
      final profileHasAuthUid =
          client.authUid != null && client.authUid!.trim().isNotEmpty;
      final authPendingOrNotActive =
          (client.authStatus ?? 'pendingActivation') != 'active';

      final cred = await _signInOrLinkNewAuthUser(
        auth: auth,
        normalizedEmail: normalizedEmail,
        password: password,
        profileHasAuthUid: profileHasAuthUid,
        authPendingOrNotActive: authPendingOrNotActive,
      );

      final uid = cred.user?.uid;
      if (uid == null || uid.isEmpty) return null;

      if (client.authUid != null &&
          client.authUid!.isNotEmpty &&
          client.authUid != uid) {
        log("❌ loginClient: authUid mismatch for ${client.id}");
        return null;
      }

      await _updateAuthFieldsWithRetry(docRef: doc.reference, uid: uid);
      client = client.copyWith(authUid: uid, authStatus: 'active');
      return client;
    } on FirebaseAuthException catch (e, s) {
      log(
        "❌ loginClient FirebaseAuthException code=${e.code}, message=${e.message}",
      );
      log("StackTrace: $s");
      return null;
    } catch (e, s) {
      log("❌ loginClient error: $e\n$s");
      return null;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-email');
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(email: normalizedEmail);
  }

  Future<void> changeCurrentUserPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    final credential = EmailAuthProvider.credential(
      email: currentUser.email!.trim().toLowerCase(),
      password: currentPassword,
    );
    await currentUser.reauthenticateWithCredential(credential);
    await currentUser.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<EmployeeModel?> getCurrentEmployeeByAuth() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return null;
    final uid = current.uid;
    final byUid =
        await _employeeCollection.where('authUid', isEqualTo: uid).limit(1).get();
    if (byUid.docs.isNotEmpty) {
      final doc = byUid.docs.first;
      return EmployeeModel.fromJson(doc.data() as Map<String, dynamic>).copyWith(
        id: doc.id,
      );
    }
    final email = current.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;
    final byEmail =
        await _employeeCollection.where('email', isEqualTo: email).limit(1).get();
    if (byEmail.docs.isEmpty) return null;
    final doc = byEmail.docs.first;
    await _employeeCollection.doc(doc.id).update({
      'authUid': uid,
      'authStatus': 'active',
    });
    return EmployeeModel.fromJson(doc.data() as Map<String, dynamic>).copyWith(
      id: doc.id,
      authUid: uid,
      authStatus: 'active',
    );
  }

  Future<ClientModel?> getCurrentClientByAuth() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return null;
    final uid = current.uid;
    final byUid =
        await _clientCollection.where('authUid', isEqualTo: uid).limit(1).get();
    if (byUid.docs.isNotEmpty) {
      final doc = byUid.docs.first;
      return ClientModel.fromJson(doc.data(), doc.id);
    }
    final email = current.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;
    final byEmail =
        await _clientCollection.where('email', isEqualTo: email).limit(1).get();
    if (byEmail.docs.isEmpty) return null;
    final doc = byEmail.docs.first;
    await _clientCollection.doc(doc.id).update({
      'authUid': uid,
      'authStatus': 'active',
    });
    return ClientModel.fromJson(doc.data(), doc.id).copyWith(
      authUid: uid,
      authStatus: 'active',
    );
  }

  Future<bool> addClient(ClientModel client) async {
    try {
      await _clientCollection.doc(client.id).set(client.toJson());
      return true;
    } catch (e, s) {
      log("❌ addClient error: $e\n$s");
      return false;
    }
  }

  Future<bool> updateClient(ClientModel client) async {
    try {
      if (client.id == null) return false;
      await _clientCollection.doc(client.id).update(client.toJson());
      return true;
    } catch (e, s) {
      log("❌ updateClient error: $e\n$s");
      return false;
    }
  }

  Future<bool> deleteClient(String id) async {
    try {
      await _clientCollection.doc(id).delete();
      return true;
    } catch (e, s) {
      log("❌ deleteClient error: $e\n$s");
      return false;
    }
  }

  Stream<List<ClientModel>> getClientsStream() {
    return _clientCollection
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ClientModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  final _db = FirebaseFirestore.instance.collection("contents");

  Future<bool> addContent(ContentModel content) async {
    try {
      final docRef = _db.doc(); // auto id
      await docRef.set(content.copyWith(id: docRef.id).toJson());
      return true;
    } catch (e) {
      log("❌ Error addContent: $e");
      return false;
    }
  }

  Future<bool> updateContent(ContentModel content) async {
    try {
      if (content.id == null) throw Exception("id is null");
      await _db.doc(content.id).update(content.toJson());
      return true;
    } catch (e) {
      log("❌ Error updateContent: $e");
      return false;
    }
  }

  Future<bool> deleteContent(String id) async {
    try {
      await _db.doc(id).delete();
      return true;
    } catch (e) {
      log("❌ Error deleteContent: $e");
      return false;
    }
  }

  Stream<List<ContentModel>> getContents() {
    return _db
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ContentModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  Stream<List<ContentModel>> getContentsForClient(clientId) {
    return _db
        .where('clientId', isEqualTo: clientId)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ContentModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  final _dbtask = FirebaseFirestore.instance.collection("tasks");

  Future<bool> addTask(TaskModel task) async {
    try {
      final docRef = _dbtask.doc(); // auto id
      await docRef.set(task.copyWith(id: docRef.id).toJson());
      return true;
    } catch (e) {
      log("❌ Error addTask: $e");
      return false;
    }
  }

  Future<bool> updateTask(TaskModel task) async {
    try {
      if (task.id == null) throw Exception("id is null");
      await _dbtask.doc(task.id).update(task.toJson());
      return true;
    } catch (e) {
      log("❌ Error updateTask: $e");
      return false;
    }
  }

  Future<bool> deleteTask(String id) async {
    try {
      await _dbtask.doc(id).delete();
      return true;
    } catch (e) {
      log("❌ Error deleteTask: $e");
      return false;
    }
  }

  Stream<List<TaskModel>> getTasks() {
    return _dbtask.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => TaskModel.fromJson(doc.data())).toList(),
    );
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return db
        .collection('chats/$chatId/messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((e) => MessageModel.fromJson(e.data()))
                  .toList(),
        );
  }

  Future<void> sendMessage(String chatId, MessageModel message) async {
    await db
        .collection('chats/$chatId/messages')
        .doc(message.id)
        .set(message.toJson());
  }

  static Future<void> addNotification(NotificationModel model) async {
    final data = Map<String, dynamic>.from(model.toJson())..remove('id');
    data['isRead'] = model.isRead ?? false;
    await FirebaseFirestore.instance.collection('notifications').add(data);
  }

  /// يضع [isRead] = true لمجموعة مستندات الإشعارات (دُفعات 450 لتفادي حد الـ batch).
  static Future<void> markInAppNotificationsAsRead(
    Iterable<String> docIds,
  ) async {
    final ids = docIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return;
    final coll = FirebaseFirestore.instance.collection('notifications');
    const chunkSize = 450;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in ids.skip(i).take(chunkSize)) {
        batch.update(coll.doc(id), {'isRead': true});
      }
      await batch.commit();
    }
  }

  /// Delete in-app notifications by Firestore document ids.
  ///
  /// Uses chunking to stay under Firestore batch limits.
  static Future<void> deleteInAppNotifications(
    Iterable<String> docIds,
  ) async {
    final ids = docIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return;
    final coll = FirebaseFirestore.instance.collection('notifications');
    const chunkSize = 450;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in ids.skip(i).take(chunkSize)) {
        batch.delete(coll.doc(id));
      }
      await batch.commit();
    }
  }

  /// Stream of total unread messages count across all chats for [userId].
  /// Updates in real time when chats or messages change.
  ///
  /// [onPerChatUnreadIncrease] يُستدعى عندما يرتفع عدد غير المقروء من الطرف الآخر
  /// في محادثة معيّنة (بعد تجاهل أول emission لكل اشتراك لتفادي الطنين عند إعادة الربط).
  Stream<int> getTotalUnreadMessagesStream(
    String userId, {
    void Function(String chatId)? onPerChatUnreadIncrease,
  }) {
    final controller = StreamController<int>.broadcast();
    controller.add(0);
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? chatsSub;
    final Map<String, StreamSubscription<int>> unreadSubs = {};

    void cancelUnreadSubs() {
      for (final sub in unreadSubs.values) {
        sub.cancel();
      }
      unreadSubs.clear();
    }

    void onChatsUpdate(QuerySnapshot<Map<String, dynamic>> chatsSnapshot) {
      cancelUnreadSubs();
      final chatIds = chatsSnapshot.docs.map((d) => d.id).toList();
      final counts = <String, int>{};
      for (final id in chatIds) {
        counts[id] = 0;
      }
      final unreadFirstDone = <String, bool>{};

      void emitTotal() {
        controller.add(counts.values.fold<int>(0, (a, b) => a + b));
      }

      if (chatIds.isEmpty) {
        controller.add(0);
        return;
      }

      for (final chatId in chatIds) {
        final unreadStream = db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .snapshots()
            .map(
              (s) => s.docs.where((d) => d.data()['senderId'] != userId).length,
            );
        unreadSubs[chatId] = unreadStream.listen(
          (count) {
            if (unreadFirstDone[chatId] != true) {
              unreadFirstDone[chatId] = true;
              counts[chatId] = count;
              emitTotal();
              return;
            }
            final previous = counts[chatId] ?? 0;
            counts[chatId] = count;
            if (count > previous) {
              onPerChatUnreadIncrease?.call(chatId);
            }
            emitTotal();
          },
          onError: controller.addError,
          cancelOnError: false,
        );
      }
    }

    chatsSub = db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen(onChatsUpdate, onError: controller.addError);

    controller.onCancel = () {
      chatsSub?.cancel();
      cancelUnreadSubs();
    };

    return controller.stream;
  }

  Stream<List<NotificationModel>> getNotifications(
    String userId,
    String otherId,
  ) async* {
    while (true) {
      try {
        await for (final snapshot
            in FirebaseFirestore.instance
                .collection('notifications')
                .where('recipientId', whereIn: [userId, otherId])
                .orderBy('createdAt', descending: true)
                .snapshots()) {
          yield snapshot.docs
              .map(
                (doc) => NotificationModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList();
        }
      } catch (e) {
        // الفهرس قد يكون قيد البناء (failed-precondition) — نعرض قائمة فارغة ونعيد المحاولة لاحقاً
        log("⚠️ getNotifications (index may be building): $e");
        yield [];
        await Future<void>.delayed(const Duration(seconds: 15));
      }
    }
  }

  static Future<void> sendFcm({
    required String userId,
    required String title,
    required String body,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
    bool sendPush = true,
    bool sendEmail = true,
  }) async {
    try {
      // 1. هات بيانات المستخدم من Firestore
      final doc =
          await FirebaseFirestore.instance
              .collection("employees")
              .doc(userId.trim())
              .get();

      if (!doc.exists) {
        log("⚠️ Employee not found: $userId");
        return;
      }

      final data = doc.data();
      final email = data?['email']?.toString().trim();
      final token = data?['fcmToken']?.toString();
      final rawRecipientName = data?['name']?.toString().trim();
      final recipientName =
          (rawRecipientName != null && rawRecipientName.isNotEmpty)
              ? rawRecipientName
              : 'الموظف';

      final trimmedUserId = userId.trim();
      await addNotification(
        NotificationModel(
          title: title,
          body: body,
          recipientId: trimmedUserId,
          createdAt: DateTime.now(),
          isRead: false,
        ),
      );

      // إرسال بريد (اختياري حسب اختيار القناة)
      if (sendEmail) {
        // إرسال إيميل حتى عند غياب FCM (من لم يثبت التطبيق أو عطّل الإشعارات يظل يحصل على الإيميل)
        if (email != null && email.isNotEmpty) {
          final details = <String, String>{
            'المستلم': recipientName,
            'معرف المستلم': trimmedUserId,
            if (emailDetails != null) ...emailDetails,
          };
          unawaited(
            EmailNotificationService.sendDetailedNotification(
              toEmail: email,
              title: title,
              body: body,
              recipientLabel: recipientName,
              notificationType: notificationType ?? 'إشعار موظف',
              actionText: actionText,
              referenceId: referenceId ?? trimmedUserId,
              details: details,
            ),
          );
        } else {
          log(
            "⚠️ Email missing for employee $userId — skipping email notification",
          );
        }
      }

      // إذا المستخدم لا يريد Push، ننهي بدون فحص token أو إرسال push.
      if (!sendPush) return;

      if (token == null || token.isEmpty) {
        log("⚠️ fcmToken missing for employee $userId — push not sent");
        return;
      }

      await _sendFcmViaFunction(
        token: token,
        title: title,
        body: body,
        data: <String, String>{
          'type': 'internal',
          'id': trimmedUserId,
          'url': 'https://example.com',
        },
      );
      log("✅ FCM Response: $userId");
    } catch (e) {
      log("❌ FCM Error: $e");
    }
  }

  static Future<void> sendFcmForClient({
    required String userId,
    required String title,
    required String body,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
  }) async {
    try {
      // 1. هات بيانات المستخدم من Firestore
      final doc =
          await FirebaseFirestore.instance
              .collection("clients")
              .doc(userId)
              .get();

      if (!doc.exists) {
        log("⚠️ Client not found: $userId");
        return;
      }

      final data = doc.data();
      final email = data?['email']?.toString().trim();
      final token = data?['fcmToken']?.toString();
      final rawRecipientName = data?['name']?.toString().trim();
      final recipientName =
          (rawRecipientName != null && rawRecipientName.isNotEmpty)
              ? rawRecipientName
              : 'العميل';

      final trimmedUserId = userId.trim();
      await addNotification(
        NotificationModel(
          title: title,
          body: body,
          recipientId: trimmedUserId,
          createdAt: DateTime.now(),
          isRead: false,
        ),
      );

      // إرسال إيميل حتى عند غياب FCM (من لم يثبت التطبيق أو عطّل الإشعارات يظل يحصل على الإيميل)
      if (email != null && email.isNotEmpty) {
        final details = <String, String>{
          'المستلم': recipientName,
          'معرف المستلم': trimmedUserId,
          if (emailDetails != null) ...emailDetails,
        };
        unawaited(
          EmailNotificationService.sendDetailedNotification(
            toEmail: email,
            title: title,
            body: body,
            recipientLabel: recipientName,
            notificationType: notificationType ?? 'إشعار عميل',
            actionText: actionText,
            referenceId: referenceId ?? trimmedUserId,
            details: details,
          ),
        );
      } else {
        log(
          "⚠️ Email missing for client $userId — skipping email notification",
        );
      }

      if (token == null || token.isEmpty) {
        log("⚠️ fcmToken missing for client $userId — push not sent");
        return;
      }

      await _sendFcmViaFunction(
        token: token,
        title: title,
        body: body,
        data: <String, String>{
          'type': 'internal',
          'id': trimmedUserId,
          'url': 'https://example.com',
        },
      );
      log("✅ FCM sent to client: $userId");
    } catch (e) {
      log("❌ FCM Error: $e");
    }
  }

  static Future<void> sendFcmTopic({
    required String topic,
    required String title,
    required String body,
    required String scheduledAt,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
    bool sendPush = true,
    bool sendEmail = true,
  }) async {
    try {
      if (sendPush) {
        await _sendFcmViaFunction(topic: topic, title: title, body: body);
        log("✅ FCM topic sent: $topic");
      }

      if (sendEmail) {
        // إرسال إيميل إشعار لجميع المستلمين في الـ topic (بدون انتظار)
        unawaited(
          _sendEmailForTopic(
            topic,
            title,
            body,
            notificationType: notificationType,
            actionText: actionText,
            referenceId: referenceId,
            emailDetails: <String, String>{
              'الموضوع': topic,
              'موعد الإرسال المجدول': scheduledAt,
              if (emailDetails != null) ...emailDetails,
            },
          ),
        );
      }
    } catch (e) {
      log("❌ FCM Error: $e");
    }
  }

  /// يجلب عناوين البريد حسب الـ topic ويرسل إشعاراً لكل واحد.
  static Future<void> _sendEmailForTopic(
    String topic,
    String title,
    String body, {
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
  }) async {
    try {
      final emails = <String>[];
      int skippedEmployees = 0;
      int skippedClients = 0;

      if (topic == 'employees' || topic == 'all') {
        final snap =
            await FirebaseFirestore.instance.collection('employees').get();
        for (final doc in snap.docs) {
          final email = doc.data()['email']?.toString().trim();
          if (email != null && email.isNotEmpty) {
            emails.add(email);
          } else {
            skippedEmployees++;
          }
        }
      }
      if (topic == 'clients' || topic == 'all') {
        final snap =
            await FirebaseFirestore.instance.collection('clients').get();
        for (final doc in snap.docs) {
          final email = doc.data()['email']?.toString().trim();
          if (email != null && email.isNotEmpty) {
            emails.add(email);
          } else {
            skippedClients++;
          }
        }
      }

      if (skippedEmployees > 0 || skippedClients > 0) {
        log(
          "⚠️ Topic $topic: skipped email for $skippedEmployees employee(s), $skippedClients client(s) with no email",
        );
      }

      for (final email in emails) {
        final details = <String, String>{
          'الوجهة': 'إشعار جماعي',
          'الموضوع': topic,
          if (emailDetails != null) ...emailDetails,
        };
        unawaited(
          EmailNotificationService.sendDetailedNotification(
            toEmail: email,
            title: title,
            body: body,
            notificationType: notificationType ?? 'إشعار جماعي',
            actionText: actionText,
            referenceId: referenceId,
            details: details,
          ),
        );
      }
    } catch (e) {
      log("❌ Email for topic error: $e");
    }
  }

  /// جلب معرفات الموظفين حسب الأدوار (مثل admin, supervisor).
  /// يستخدم whereIn (حد أقصى 10 قيم في الاستعلام).
  static Future<List<String>> getEmployeeIdsByRole(List<String> roles) async {
    if (roles.isEmpty) return [];
    try {
      final list = roles.take(10).toList();
      final snap =
          await FirebaseFirestore.instance
              .collection('employees')
              .where('role', whereIn: list)
              .get();
      return snap.docs.map((d) => d.id).where((id) => id.isNotEmpty).toList();
    } catch (e) {
      log("❌ getEmployeeIdsByRole: $e");
      return [];
    }
  }

  /// جلب معرفات الموظفين حسب القسم (مثل cat6 للنشر، cat1 للترويج).
  static Future<List<String>> getEmployeeIdsByDepartment(
    String department,
  ) async {
    if (department.isEmpty) return [];
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('employees')
              .where('department', isEqualTo: department)
              .get();
      return snap.docs.map((d) => d.id).where((id) => id.isNotEmpty).toList();
    } catch (e) {
      log("❌ getEmployeeIdsByDepartment: $e");
      return [];
    }
  }

  /// إرسال إشعار FCM (وإيميل + حفظ في notifications) لعدة موظفين بدون تكرار.
  static Future<void> sendFcmToEmployees({
    required List<String> userIds,
    required String title,
    required String body,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
  }) async {
    final seen = <String>{};
    for (final id in userIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      unawaited(
        sendFcm(
          userId: trimmed,
          title: title,
          body: body,
          notificationType: notificationType,
          actionText: actionText,
          referenceId: referenceId,
          emailDetails: emailDetails,
        ),
      );
    }
  }
}
