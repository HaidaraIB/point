import 'dart:async';
import 'dart:developer';
import 'dart:math' show Random;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Models/ChatMetaData.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/EmailNotificationService.dart';
import 'package:point/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmSendException implements Exception {
  final int? status;
  final String? errorCode;
  final Object? details;
  final String? fcmErrorStatus;
  final String? fcmErrorMessage;

  const FcmSendException({
    this.status,
    this.errorCode,
    this.details,
    this.fcmErrorStatus,
    this.fcmErrorMessage,
  });

  @override
  String toString() =>
      'FcmSendException(status: $status, code: $errorCode, fcmStatus: $fcmErrorStatus, details: $details)';
}

class FirestoreServices {
  static final Random _random = Random();

  /// يمنع تسرب أخطاء `permission-denied` إلى [Rx.bindStream] / الـ zone بعد تسجيل الخروج.
  static Stream<List<T>> _safeFirestoreListStream<T>(
    Stream<List<T>> source,
    String label,
  ) {
    return source.transform(
      StreamTransformer<List<T>, List<T>>.fromHandlers(
        handleError: (Object error, StackTrace stackTrace, EventSink<List<T>> sink) {
          if (FirebaseAuth.instance.currentUser == null) {
            sink.add(<T>[]);
            return;
          }
          final msg = error.toString();
          if (msg.contains('permission-denied')) {
            sink.add(<T>[]);
            return;
          }
          log('⚠️ Firestore stream [$label]: $error');
          sink.add(<T>[]);
        },
      ),
    );
  }

  static String _newPushRequestId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(1 << 20).toRadixString(16);
    return 'push_$ms$rand';
  }

  static String _maskFcmToken(String t) {
    if (t.length <= 12) return '***';
    return '${t.substring(0, 6)}...${t.substring(t.length - 4)}';
  }

  static Future<void> _logPushDiagnostic({
    required String requestId,
    required String stage,
    required String status,
    required String targetType,
    String? recipientId,
    String? recipientType,
    String? tokenMasked,
    String? topic,
    String? title,
    int? bodyLen,
    String? notificationType,
    int? fcmHttpStatus,
    String? fcmErrorCode,
    String? fcmErrorStatus,
    String? fcmErrorMessage,
    Object? details,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('push_diagnostics').add({
        'createdAt': FieldValue.serverTimestamp(),
        'requestId': requestId,
        'stage': stage,
        'status': status,
        'targetType': targetType,
        'senderUid': currentUser?.uid,
        'recipientId': recipientId,
        'recipientType': recipientType,
        'tokenMasked': tokenMasked,
        'topic': topic,
        'title': title,
        'bodyLen': bodyLen ?? 0,
        'notificationType': notificationType,
        'fcmHttpStatus': fcmHttpStatus,
        'fcmErrorCode': fcmErrorCode,
        'fcmErrorStatus': fcmErrorStatus,
        'fcmErrorMessage': fcmErrorMessage,
        if (details != null) 'details': details.toString(),
        'source': 'flutter_app',
      });
    } catch (_) {
      // Keep diagnostics non-blocking.
    }
  }

  static List<String> _extractFcmTokens(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final tokens = <String>{};
    final rawList = data['fcmTokens'];
    if (rawList is List) {
      for (final raw in rawList) {
        final token = raw?.toString().trim() ?? '';
        if (token.isNotEmpty) tokens.add(token);
      }
    }
    final singleToken = data['fcmToken']?.toString().trim() ?? '';
    if (singleToken.isNotEmpty) tokens.add(singleToken);
    return tokens.toList();
  }

  static bool _isInvalidOrExpiredTokenError(Object error) {
    if (error is FcmSendException) {
      final details = (error.details?.toString() ?? '').toLowerCase();
      final fcmStatus = (error.fcmErrorStatus ?? '').toLowerCase();
      final fcmMessage = (error.fcmErrorMessage ?? '').toLowerCase();
      final combined = '$details $fcmStatus $fcmMessage';
      return combined.contains('registration-token-not-registered') ||
          combined.contains('invalid-registration-token') ||
          combined.contains('invalid_argument') ||
          combined.contains('unregistered') ||
          combined.contains('not registered') ||
          combined.contains('token-not-registered');
    }
    if (error is FunctionException) {
      return _fcmPayloadImpliesInvalidToken(error.details);
    }
    return false;
  }

  static bool _fcmPayloadImpliesInvalidToken(Object? details) {
    final s = details?.toString().toLowerCase() ?? '';
    return s.contains('unregistered') ||
        s.contains('registration-token-not-registered') ||
        s.contains('invalid-registration-token') ||
        s.contains('invalid_argument') ||
        s.contains('not registered') ||
        s.contains('token-not-registered');
  }

  /// When Supabase `functions.invoke` gets a non-2xx response it throws
  /// [FunctionException] instead of returning [FunctionResponse], so FCM errors
  /// must be normalized to [FcmSendException] for callers and token cleanup.
  static FcmSendException _fcmSendExceptionFromFunctionException(
    FunctionException e,
  ) {
    final responseData = _normalizeDetailsMap(e.details);
    final code = responseData?['errorCode']?.toString();
    final nestedDetails = responseData?['details'];
    Map<String, dynamic>? fcmError;
    final nestedMap = _normalizeDetailsMap(nestedDetails);
    if (nestedMap != null) {
      fcmError = _normalizeDetailsMap(nestedMap['error']);
    }
    return FcmSendException(
      status: e.status,
      errorCode: code,
      details: nestedDetails ?? responseData,
      fcmErrorStatus: fcmError?['status']?.toString(),
      fcmErrorMessage: fcmError?['message']?.toString(),
    );
  }

  static Map<String, dynamic>? _normalizeDetailsMap(Object? value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, dynamic v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static Future<void> addEmployeeFcmToken({
    required String employeeId,
    required String token,
  }) async {
    final cleanedId = employeeId.trim();
    final cleanedToken = token.trim();
    if (cleanedId.isEmpty || cleanedToken.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('employees')
        .doc(cleanedId)
        .update({
          'fcmToken': cleanedToken,
          'fcmTokens': FieldValue.arrayUnion([cleanedToken]),
        });
  }

  static Future<void> addClientFcmToken({
    required String clientId,
    required String token,
  }) async {
    final cleanedId = clientId.trim();
    final cleanedToken = token.trim();
    if (cleanedId.isEmpty || cleanedToken.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('clients')
        .doc(cleanedId)
        .update({
          'fcmToken': cleanedToken,
          'fcmTokens': FieldValue.arrayUnion([cleanedToken]),
        });
  }

  static Future<void> _removeEmployeeFcmToken({
    required String employeeId,
    required String token,
  }) async {
    final cleanedId = employeeId.trim();
    final cleanedToken = token.trim();
    if (cleanedId.isEmpty || cleanedToken.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('employees')
        .doc(cleanedId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data();
    final currentSingle = data?['fcmToken']?.toString().trim() ?? '';
    await ref.update({
      'fcmTokens': FieldValue.arrayRemove([cleanedToken]),
      if (currentSingle == cleanedToken) 'fcmToken': null,
    });
  }

  static Future<void> _removeClientFcmToken({
    required String clientId,
    required String token,
  }) async {
    final cleanedId = clientId.trim();
    final cleanedToken = token.trim();
    if (cleanedId.isEmpty || cleanedToken.isEmpty) return;
    final ref = FirebaseFirestore.instance.collection('clients').doc(cleanedId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data();
    final currentSingle = data?['fcmToken']?.toString().trim() ?? '';
    await ref.update({
      'fcmTokens': FieldValue.arrayRemove([cleanedToken]),
      if (currentSingle == cleanedToken) 'fcmToken': null,
    });
  }

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

  Future<void> _updateAuthFieldsWithRetry({
    required DocumentReference docRef,
    required String uid,
  }) async {
    // On web, Firestore request auth context may lag briefly right after
    // signIn/createUser; wait until FirebaseAuth is fully hydrated.
    const hydrationMaxAttempts = 20;
    for (var i = 0; i < hydrationMaxAttempts; i++) {
      final cu = FirebaseAuth.instance.currentUser;
      if (cu != null && cu.uid == uid) {
        try {
          await cu.getIdToken();
          break;
        } catch (_) {
          // keep retrying until token is ready
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

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
    required String requestId,
    String? recipientId,
    String? recipientType,
    String? notificationType,
  }) async {
    final targetLabel =
        token != null
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

    try {
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
          'requestId': requestId,
          if (recipientId != null) 'recipientId': recipientId,
          if (recipientType != null) 'recipientType': recipientType,
          if (notificationType != null) 'notificationType': notificationType,
        },
      );

      log(
        '✅ FCM invoke success. target=$targetLabel status=${res.status} data=${res.data}',
      );
    } on FunctionException catch (e) {
      final ex = _fcmSendExceptionFromFunctionException(e);
      log(
        '❌ FCM invoke failed. target=$targetLabel status=${ex.status} errorCode=${ex.errorCode} details=${ex.details}',
      );
      throw ex;
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
            normalizedEmployee
                .copyWith(
                  authStatus:
                      normalizedEmployee.authStatus ?? 'pendingActivation',
                )
                .toJson(),
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
      await FirestoreServices.syncAuthRoleForEmployee(employee);
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

  /// إضافة حساب اختباري point@admin.app بدور admin إن لم يكن موجوداً (للتطوير فقط).
  /// كلمة المرور تُمرّر عبر `--dart-define=TEST_ADMIN_PASSWORD` في وضع التطوير فقط.
  static const String _kTestAdminDevEmail = 'point@admin.app';
  static const String _kTestAdminDevId = 'admin-test';

  String get _testAdminDevPassword => AppConfig.testAdminPassword;

  Future<void> ensureTestAdminUser() async {
    // Safety: never auto-create a test user unless explicitly enabled.
    if (!const bool.fromEnvironment('ENABLE_TEST_ADMIN', defaultValue: false)) {
      return;
    }
    if (_testAdminDevPassword.isEmpty) {
      log('⚠️ TEST_ADMIN_PASSWORD غير معرّف — تخطي إنشاء الحساب الاختباري');
      return;
    }
    try {
      final existing =
          await _employeeCollection
              .where("email", isEqualTo: _kTestAdminDevEmail)
              .limit(1)
              .get();
      if (existing.docs.isNotEmpty) {
        log("✅ حساب $_kTestAdminDevEmail موجود مسبقاً");
        return;
      }
      final employee = EmployeeModel(
        id: _kTestAdminDevId,
        name: 'Point Test (Admin)',
        email: _kTestAdminDevEmail,
        phone: null,
        role: 'admin',
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
        "✅ تم إضافة الحساب الاختباري $_kTestAdminDevEmail إلى قاعدة البيانات (admin)",
      );

      // تأكد من وجود حساب مطابق في FirebaseAuth بنفس البريد وكلمة المرور.
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _kTestAdminDevEmail,
          password: _testAdminDevPassword,
        );
        log('✅ FirebaseAuth session/creation successful for test admin');
      } on FirebaseAuthException catch (e, s) {
        log(
          '❌ ensureTestAdminUser FirebaseAuthException code=${e.code}, message=${e.message}',
        );
        log('StackTrace: $s');
      } catch (e, s) {
        log('❌ ensureTestAdminUser unexpected error: $e');
        log('StackTrace: $s');
      }
      return;
    } catch (e) {
      log("❌ ensureTestAdminUser: $e");
      return;
    }
  }

  // 📡 قراءة كل الموظفين (Stream) — يشمل admin وsupervisor وemployee.
  Stream<List<EmployeeModel>> getEmployees() {
    try {
      return _safeFirestoreListStream(
        _employeeCollection.snapshots().map((snapshot) {
          return snapshot.docs.map((doc) {
            final raw = doc.data();
            final map = Map<String, dynamic>.from(raw as Map);
            return EmployeeModel.fromJson(map);
          }).toList();
        }),
        'employees',
      );
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
          .set(
            client
                .copyWith(authStatus: client.authStatus ?? 'pendingActivation')
                .toJson(),
          );
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
      // جلسة Firebase قديمة (بدون authRoles مناسب) ترفض قراءة clients — نبدأ من دون مستخدم.
      await FirebaseAuth.instance.signOut();

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
      await FirestoreServices.syncAuthRoleForClient(client);
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
    try {
      await _removeCurrentDeviceFcmToken();
    } catch (e) {
      log("⚠️ signOut: FCM cleanup failed (ignored): $e");
    }
    await FirebaseAuth.instance.signOut();
  }

  /// يزيل توكن الجهاز من [fcmToken]/[fcmTokens] فقط (متوافق مع قواعد Firestore).
  Future<void> _stripFcmTokenFromUserDoc(
    DocumentReference ref,
    String cleanedToken,
  ) async {
    final snap = await ref.get();
    if (!snap.exists) return;
    final raw = snap.data();
    final m = raw is Map<String, dynamic> ? raw : null;
    final currentSingle = m?['fcmToken']?.toString().trim() ?? '';
    await ref.update({
      'fcmTokens': FieldValue.arrayRemove([cleanedToken]),
      if (currentSingle == cleanedToken) 'fcmToken': null,
    });
  }

  /// بدون authRoles: استعلام authUid (قد يفشل التحديث إن لم يطابق documentId الـ employeeId في القواعد).
  Future<void> _removeCurrentDeviceFcmTokenLegacyQuery(
    String authUid,
    String cleanedToken,
  ) async {
    final employeeSnap =
        await _employeeCollection
            .where('authUid', isEqualTo: authUid)
            .limit(1)
            .get();
    if (employeeSnap.docs.isNotEmpty) {
      await _stripFcmTokenFromUserDoc(
        employeeSnap.docs.first.reference,
        cleanedToken,
      );
    }

    final clientSnap =
        await _clientCollection
            .where('authUid', isEqualTo: authUid)
            .limit(1)
            .get();
    if (clientSnap.docs.isNotEmpty) {
      await _stripFcmTokenFromUserDoc(
        clientSnap.docs.first.reference,
        cleanedToken,
      );
    }
  }

  Future<void> _removeCurrentDeviceFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      final cleanedToken = token?.trim() ?? '';
      if (cleanedToken.isEmpty) return;

      // تحديث الموظف مسموح فقط على employees/{myEmployeeId} — نقرأ المعرف من authRoles.
      final roleSnap =
          await FirebaseFirestore.instance
              .collection(authRolesCollection)
              .doc(user.uid)
              .get();

      if (roleSnap.exists && roleSnap.data() != null) {
        final rd = roleSnap.data()!;
        final role = rd['role']?.toString();
        final employeeId = rd['employeeId']?.toString().trim();
        final clientId = rd['clientId']?.toString().trim();

        if (role == 'client' && clientId != null && clientId.isNotEmpty) {
          await _stripFcmTokenFromUserDoc(
            _clientCollection.doc(clientId),
            cleanedToken,
          );
          return;
        }
        if (employeeId != null && employeeId.isNotEmpty) {
          await _stripFcmTokenFromUserDoc(
            _employeeCollection.doc(employeeId),
            cleanedToken,
          );
          return;
        }
      }

      await _removeCurrentDeviceFcmTokenLegacyQuery(user.uid, cleanedToken);
    } catch (e) {
      log("⚠️ remove current device token before signOut failed: $e");
    }
  }

  Future<EmployeeModel?> getCurrentEmployeeByAuth() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return null;
    final uid = current.uid;
    final byUid =
        await _employeeCollection
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();
    if (byUid.docs.isNotEmpty) {
      final doc = byUid.docs.first;
      final emp = EmployeeModel.fromJson(
        doc.data() as Map<String, dynamic>,
      ).copyWith(id: doc.id);
      await FirestoreServices.syncAuthRoleForEmployee(emp);
      return emp;
    }
    final email = current.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;
    final byEmail =
        await _employeeCollection
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
    if (byEmail.docs.isEmpty) return null;
    final doc = byEmail.docs.first;
    await _employeeCollection.doc(doc.id).update({
      'authUid': uid,
      'authStatus': 'active',
    });
    final restored = EmployeeModel.fromJson(
      doc.data() as Map<String, dynamic>,
    ).copyWith(id: doc.id, authUid: uid, authStatus: 'active');
    await FirestoreServices.syncAuthRoleForEmployee(restored);
    return restored;
  }

  Future<ClientModel?> getCurrentClientByAuth() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return null;
    final uid = current.uid;
    final email = current.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;

    // استعلام بالبريد فقط: قواعد Firestore تسمح بـ canReadClientsDoc عندما يطابق
    // المستند request.auth.token.email. استعلام authUid أولاً يُرفض كاملاً قبل وجود authRoles.
    final byEmail =
        await _clientCollection.where('email', isEqualTo: email).limit(1).get();
    if (byEmail.docs.isEmpty) return null;

    final doc = byEmail.docs.first;
    var client = ClientModel.fromJson(doc.data(), doc.id);

    if (client.authUid != null &&
        client.authUid!.trim().isNotEmpty &&
        client.authUid != uid) {
      return null;
    }

    if (client.authUid == uid) {
      await FirestoreServices.syncAuthRoleForClient(client);
      return client;
    }

    await _updateAuthFieldsWithRetry(docRef: doc.reference, uid: uid);
    final restored =
        client.copyWith(authUid: uid, authStatus: 'active');
    await FirestoreServices.syncAuthRoleForClient(restored);
    return restored;
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
    return _safeFirestoreListStream(
      _clientCollection
          .orderBy("createdAt", descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => ClientModel.fromJson(doc.data(), doc.id))
                    .toList(),
          ),
      'clients',
    );
  }

  /// للعميل بعد تسجيل الدخول: لا يقرأ إلا مستنده (استعلام بالبريد يتوافق مع canReadClientsDoc + JWT).
  Stream<List<ClientModel>> getClientsStreamForCurrentAuthEmail() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream<List<ClientModel>>.value(const <ClientModel>[]);
    }
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return Stream<List<ClientModel>>.value(const <ClientModel>[]);
    }
    return _safeFirestoreListStream(
      _clientCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => ClientModel.fromJson(doc.data(), doc.id))
                    .toList(),
          ),
      'clientsForEmail',
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

  /// تحديث حقل الترويج فقط — يتوافق مع قواعد موظف الترويج في Firestore.
  Future<bool> updateContentPromotionField(String contentId, String promotion) async {
    try {
      await _db.doc(contentId).update({'promotion': promotion});
      return true;
    } catch (e) {
      log("❌ Error updateContentPromotionField: $e");
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
    return _safeFirestoreListStream(
      _db
          .orderBy("createdAt", descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => ContentModel.fromJson(doc.data(), doc.id))
                    .toList(),
          ),
      'contents',
    );
  }

  Stream<List<ContentModel>> getContentsForClient(clientId) {
    return _safeFirestoreListStream(
      _db
          .where('clientId', isEqualTo: clientId)
          .orderBy("createdAt", descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => ContentModel.fromJson(doc.data(), doc.id))
                    .toList(),
          ),
      'contentsForClient',
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
    return _safeFirestoreListStream(
      _dbtask.snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) {
              final raw = doc.data();
              final map = Map<String, dynamic>.from(raw as Map);
              return TaskModel.fromJson(map);
            }).toList(),
      ),
      'tasks',
    );
  }

  /// يطابق [canReadTaskDoc] في firestore.rules: مهام القسم (`type`) أو المعيّنة للموظف.
  /// الاستعلام على المجموعة كاملة يُرفض للموظف لأن القواعد لا تضمن قراءة كل المستندات.
  static String? _taskTypeCodeForNormalizedDepartment(String normalizedDept) {
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
      default:
        return null;
    }
  }

  /// تيار مهام موظف عادي (ليس مشرفاً/مديراً): `assignedTo` أو `type` حسب القسم.
  Stream<List<TaskModel>> getTasksStreamForEmployee({
    required String employeeId,
    String? departmentRaw,
  }) {
    final trimmedId = employeeId.trim();
    if (trimmedId.isEmpty) {
      return Stream<List<TaskModel>>.value(const <TaskModel>[]);
    }
    final dept = StorageKeys.normalizeDepartment(departmentRaw);
    final typeCode = _taskTypeCodeForNormalizedDepartment(dept);

    Query<Map<String, dynamic>> q;
    if (typeCode != null) {
      q = _dbtask.where(
        Filter.or(
          Filter('assignedTo', isEqualTo: trimmedId),
          Filter('type', isEqualTo: typeCode),
        ),
      );
    } else {
      q = _dbtask.where('assignedTo', isEqualTo: trimmedId);
    }

    return _safeFirestoreListStream(
      q.snapshots().map((snapshot) {
        final list =
            snapshot.docs.map((doc) {
              final raw = doc.data();
              final map = Map<String, dynamic>.from(raw);
              map['id'] = doc.id;
              return TaskModel.fromJson(map);
            }).toList();
        list.sort((a, b) => a.fromDate.compareTo(b.fromDate));
        return list;
      }),
      'tasksForEmployee',
    );
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _safeFirestoreListStream(
      db
          .collection('chats/$chatId/messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((e) => MessageModel.fromJson(e.data()))
                    .toList(),
          ),
      'chatMessages',
    );
  }

  Future<void> sendMessage(String chatId, MessageModel message) async {
    await db
        .collection('chats/$chatId/messages')
        .doc(message.id)
        .set(message.toJson());
  }

  /// يضع [isRead] = true لكل الرسائل الواردة (مرسل ليس [viewerUserId]) داخل [chatId].
  /// يُستدعى عند فتح المحادثة أو عند وصول تحديثات أثناء بقاء الشاشة مفتوحة.
  /// يحدّد المحادثة المفتوحة حالياً لموظف (لتخطّي FCM على الخادم عند الحاجة).
  static Future<void> syncEmployeeActiveChatId(
    String employeeId,
    String? chatId,
  ) async {
    try {
      final ref = FirebaseFirestore.instance.collection('employees').doc(employeeId);
      if (chatId == null || chatId.isEmpty) {
        await ref.update({
          'activeChatId': FieldValue.delete(),
          'activeChatUpdatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.update({
          'activeChatId': chatId,
          'activeChatUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      log('syncEmployeeActiveChatId: $e');
    }
  }

  static Future<void> markIncomingMessagesReadInChat(
    String chatId,
    String viewerUserId,
  ) async {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    try {
      final unreadMessages =
          await chatRef
              .collection('messages')
              .where('isRead', isEqualTo: false)
              .where('senderId', isNotEqualTo: viewerUserId)
              .get();

      for (final doc in unreadMessages.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      if (e.toString().contains('failed-precondition') ||
          e.toString().contains('index')) {
        final unreadSnapshot =
            await chatRef
                .collection('messages')
                .where('isRead', isEqualTo: false)
                .get();
        final toMark =
            unreadSnapshot.docs
                .where((d) => d.data()['senderId'] != viewerUserId)
                .toList();
        for (final doc in toMark) {
          await doc.reference.update({'isRead': true});
        }
      } else {
        rethrow;
      }
    }
  }

  static bool _shouldPersistFcmToNotificationInbox(String? notificationType) {
    return notificationType?.trim() != 'chat_message';
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
  static Future<void> deleteInAppNotifications(Iterable<String> docIds) async {
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

    void onUnreadSubError(Object e, StackTrace st) {
      // أثناء تسجيل الخروج تُلغى صلاحيات Firestore؛ لا نُمرّر الخطأ للمستمع (RethrownDartError).
      if (FirebaseAuth.instance.currentUser == null) return;
      final msg = e.toString();
      if (msg.contains('permission-denied')) return;
      log('⚠️ getTotalUnreadMessagesStream (messages sub): $e');
    }

    void onChatsSubError(Object e, StackTrace st) {
      if (FirebaseAuth.instance.currentUser == null) {
        try {
          controller.add(0);
        } catch (_) {}
        return;
      }
      final msg = e.toString();
      if (msg.contains('permission-denied')) {
        try {
          controller.add(0);
        } catch (_) {}
        return;
      }
      log('⚠️ getTotalUnreadMessagesStream (chats): $e');
      try {
        controller.add(0);
      } catch (_) {}
    }

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
          onError: onUnreadSubError,
          cancelOnError: false,
        );
      }
    }

    chatsSub = db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen(onChatsUpdate, onError: onChatsSubError);

    controller.onCancel = () {
      chatsSub?.cancel();
      cancelUnreadSubs();
    };

    return controller.stream;
  }

  /// عدد الرسائل غير المقروءة الواردة من غير [userId] داخل محادثة [chatId].
  /// يتبع نفس منطق [getTotalUnreadMessagesStream] لكل محادثة.
  Stream<int> unreadIncomingCountStream(String chatId, String userId) {
    return db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.where((d) => d.data()['senderId'] != userId).length);
  }

  Stream<List<NotificationModel>> getNotifications(
    String userId,
    String otherId,
  ) {
    if (FirebaseAuth.instance.currentUser == null) {
      return Stream<List<NotificationModel>>.value(const <NotificationModel>[]);
    }
    final mapped = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', whereIn: [userId, otherId])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    NotificationModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .toList(),
        );
    return _safeFirestoreListStream(mapped, 'notifications');
  }

  /// Diagnostics query by request id.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  watchPushDiagnosticsByRequestId(String requestId) {
    return FirebaseFirestore.instance
        .collection('push_diagnostics')
        .where('requestId', isEqualTo: requestId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Diagnostics query by recipient user id.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  watchPushDiagnosticsByRecipient(String recipientId) {
    return FirebaseFirestore.instance
        .collection('push_diagnostics')
        .where('recipientId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  /// Diagnostics query focused on recent iOS-like failures.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  watchRecentIosPushFailures() {
    return FirebaseFirestore.instance
        .collection('push_diagnostics')
        .where('status', isEqualTo: 'error')
        .where('fcmErrorMessage', isGreaterThanOrEqualTo: 'A')
        .orderBy('fcmErrorMessage')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  static Future<void> sendFcm({
    required String userId,
    required String title,
    required String body,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
    /// يُدمج في حمولة `data` لـ FCM (مثل `chatId` لإشعارات الدردشة).
    Map<String, String>? fcmDataExtras,
    bool sendPush = true,
    bool sendEmail = true,
    Set<String>? batchSeenTokens,
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
      final tokens = _extractFcmTokens(data);
      final rawRecipientName = data?['name']?.toString().trim();
      final recipientRole = data?['role'];
      final recipientName =
          (rawRecipientName != null && rawRecipientName.isNotEmpty)
              ? rawRecipientName
              : 'الموظف';

      final trimmedUserId = userId.trim();
      if (_shouldPersistFcmToNotificationInbox(notificationType)) {
        await addNotification(
          NotificationModel(
            title: title,
            body: body,
            recipientId: trimmedUserId,
            createdAt: DateTime.now(),
            isRead: false,
          ),
        );
      }

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
            "⚠️ Email missing for $recipientRole $recipientName — skipping email notification",
          );
        }
      }

      // إذا المستخدم لا يريد Push، ننهي بدون فحص token أو إرسال push.
      if (!sendPush) return;

      if (tokens.isEmpty) {
        log("⚠️ fcmToken missing for $recipientRole $recipientName — push not sent");
        return;
      }

      for (final token in tokens) {
        final cleanedToken = token.trim();
        if (cleanedToken.isEmpty) continue;
        if (batchSeenTokens != null && !batchSeenTokens.add(cleanedToken)) {
          log(
            "↩️ Duplicate batch token skipped for $recipientRole $recipientName (${_maskFcmToken(cleanedToken)})",
          );
          continue;
        }
        final requestId = _newPushRequestId();
        try {
          await _sendFcmViaFunction(
            token: cleanedToken,
            title: title,
            body: body,
            data: <String, String>{
              'type': 'internal',
              'id': trimmedUserId,
              'url': 'https://example.com',
              if (notificationType != null &&
                  notificationType.trim().isNotEmpty)
                'notificationType': notificationType.trim(),
              if (fcmDataExtras != null) ...fcmDataExtras,
            },
            requestId: requestId,
            recipientId: trimmedUserId,
            recipientType: 'employee',
            notificationType: notificationType,
          );
        } catch (e) {
          if (e is FcmSendException) {
            await _logPushDiagnostic(
              requestId: requestId,
              stage: 'app_result',
              status: 'error',
              targetType: 'token',
              recipientId: trimmedUserId,
              recipientType: 'employee',
              tokenMasked: _maskFcmToken(cleanedToken),
              title: title,
              bodyLen: body.length,
              notificationType: notificationType,
              fcmHttpStatus: e.status,
              fcmErrorCode: e.errorCode,
              fcmErrorStatus: e.fcmErrorStatus,
              fcmErrorMessage: e.fcmErrorMessage,
              details: e.details,
            );
          }
          if (_isInvalidOrExpiredTokenError(e)) {
            await _removeEmployeeFcmToken(
              employeeId: trimmedUserId,
              token: cleanedToken,
            );
            log("🧹 Removed invalid employee token for $recipientName");
            continue;
          }
          rethrow;
        }
      }
      log("✅ FCM Response: $recipientName");
    } on FcmSendException catch (e) {
      switch (e.errorCode) {
        case 'ERR_METHOD_NOT_ALLOWED':
          log("❌ FCM Error: ${AppLocaleKeys.errorsMethodNotAllowed}");
          break;
        case 'ERR_UNAUTHORIZED':
          log("❌ FCM Error: ${AppLocaleKeys.errorsUnauthorized}");
          break;
        case 'ERR_FORBIDDEN':
          log("❌ FCM Error: ${AppLocaleKeys.errorsForbidden}");
          break;
        case 'ERR_MISSING_TOKEN':
          log("❌ FCM Error: ${AppLocaleKeys.errorsMissingToken}");
          break;
        case 'ERR_INVALID_DATA':
          log("❌ FCM Error: ${AppLocaleKeys.errorsInvalidData}");
          break;
        default:
          log("❌ FCM Error: ${AppLocaleKeys.errorsServer} | $e");
      }
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
    Map<String, String>? fcmDataExtras,
    bool sendPush = true,
    bool sendEmail = true,
    Set<String>? batchSeenTokens,
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
      final tokens = _extractFcmTokens(data);
      final rawRecipientName = data?['name']?.toString().trim();
      final recipientName =
          (rawRecipientName != null && rawRecipientName.isNotEmpty)
              ? rawRecipientName
              : 'العميل';

      final trimmedUserId = userId.trim();
      if (_shouldPersistFcmToNotificationInbox(notificationType)) {
        await addNotification(
          NotificationModel(
            title: title,
            body: body,
            recipientId: trimmedUserId,
            createdAt: DateTime.now(),
            isRead: false,
          ),
        );
      }

      if (sendEmail) {
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
            "⚠️ Email missing for client $recipientName — skipping email notification",
          );
        }
      }

      if (!sendPush) return;

      if (tokens.isEmpty) {
        log("⚠️ fcmToken missing for client $recipientName — push not sent");
        return;
      }

      for (final token in tokens) {
        final cleanedToken = token.trim();
        if (cleanedToken.isEmpty) continue;
        if (batchSeenTokens != null && !batchSeenTokens.add(cleanedToken)) {
          log(
            "↩️ Duplicate batch token skipped for client $recipientName (${_maskFcmToken(cleanedToken)})",
          );
          continue;
        }
        final requestId = _newPushRequestId();
        try {
          await _sendFcmViaFunction(
            token: cleanedToken,
            title: title,
            body: body,
            data: <String, String>{
              'type': 'internal',
              'id': trimmedUserId,
              'url': 'https://example.com',
              if (notificationType != null &&
                  notificationType.trim().isNotEmpty)
                'notificationType': notificationType.trim(),
              if (fcmDataExtras != null) ...fcmDataExtras,
            },
            requestId: requestId,
            recipientId: trimmedUserId,
            recipientType: 'client',
            notificationType: notificationType,
          );
        } catch (e) {
          if (e is FcmSendException) {
            await _logPushDiagnostic(
              requestId: requestId,
              stage: 'app_result',
              status: 'error',
              targetType: 'token',
              recipientId: trimmedUserId,
              recipientType: 'client',
              tokenMasked: _maskFcmToken(cleanedToken),
              title: title,
              bodyLen: body.length,
              notificationType: notificationType,
              fcmHttpStatus: e.status,
              fcmErrorCode: e.errorCode,
              fcmErrorStatus: e.fcmErrorStatus,
              fcmErrorMessage: e.fcmErrorMessage,
              details: e.details,
            );
          }
          if (_isInvalidOrExpiredTokenError(e)) {
            await _removeClientFcmToken(
              clientId: trimmedUserId,
              token: cleanedToken,
            );
            log("🧹 Removed invalid client token for $recipientName");
            continue;
          }
          rethrow;
        }
      }
      log("✅ FCM sent to client: $recipientName");
    } on FcmSendException catch (e) {
      switch (e.errorCode) {
        case 'ERR_METHOD_NOT_ALLOWED':
          log("❌ FCM Error: ${AppLocaleKeys.errorsMethodNotAllowed}");
          break;
        case 'ERR_UNAUTHORIZED':
          log("❌ FCM Error: ${AppLocaleKeys.errorsUnauthorized}");
          break;
        case 'ERR_FORBIDDEN':
          log("❌ FCM Error: ${AppLocaleKeys.errorsForbidden}");
          break;
        case 'ERR_MISSING_TOKEN':
          log("❌ FCM Error: ${AppLocaleKeys.errorsMissingToken}");
          break;
        case 'ERR_INVALID_DATA':
          log("❌ FCM Error: ${AppLocaleKeys.errorsInvalidData}");
          break;
        default:
          log("❌ FCM Error: ${AppLocaleKeys.errorsServer} | $e");
      }
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
    final requestId = _newPushRequestId();
    try {
      if (sendPush) {
        await _sendFcmViaFunction(
          topic: topic,
          title: title,
          body: body,
          data:
              notificationType != null && notificationType.trim().isNotEmpty
                  ? <String, String>{
                    'notificationType': notificationType.trim(),
                  }
                  : null,
          requestId: requestId,
          recipientType: 'topic',
          notificationType: notificationType,
        );
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
    } on FcmSendException catch (e) {
      await _logPushDiagnostic(
        requestId: requestId,
        stage: 'app_result',
        status: 'error',
        targetType: 'topic',
        topic: topic,
        title: title,
        bodyLen: body.length,
        notificationType: notificationType,
        fcmHttpStatus: e.status,
        fcmErrorCode: e.errorCode,
        fcmErrorStatus: e.fcmErrorStatus,
        fcmErrorMessage: e.fcmErrorMessage,
        details: e.details,
      );
      log("❌ FCM Error: $e");
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

  /// جلب معرفات الموظفين حسب القسم الدلالي (مثل publishing, promotion).
  static Future<List<String>> getEmployeeIdsByDepartment(
    String department,
  ) async {
    if (department.isEmpty) return [];
    try {
      final normalized = StorageKeys.normalizeDepartment(department);
      if (normalized.isEmpty) return [];
      final snap =
          await FirebaseFirestore.instance
              .collection('employees')
              .where('department', isEqualTo: normalized)
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
    Map<String, String>? fcmDataExtras,
  }) async {
    final seen = <String>{};
    final batchSeenTokens = <String>{};
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
          fcmDataExtras: fcmDataExtras,
          batchSeenTokens: batchSeenTokens,
        ),
      );
    }
  }
}
