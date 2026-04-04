import 'package:point/Utils/app_log.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Services/firebase_auth_web_hydration.dart';

/// Attempts silent login using FirebaseAuth existing session.
///
/// Returns the route name to navigate to on success, otherwise null.
Future<String?> attemptSilentLogin() async {
  await waitForFirebaseAuthHydrationOnWeb();

  final homeController = Get.find<HomeController>();
  final clientController = Get.find<ClientController>();

  final fcm = FirebaseMessaging.instance;

  final employee = await homeController.service.getCurrentEmployeeByAuth();

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
        try {
          await fcm.unsubscribeFromTopic('employees');
          await fcm.subscribeToTopic('clients');
          await fcm.subscribeToTopic('all');
        } catch (e) {
          appLog('FCM subscribe (client): $e');
        }
      }

      return '/ClientHome';
    }
    return null;
  }

  return null;
}
