part of 'package:point/Controller/HomeController.dart';

void homeBindLibraryFilesStream(HomeController c, bool canAccessLibrary) {
  if (canAccessLibrary) {
    c.libraryFiles.bindStream(c._service.getLibraryFiles());
  } else {
    c.libraryFiles.bindStream(Stream<List<LibraryFileModel>>.value([]));
  }
}

void homeBindLibraryBrowseTasksStream(HomeController c, bool canAccessLibrary) {
  if (canAccessLibrary) {
    c.libraryBrowseTasks.bindStream(c._service.getTasks());
  } else {
    c.libraryBrowseTasks.bindStream(Stream<List<TaskModel>>.value([]));
  }
}

bool _libraryAccessFromAuthRole(Map<String, dynamic>? m) {
  return m?['libraryAccess'] == true;
}

bool _canAccessLibraryFromRoleAndAuth({
  required String? role,
  required Map<String, dynamic>? authData,
}) {
  if (role == 'admin' || role == 'supervisor') return true;
  if (role == 'employee') return _libraryAccessFromAuthRole(authData);
  return false;
}

List<String> _departmentsFromFirestoreMap(Map<String, dynamic>? m) {
  if (m == null) return const [];
  final raw = m['departments'];
  if (raw is List && raw.isNotEmpty) {
    return StorageKeys.normalizeDepartments(
      raw.map((e) => e?.toString()),
    );
  }
  return StorageKeys.normalizeDepartments([m['department']?.toString()]);
}

/// منطق إعادة ربط تيّاري العملاء والمهام حسب الدور (مستخرج لتقليل حجم [HomeController]).
Future<void> homeRebindClientsAndTasksStreamsAsync(
  HomeController c,
  int gen,
) async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return;

  try {
    final roleSnap =
        await FirebaseFirestore.instance
            .collection('authRoles')
            .doc(u.uid)
            .get();
    if (gen != c._clientsTasksRebindGeneration) return;

    String? role;
    if (roleSnap.exists) {
      role = roleSnap.data()?['role']?.toString();
    }

    if (role == 'client') {
      c.clients.bindStream(c._service.getClientsStreamForCurrentAuthEmail());
      c.tasks.bindStream(Stream<List<TaskModel>>.value([]));
      homeBindLibraryFilesStream(c, false);
      homeBindLibraryBrowseTasksStream(c, false);
      c.update();
      return;
    }

    if (role == 'admin' || role == 'supervisor') {
      c.clients.bindStream(c._service.getClientsStream());
      c.tasks.bindStream(c._service.getTasks());
      homeBindLibraryFilesStream(c, true);
      homeBindLibraryBrowseTasksStream(c, true);
      c.update();
      return;
    }

    if (role == 'employee') {
      final employeeId =
          roleSnap.data()?['employeeId']?.toString().trim() ?? '';
      final departments = _departmentsFromFirestoreMap(roleSnap.data());
      final canAccessLibrary = _libraryAccessFromAuthRole(roleSnap.data());
      c.clients.bindStream(c._service.getClientsStream());
      if (employeeId.isNotEmpty) {
        c.tasks.bindStream(
          c._service.getTasksStreamForEmployee(
            employeeId: employeeId,
            departments: departments,
          ),
        );
      } else {
        c.tasks.bindStream(Stream<List<TaskModel>>.value([]));
      }
      homeBindLibraryFilesStream(c, canAccessLibrary);
      homeBindLibraryBrowseTasksStream(c, canAccessLibrary);
      c.update();
      return;
    }

    if (role != null) {
      c.clients.bindStream(c._service.getClientsStream());
      c.tasks.bindStream(c._service.getTasks());
      final canAccessLibrary = _canAccessLibraryFromRoleAndAuth(
        role: role,
        authData: roleSnap.data(),
      );
      homeBindLibraryFilesStream(c, canAccessLibrary);
      homeBindLibraryBrowseTasksStream(c, canAccessLibrary);
      c.update();
      return;
    }

    final email = u.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      c.clients.bindStream(Stream<List<ClientModel>>.value([]));
      c.tasks.bindStream(Stream<List<TaskModel>>.value([]));
      homeBindLibraryFilesStream(c, false);
      homeBindLibraryBrowseTasksStream(c, false);
      c.update();
      return;
    }

    final empByEmail =
        await FirebaseFirestore.instance
            .collection('employees')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
    if (gen != c._clientsTasksRebindGeneration) return;

    if (empByEmail.docs.isNotEmpty) {
      final empDoc = empByEmail.docs.first;
      final empData = empDoc.data();
      final empRole = empData['role']?.toString().trim() ?? '';
      final empId = empDoc.id;
      final departments = _departmentsFromFirestoreMap(empData);
      final canAccessLibrary = _canAccessLibraryFromRoleAndAuth(
        role: empRole,
        authData: empData,
      );
      c.clients.bindStream(c._service.getClientsStream());
      if (empRole == 'admin' || empRole == 'supervisor') {
        c.tasks.bindStream(c._service.getTasks());
      } else if (empRole == 'employee') {
        c.tasks.bindStream(
          c._service.getTasksStreamForEmployee(
            employeeId: empId,
            departments: departments,
          ),
        );
      } else {
        c.tasks.bindStream(c._service.getTasks());
      }
      homeBindLibraryFilesStream(c, canAccessLibrary);
      homeBindLibraryBrowseTasksStream(c, canAccessLibrary);
    } else {
      c.clients.bindStream(c._service.getClientsStreamForCurrentAuthEmail());
      c.tasks.bindStream(Stream<List<TaskModel>>.value([]));
      homeBindLibraryFilesStream(c, false);
      homeBindLibraryBrowseTasksStream(c, false);
    }
    c.update();
  } catch (e, s) {
    appLog('_rebindClientsAndTasksStreamsAsync: $e');
    appLog('$s');
    if (gen != c._clientsTasksRebindGeneration) return;
    c.clients.bindStream(c._service.getClientsStreamForCurrentAuthEmail());
    c.tasks.bindStream(Stream<List<TaskModel>>.value([]));
    homeBindLibraryFilesStream(c, false);
    homeBindLibraryBrowseTasksStream(c, false);
    c.update();
  }
}
