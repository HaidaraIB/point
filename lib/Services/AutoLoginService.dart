import 'package:point/Utils/app_log.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Services/firebase_auth_web_hydration.dart';

/// Attempts silent login using FirebaseAuth existing session.
///
/// Returns the route name to navigate to on success, otherwise null.
Future<String?> attemptSilentLogin({bool allowRetry = true}) async {
  await waitForFirebaseAuthHydrationOnWeb();

  final homeController = Get.find<HomeController>();
  final clientController = Get.find<ClientController>();

  EmployeeModel? employee;
  try {
    employee = await homeController.service.getCurrentEmployeeByAuth();
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      appLog('attemptSilentLogin: getCurrentEmployeeByAuth permission-denied');
    } else {
      appLog('attemptSilentLogin: getCurrentEmployeeByAuth $e');
    }
    employee = null;
  } catch (e, s) {
    appLog('attemptSilentLogin: getCurrentEmployeeByAuth $e');
    appLog('$s');
    employee = null;
  }

  if (employee != null) {
    appLog("✅ تم تسجيل دخول الموظف: ${employee.email}");
    if (employee.status == 'active') {
      homeController.applyEmployeeSessionAfterAuthRestore(employee);

      if (!kIsWeb) {
        try {
          await homeController.setupFCM(employee.id);
        } catch (e) {
          appLog('FCM setup: $e');
        }
      }

      if (!kIsWeb) {
        final fcm = FirebaseMessaging.instance;
        try {
          await fcm.subscribeToTopic('all');
          await fcm.unsubscribeFromTopic('clients');
          await fcm.subscribeToTopic('employees');
        } catch (e) {
          appLog('FCM subscribe (employee): $e');
        }
      }

      final role = employee.role;
      if (role == 'employee') return '/employeeDashboard';
      if (role == 'supervisor' || role == 'admin') {
        return '/';
      }
      return '/';
    }
    return null;
  }

  ClientModel? client;
  try {
    client = await clientController.service.getCurrentClientByAuth();
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      appLog('attemptSilentLogin: getCurrentClientByAuth permission-denied');
    } else {
      appLog('attemptSilentLogin: getCurrentClientByAuth $e');
    }
    client = null;
  } catch (e, s) {
    appLog('attemptSilentLogin: getCurrentClientByAuth $e');
    appLog('$s');
    client = null;
  }

  if (client != null) {
    appLog("✅ تم تسجيل دخول العميل: ${client.email}");
    if (client.status == 'active') {
      clientController.currentClient.value = client;
      clientController.fetchClients();
      clientController.listenToClient(client.id!);
      clientController.fetchContents();

      if (!kIsWeb) {
        final fcm = FirebaseMessaging.instance;
        try {
          await fcm.unsubscribeFromTopic('employees');
          await fcm.subscribeToTopic('clients');
          await fcm.subscribeToTopic('all');
        } catch (e) {
          appLog('FCM subscribe (client): $e');
        }
      }

      return '/clientSessionSetup';
    }
    return null;
  }

  // On some cold starts, Firestore auth checks can race token/claims readiness.
  // Retry once shortly before declaring user as signed out.
  if (allowRetry && FirebaseAuth.instance.currentUser != null) {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return attemptSilentLogin(allowRetry: false);
  }

  return null;
}
