import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Models/chatMetaData.dart';
import 'package:point/Services/EmailNotificationService.dart';
import 'package:point/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FirestoreServices {
  static Future<void> _sendFcmViaFunction({
    String? token,
    String? topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final firebaseIdToken =
        await FirebaseAuth.instance.currentUser?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw StateError('FirebaseAuth session required to send FCM.');
    }

    final res = await Supabase.instance.client.functions.invoke(
      'send-fcm',
      headers: <String, String>{'authorization': 'Bearer $firebaseIdToken'},
      body: <String, dynamic>{
        if (token != null) 'token': token,
        if (topic != null) 'topic': topic,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
      },
    );

    if (res.status != 200) {
      throw StateError('send-fcm failed (${res.status}): ${res.data}');
    }
  }

  // static get currentUser => '1';

  var db = FirebaseFirestore.instance;
  final CollectionReference _employeeCollection = FirebaseFirestore.instance
      .collection("employees");

  Future<UserCredential> _createOrGetAuthUser({
    required String email,
    required String password,
  }) async {
    final auth = FirebaseAuth.instance;
    final normalizedEmail = email.trim().toLowerCase();
    try {
      // إذا كان المستخدم موجوداً وجربنا تسجيل الدخول بكلمة مرور قديمة أو جديدة
      return await auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e, s) {
      log(
        '❌ _createOrGetAuthUser signIn FirebaseAuthException code=${e.code}, message=${e.message}',
      );
      log('StackTrace: $s');
      if (e.code == 'user-not-found') {
        // إنشاء مستخدم جديد في Auth
        final cred = await auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        log('✅ FirebaseAuth user created for $normalizedEmail');
        return cred;
      }
      rethrow;
    }
  }

  Future<bool> createEmployeeWithAuth({
    required EmployeeModel employee,
    required String password,
  }) async {
    final email = employee.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      log('❌ createEmployeeWithAuth: email is required');
      return false;
    }
    try {
      // Add record only; Auth user is created when employee logs in (loginemployee).
      await _employeeCollection
          .doc(employee.id)
          .set(employee.copyWith(password: password).toJson());
      log("✅ createEmployeeWithAuth: ${employee.name}");
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
    final oldEmail = existing.email?.trim().toLowerCase();
    final newEmail = updated.email?.trim().toLowerCase();
    final passwordToUse =
        newPassword?.trim().isNotEmpty == true
            ? newPassword!.trim()
            : existing.password;

    if (newEmail == null || newEmail.isEmpty) {
      log('❌ updateEmployeeWithAuth: email is required');
      return false;
    }
    if (passwordToUse == null || passwordToUse.isEmpty) {
      log('❌ updateEmployeeWithAuth: password is required to sync Auth user');
      return false;
    }

    try {
      // أولاً نضمن جلسة لـ FirebaseAuth بنفس البريد الجديد/الحالي
      await _createOrGetAuthUser(email: newEmail, password: passwordToUse);

      // إذا تغيّر البريد، لا نعبأ كثيراً بالبريد القديم لأننا نستخدم normalize دائماً
      final toSave = updated.copyWith(
        password:
            newPassword?.trim().isNotEmpty == true
                ? newPassword!.trim()
                : existing.password,
      );
      await _employeeCollection.doc(toSave.id).update(toSave.toJson());
      log(
        "✅ updateEmployeeWithAuth: ${toSave.id} (oldEmail=$oldEmail, newEmail=$newEmail)",
      );
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
      await _employeeCollection.doc(employee.id).set(employee.toJson());
      log("✅ تم إضافة الموظف بنجاح: ${employee.name}");
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
      if (employee.id == null) throw Exception("معرف الموظف (id) مفقود!");
      await _employeeCollection.doc(employee.id).update(employee.toJson());
      log("✅ تم تحديث الموظف: ${employee.id}");
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
      // 1) Query Firestore first by email
      final query =
          await _employeeCollection
              .where("email", isEqualTo: normalizedEmail)
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        log("❌ loginEmployee: no employee record for $normalizedEmail");
        return null;
      }

      final data = query.docs.first.data() as Map<String, dynamic>;
      final employee = EmployeeModel.fromJson(data);

      // 2) Verify password against stored model
      final storedPassword = employee.password?.trim();
      if (storedPassword == null ||
          storedPassword.isEmpty ||
          storedPassword != password.trim()) {
        log("❌ loginEmployee: invalid password for $normalizedEmail");
        return null;
      }

      // 3) Sign in or create Auth user (user-not-found → createUser then sign in)
      await _ensureFirebaseAuthSession(
        email: normalizedEmail,
        password: password,
      );

      return employee;
    } on FirebaseAuthException catch (e, s) {
      log(
        "❌ loginEmployee FirebaseAuthException code=${e.code}, message=${e.message}",
      );
      log("StackTrace: $s");
      return null;
    } catch (e, s) {
      log("❌ loginEmployee error: $e\n$s");
      return null;
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
        try {
          await _ensureFirebaseAuthSession(
            email: _kTestAccountholderEmail,
            password: _testAccountholderPassword,
          );
        } catch (e, s) {
          log(
            '❌ ensureAccountholderTestUser (existing) FirebaseAuth error: $e',
          );
          log('StackTrace: $s');
        }
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
        password: _testAccountholderPassword,
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

  Stream<EmployeeModel?> streamCurrentemployee(String empid) {
    return _employeeCollection.doc(empid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        final raw = snapshot.data();
        final map = Map<String, dynamic>.from(raw as Map);
        return EmployeeModel.fromJson(map);
      } else {
        return null;
      }
    });
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
      // Add record only; Auth user is created when client logs in (loginClient).
      await _clientCollection
          .doc(client.id)
          .set(client.copyWith(password: password).toJson());
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
    final oldEmail = existing.email?.trim().toLowerCase();
    final newEmail = updated.email?.trim().toLowerCase();
    final passwordToUse =
        newPassword?.trim().isNotEmpty == true
            ? newPassword!.trim()
            : existing.password;

    if (newEmail == null || newEmail.isEmpty) {
      log('❌ updateClientWithAuth: email is required');
      return false;
    }
    if (passwordToUse == null || passwordToUse.isEmpty) {
      log('❌ updateClientWithAuth: password is required to sync Auth user');
      return false;
    }

    try {
      await _createOrGetAuthUser(email: newEmail, password: passwordToUse);
      final toSave = updated.copyWith(
        password:
            newPassword?.trim().isNotEmpty == true
                ? newPassword!.trim()
                : existing.password,
      );
      await _clientCollection.doc(toSave.id).update(toSave.toJson());
      log(
        "✅ updateClientWithAuth: ${toSave.id} (oldEmail=$oldEmail, newEmail=$newEmail)",
      );
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
      // 1) Query Firestore first by email
      final query =
          await _clientCollection
              .where("email", isEqualTo: normalizedEmail)
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        log("❌ loginClient: no client record for $normalizedEmail");
        return null;
      }

      final data = query.docs.first.data();
      final docId = query.docs.first.id;
      final client = ClientModel.fromJson(data, docId);

      // 2) Verify password against stored model
      final storedPassword = client.password?.trim();
      if (storedPassword == null ||
          storedPassword.isEmpty ||
          storedPassword != password.trim()) {
        log("❌ loginClient: invalid password for $normalizedEmail");
        return null;
      }

      // 3) Sign in or create Auth user (user-not-found → createUser then sign in)
      await _ensureFirebaseAuthSession(
        email: normalizedEmail,
        password: password,
      );

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

  Future<void> _ensureFirebaseAuthSession({
    required String email,
    required String password,
  }) async {
    final auth = FirebaseAuth.instance;
    final normalizedEmail = email.trim().toLowerCase();
    try {
      await auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      log('✅ FirebaseAuth signIn successful for $normalizedEmail');
    } on FirebaseAuthException catch (e, s) {
      log(
        '❌ _ensureFirebaseAuthSession FirebaseAuthException code=${e.code}, message=${e.message}',
      );
      log('StackTrace: $s');

      // إذا لم يوجد المستخدم في FirebaseAuth يمكننا إنشاؤه (سياسة التطبيق الحالية).
      try {
        await auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        log('✅ FirebaseAuth user created for $normalizedEmail');
        return;
      } on FirebaseAuthException catch (ce, cs) {
        log(
          '❌ createUserWithEmailAndPassword failed for $normalizedEmail code=${ce.code}, message=${ce.message}',
        );
        log('StackTrace: $cs');
        rethrow;
      }
    }
  }

  Stream<ClientModel?> streamCurrentClient(String clientId) {
    return _clientCollection.doc(clientId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return ClientModel.fromJson(snapshot.data()!, snapshot.id);
      } else {
        return null;
      }
    });
  }

  Future<bool> addClient(ClientModel client) async {
    try {
      await _clientCollection.doc(client.id).set(client.toJson());
      return true;
    } catch (e, s) {
      log("❌ addClient error: $e\n$s");
      return true;
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

  static addNotification(NotificationModel model) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .add(model.toJson());
  }

  /// Stream of total unread messages count across all chats for [userId].
  /// Updates in real time when chats or messages change.
  Stream<int> getTotalUnreadMessagesStream(String userId) {
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
            counts[chatId] = count;
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
              .map((doc) => NotificationModel.fromJson(doc.data()))
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

      // إرسال إيميل حتى عند غياب FCM (من لم يثبت التطبيق أو عطّل الإشعارات يظل يحصل على الإيميل)
      if (email != null && email.isNotEmpty) {
        unawaited(
          EmailNotificationService.sendNotification(
            toEmail: email,
            title: title,
            body: body,
          ),
        );
      } else {
        log(
          "⚠️ Email missing for employee $userId — skipping email notification",
        );
      }

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
          'id': userId,
          'url': 'https://example.com',
        },
      );
      addNotification(
        NotificationModel(
          title: title,
          body: body,
          recipientId: userId,
          createdAt: DateTime.now(),
        ),
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

      // إرسال إيميل حتى عند غياب FCM (من لم يثبت التطبيق أو عطّل الإشعارات يظل يحصل على الإيميل)
      if (email != null && email.isNotEmpty) {
        unawaited(
          EmailNotificationService.sendNotification(
            toEmail: email,
            title: title,
            body: body,
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
          'id': userId,
          'url': 'https://example.com',
        },
      );
      addNotification(
        NotificationModel(
          title: title,
          body: body,
          recipientId: userId,
          createdAt: DateTime.now(),
        ),
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
  }) async {
    try {
      await _sendFcmViaFunction(topic: topic, title: title, body: body);

      // إرسال إيميل إشعار لجميع المستلمين في الـ topic (بدون انتظار)
      unawaited(_sendEmailForTopic(topic, title, body));

      log("✅ FCM topic sent: $topic");
    } catch (e) {
      log("❌ FCM Error: $e");
    }
  }

  /// يجلب عناوين البريد حسب الـ topic ويرسل إشعاراً لكل واحد.
  static Future<void> _sendEmailForTopic(
    String topic,
    String title,
    String body,
  ) async {
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
        unawaited(
          EmailNotificationService.sendNotification(
            toEmail: email,
            title: title,
            body: body,
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
  }) async {
    final seen = <String>{};
    for (final id in userIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      unawaited(sendFcm(userId: trimmed, title: title, body: body));
    }
  }
}
