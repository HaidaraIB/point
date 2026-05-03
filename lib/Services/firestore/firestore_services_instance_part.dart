part of 'package:point/Services/FireStoreServices.dart';

const Set<String> _kGlobalRolesWithoutDepartment = {
  'admin',
  'supervisor',
};

mixin FirestoreServicesInstanceMixin on FirestoreServicesBase {
  EmployeeModel _normalizeEmployeeDepartmentByRole(EmployeeModel employee) {
    if (_kGlobalRolesWithoutDepartment.contains(employee.role)) {
      return employee.copyWith(departments: const []);
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
        appLog(
          '⚠️ _updateAuthFieldsWithRetry attempt ${attempt + 1}/$maxAttempts failed: $e',
        );
        appLog('StackTrace: $s');
        if (attempt == maxAttempts - 1) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
  }

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
      appLog('❌ createEmployeeWithAuth: email is required');
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
      appLog("✅ createEmployeeWithAuth: ${normalizedEmployee.name}");
      return true;
    } catch (e, s) {
      appLog("❌ createEmployeeWithAuth error: $e");
      appLog("StackTrace: $s");
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
          appLog(
            "⚠️ updateEmployeeWithAuth password update skipped: code=${e.code}, message=${e.message}",
          );
        }
      }
      appLog("✅ updateEmployeeWithAuth (table-only): ${merged.id}");
      return true;
    } catch (e, s) {
      appLog("❌ updateEmployeeWithAuth error: $e");
      appLog("StackTrace: $s");
      return false;
    }
  }

  /// تحديث [name] و/أو [image] فقط (بدون بقية حقول [EmployeeModel.toJson]).
  /// يُستخدم لملف الموظف الشخصي حتى تطابق قواعد الأمان `affectedKeys` لدور employee.
  Future<bool> updateEmployeeProfileFields({
    required String employeeId,
    required String name,
    String? imageUrl,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
      };
      final img = imageUrl?.trim();
      if (img != null && img.isNotEmpty) {
        payload['image'] = img;
      }
      await _employeeCollection.doc(employeeId).update(payload);
      appLog("✅ updateEmployeeProfileFields: $employeeId");
      return true;
    } catch (e, s) {
      appLog("❌ updateEmployeeProfileFields error: $e");
      appLog("StackTrace: $s");
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
      appLog("✅ تم إضافة الموظف بنجاح: ${normalizedEmployee.name}");
      return true;
    } catch (e, s) {
      appLog("❌ خطأ أثناء إضافة الموظف: $e");
      appLog("StackTrace: $s");
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
      appLog("✅ تم تحديث الموظف: ${normalizedEmployee.id}");
      return true;
    } catch (e, s) {
      appLog("❌ خطأ أثناء تحديث الموظف: $e");
      appLog("StackTrace: $s");
      return false;
    }
  }

  // 🔴 حذف موظف
  Future<bool> deleteEmployee(String id) async {
    try {
      await _employeeCollection.doc(id).delete();
      appLog("✅ تم حذف الموظف: $id");
      return true;
    } catch (e, s) {
      appLog("❌ خطأ أثناء حذف الموظف: $e");
      appLog("StackTrace: $s");
      return false;
    }
  }

  // 🔍 قراءة موظف واحد
  Future<EmployeeModel?> getEmployeeById(String id) async {
    try {
      final doc = await _employeeCollection.doc(id).get();
      if (!doc.exists) {
        appLog("⚠️ لا يوجد موظف بهذا الـ ID: $id");
        return null;
      }
      appLog("✅ تم جلب بيانات الموظف: $id");
      return EmployeeModel.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e, s) {
      appLog("❌ خطأ أثناء جلب الموظف: $e");
      appLog("StackTrace: $s");
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
        appLog("❌ loginEmployee: no employee record for $normalizedEmail");
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
        appLog("❌ loginEmployee: authUid mismatch for ${employee.id}");
        throw StateError('AUTH_UID_MISMATCH');
      }

      await _updateAuthFieldsWithRetry(docRef: doc.reference, uid: uid);
      employee = employee.copyWith(authUid: uid, authStatus: 'active');
      await FirestoreAuthApi.syncAuthRoleForEmployee(employee);
      return employee;
    } on FirebaseAuthException catch (e, s) {
      appLog(
        "❌ loginEmployee FirebaseAuthException code=${e.code}, message=${e.message}",
      );
      appLog("StackTrace: $s");
      throw StateError('FIREBASE_AUTH_${e.code.toUpperCase()}');
    } catch (e, s) {
      appLog("❌ loginEmployee error: $e\n$s");
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
      appLog('⚠️ TEST_ADMIN_PASSWORD غير معرّف — تخطي إنشاء الحساب الاختباري');
      return;
    }
    try {
      // Fixed doc id (see [_kTestAdminDevId]); avoids collection query + index,
      // and matches [testAdminDevEmployeeBootstrapCreate] in firestore.rules.
      final existing = await _employeeCollection.doc(_kTestAdminDevId).get();
      if (existing.exists) {
        appLog("✅ حساب $_kTestAdminDevEmail موجود مسبقاً");
        return;
      }
      final employee = EmployeeModel(
        id: _kTestAdminDevId,
        name: 'Point Test (Admin)',
        email: _kTestAdminDevEmail,
        phone: null,
        role: 'admin',
        departments: const [],
        fcmToken: null,
        onesignal: null,
        hireDate: null,
        status: 'active',
        createdAt: DateTime.now(),
        authStatus: 'active',
        image: null,
      );
      await _employeeCollection.doc(employee.id).set(employee.toJson());
      appLog(
        "✅ تم إضافة الحساب الاختباري $_kTestAdminDevEmail إلى قاعدة البيانات (admin)",
      );

      // تأكد من وجود حساب مطابق في FirebaseAuth بنفس البريد وكلمة المرور.
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _kTestAdminDevEmail,
          password: _testAdminDevPassword,
        );
        appLog('✅ FirebaseAuth session/creation successful for test admin');
      } on FirebaseAuthException catch (e, s) {
        appLog(
          '❌ ensureTestAdminUser FirebaseAuthException code=${e.code}, message=${e.message}',
        );
        appLog('StackTrace: $s');
      } catch (e, s) {
        appLog('❌ ensureTestAdminUser unexpected error: $e');
        appLog('StackTrace: $s');
      }
      return;
    } catch (e) {
      appLog("❌ ensureTestAdminUser: $e");
      return;
    }
  }

  // 📡 قراءة كل الموظفين (Stream) — يشمل admin وsupervisor وemployee.
  Stream<List<EmployeeModel>> getEmployees() {
    try {
      return safeFirestoreListStream(
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
      appLog("❌ خطأ أثناء جلب كل الموظفين: $e");
      appLog("StackTrace: $s");
      return const Stream.empty();
    }
  }

  Stream<Map<String, DateTime>> getEmployeePresenceMap() {
    return FirebaseFirestore.instance
        .collection('employee_presence')
        .snapshots()
        .map((snapshot) {
          final out = <String, DateTime>{};
          for (final doc in snapshot.docs) {
            final raw = doc.data();
            final ts = raw['lastSeenAt'];
            DateTime? dt;
            if (ts is Timestamp) {
              dt = ts.toDate();
            } else if (ts is String) {
              dt = DateTime.tryParse(ts);
            }
            if (dt != null) {
              out[doc.id] = dt;
            }
          }
          return out;
        });
  }

  Future<void> syncEmployeePresenceHeartbeat(String employeeId) async {
    final id = employeeId.trim();
    if (id.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('employee_presence').doc(id).set(
        <String, dynamic>{
          'employeeId': id,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      appLog('syncEmployeePresenceHeartbeat: $e');
    }
  }

  Future<bool> createClientWithAuth({
    required ClientModel client,
    required String password,
  }) async {
    final email = client.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      appLog('❌ createClientWithAuth: email is required');
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
      appLog("✅ createClientWithAuth: ${client.name}");
      return true;
    } catch (e, s) {
      appLog("❌ createClientWithAuth error: $e");
      appLog("StackTrace: $s");
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
          appLog(
            "⚠️ updateClientWithAuth password update skipped: code=${e.code}, message=${e.message}",
          );
        }
      }
      appLog("✅ updateClientWithAuth (table-only): ${merged.id}");
      return true;
    } catch (e, s) {
      appLog("❌ updateClientWithAuth error: $e");
      appLog("StackTrace: $s");
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
        appLog("❌ loginClient: no client record for $normalizedEmail");
        return null;
      }

      final doc = query.docs.first;
      final data = doc.data() as Map<String, dynamic>;
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
        appLog("❌ loginClient: authUid mismatch for ${client.id}");
        return null;
      }

      await _updateAuthFieldsWithRetry(docRef: doc.reference, uid: uid);
      client = client.copyWith(authUid: uid, authStatus: 'active');
      await FirestoreAuthApi.syncAuthRoleForClient(client);
      return client;
    } on FirebaseAuthException catch (e, s) {
      appLog(
        "❌ loginClient FirebaseAuthException code=${e.code}, message=${e.message}",
      );
      appLog("StackTrace: $s");
      return null;
    } catch (e, s) {
      appLog("❌ loginClient error: $e\n$s");
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
      appLog("⚠️ signOut: FCM cleanup failed (ignored): $e");
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
    if (kIsWeb) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      final cleanedToken = token?.trim() ?? '';
      if (cleanedToken.isEmpty) return;

      // تحديث الموظف مسموح فقط على employees/{myEmployeeId} — نقرأ المعرف من authRoles.
      final roleSnap =
          await FirebaseFirestore.instance
              .collection(FirestoreAuthApi.authRolesCollection)
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
      appLog("⚠️ remove current device token before signOut failed: $e");
    }
  }

  Future<EmployeeModel?> getCurrentEmployeeByAuth() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return null;
    final uid = current.uid;
    QueryDocumentSnapshot? byUidDoc;
    try {
      final byUid =
          await _employeeCollection
              .where('authUid', isEqualTo: uid)
              .limit(1)
              .get();
      if (byUid.docs.isNotEmpty) {
        byUidDoc = byUid.docs.first;
      }
    } on FirebaseException catch (e) {
      // During cold-start token/claims timing, this query can be denied.
      // Continue with email-based restore instead of failing whole auto-login.
      if (e.code == 'permission-denied') {
        appLog('getCurrentEmployeeByAuth byUid permission-denied; fallback byEmail');
      } else {
        rethrow;
      }
    }
    if (byUidDoc != null) {
      final doc = byUidDoc;
      final emp = EmployeeModel.fromJson(doc.data() as Map<String, dynamic>)
          .copyWith(id: doc.id);
      try {
        await FirestoreAuthApi.syncAuthRoleForEmployee(emp);
      } catch (e) {
        appLog('getCurrentEmployeeByAuth sync role failed (ignored): $e');
      }
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
    try {
      await _employeeCollection.doc(doc.id).update({
        'authUid': uid,
        'authStatus': 'active',
      });
    } catch (e) {
      appLog('getCurrentEmployeeByAuth update auth fields failed (ignored): $e');
    }
    final restored = EmployeeModel.fromJson(
      doc.data() as Map<String, dynamic>,
    ).copyWith(id: doc.id, authUid: uid, authStatus: 'active');
    try {
      await FirestoreAuthApi.syncAuthRoleForEmployee(restored);
    } catch (e) {
      appLog('getCurrentEmployeeByAuth sync role failed (ignored): $e');
    }
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
    var client = ClientModel.fromJson(doc.data()! as Map<String, dynamic>, doc.id);

    if (client.authUid != null &&
        client.authUid!.trim().isNotEmpty &&
        client.authUid != uid) {
      return null;
    }

    if (client.authUid == uid) {
      try {
        await FirestoreAuthApi.syncAuthRoleForClient(client);
      } catch (e) {
        appLog('getCurrentClientByAuth sync role failed (ignored): $e');
      }
      return client;
    }

    try {
      await _updateAuthFieldsWithRetry(docRef: doc.reference, uid: uid);
    } catch (e) {
      appLog('getCurrentClientByAuth update auth fields failed (ignored): $e');
    }
    final restored =
        client.copyWith(authUid: uid, authStatus: 'active');
    try {
      await FirestoreAuthApi.syncAuthRoleForClient(restored);
    } catch (e) {
      appLog('getCurrentClientByAuth sync role failed (ignored): $e');
    }
    return restored;
  }

  Future<bool> addClient(ClientModel client) async {
    try {
      await _clientCollection.doc(client.id).set(client.toJson());
      return true;
    } catch (e, s) {
      appLog("❌ addClient error: $e\n$s");
      return false;
    }
  }

  Future<bool> updateClient(ClientModel client) async {
    try {
      if (client.id == null) return false;
      await _clientCollection.doc(client.id).update(client.toJson());
      return true;
    } catch (e, s) {
      appLog("❌ updateClient error: $e\n$s");
      return false;
    }
  }

  Future<bool> deleteClient(String id) async {
    try {
      await _clientCollection.doc(id).delete();
      return true;
    } catch (e, s) {
      appLog("❌ deleteClient error: $e\n$s");
      return false;
    }
  }

  Stream<List<ClientModel>> getClientsStream() {
    return safeFirestoreListStream(
      _clientCollection
          .orderBy("createdAt", descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map(
                      (doc) => ClientModel.fromJson(
                        doc.data()! as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
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
    return safeFirestoreListStream(
      _clientCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map(
                      (doc) => ClientModel.fromJson(
                        doc.data()! as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
                    .toList(),
          ),
      'clientsForEmail',
    );
  }

  Future<bool> addContent(ContentModel content) async {
    try {
      final docRef = _db.doc(); // auto id
      await docRef.set(content.copyWith(id: docRef.id).toJson());
      return true;
    } catch (e) {
      appLog("❌ Error addContent: $e");
      return false;
    }
  }

  Future<bool> updateContent(ContentModel content) async {
    try {
      if (content.id == null) throw Exception("id is null");
      await _db.doc(content.id).update(content.toJson());
      return true;
    } catch (e) {
      appLog("❌ Error updateContent: $e");
      return false;
    }
  }

  /// تحديث حقل الترويج فقط — يتوافق مع قواعد موظف الترويج في Firestore.
  Future<bool> updateContentPromotionField(String contentId, String promotion) async {
    try {
      await _db.doc(contentId).update({'promotion': promotion});
      return true;
    } catch (e) {
      appLog("❌ Error updateContentPromotionField: $e");
      return false;
    }
  }

  Future<bool> deleteContent(String id) async {
    try {
      await _db.doc(id).delete();
      return true;
    } catch (e) {
      appLog("❌ Error deleteContent: $e");
      return false;
    }
  }

  Stream<List<ContentModel>> getContents() {
    return safeFirestoreListStream(
      _db
          .orderBy("createdAt", descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map(
                      (doc) => ContentModel.fromJson(
                        doc.data()! as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
                    .toList(),
          ),
      'contents',
    );
  }

  Stream<List<ContentModel>> getContentsForClient(clientId) {
    return safeFirestoreListStream(
      _db
          .where('clientId', isEqualTo: clientId)
          .orderBy("createdAt", descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map(
                      (doc) => ContentModel.fromJson(
                        doc.data()! as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
                    .toList(),
          ),
      'contentsForClient',
    );
  }

  Stream<List<MetaPostModel>> getMetaPosts() {
    return safeFirestoreListStream(
      _metaPostsCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map(
                      (doc) => MetaPostModel.fromJson(
                        doc.data()! as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
                    .toList(),
          ),
      'meta_posts',
    );
  }

  Future<bool> addMetaPost(MetaPostModel post) async {
    try {
      final docRef = _metaPostsCollection.doc();
      await docRef.set(post.copyWith(id: docRef.id).toJson());
      return true;
    } catch (e) {
      appLog('❌ Error addMetaPost: $e');
      return false;
    }
  }

  Future<bool> updateMetaPost(MetaPostModel post) async {
    try {
      if (post.id == null) throw Exception('id is null');
      await _metaPostsCollection.doc(post.id).update(post.toJson());
      return true;
    } catch (e) {
      appLog('❌ Error updateMetaPost: $e');
      return false;
    }
  }

  Future<bool> deleteMetaPost(String id) async {
    try {
      await _metaPostsCollection.doc(id).delete();
      return true;
    } catch (e) {
      appLog('❌ Error deleteMetaPost: $e');
      return false;
    }
  }

  Future<bool> addTask(TaskModel task) async {
    try {
      final docRef = _dbtask.doc(); // auto id
      await docRef.set(task.copyWith(id: docRef.id).toJson());
      return true;
    } catch (e) {
      appLog("❌ Error addTask: $e");
      return false;
    }
  }

  Future<bool> updateTask(TaskModel task) async {
    try {
      if (task.id == null) throw Exception("id is null");
      await _dbtask.doc(task.id).update(task.toJson());
      return true;
    } catch (e) {
      appLog("❌ Error updateTask: $e");
      return false;
    }
  }

  Future<bool> deleteTask(String id) async {
    try {
      await _dbtask.doc(id).delete();
      return true;
    } catch (e) {
      appLog("❌ Error deleteTask: $e");
      return false;
    }
  }

  Stream<List<TaskModel>> getTasks() {
    return safeFirestoreListStream(
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

  /// تيار مهام موظف عادي (ليس مشرفاً/مديراً): `assignedTo` أو `type` حسب القسم.
  Stream<List<TaskModel>> getTasksStreamForEmployee({
    required String employeeId,
    List<String>? departments,
  }) {
    final trimmedId = employeeId.trim();
    if (trimmedId.isEmpty) {
      return Stream<List<TaskModel>>.value(const <TaskModel>[]);
    }
    final depts = StorageKeys.normalizeDepartments(departments ?? const []);
    final typeCodes = <String>{};
    for (final d in depts) {
      final c = taskTypeCodeForNormalizedDepartment(d);
      if (c != null) typeCodes.add(c);
    }

    final filters = <Filter>[
      Filter('assignedTo', isEqualTo: trimmedId),
      ...typeCodes.map((t) => Filter('type', isEqualTo: t)),
    ];

    final Filter combined;
    if (filters.length == 1) {
      combined = filters.single;
    } else {
      var acc = filters[0];
      for (var i = 1; i < filters.length; i++) {
        acc = Filter.or(acc, filters[i]);
      }
      combined = acc;
    }

    final Query<Map<String, dynamic>> q =
        _dbtask.where(combined) as Query<Map<String, dynamic>>;

    return safeFirestoreListStream(
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
    return safeFirestoreListStream(
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
      appLog('⚠️ getTotalUnreadMessagesStream (messages sub): $e');
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
      appLog('⚠️ getTotalUnreadMessagesStream (chats): $e');
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
                (doc) => NotificationModel.fromJson({
                  ...Map<String, dynamic>.from(doc.data() as Map),
                  'id': doc.id,
                }),
              )
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'notifications');
  }
}

