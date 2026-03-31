import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';

/// Attempts silent login using FirebaseAuth existing session.
///
/// Returns the route name to navigate to on success, otherwise null.
Future<String?> attemptSilentLogin() async {
  final homeController = Get.find<HomeController>();
  final clientController = Get.find<ClientController>();

  final fcm = FirebaseMessaging.instance;

  final employee = await homeController.service.getCurrentEmployeeByAuth();

  if (employee != null) {
    log("✅ تم تسجيل دخول الموظف: ${employee.email}");
    if (employee.status == 'active') {
      try {
        await homeController.setupFCM(employee.id);
      } catch (e) {
        log('FCM setup: $e');
      }

      if (!kIsWeb) {
        try {
          await fcm.subscribeToTopic('all');
          await fcm.unsubscribeFromTopic('clients');
          await fcm.subscribeToTopic('employees');
        } catch (e) {
          log('FCM subscribe (employee): $e');
        }
      }

      homeController.fetchNotification(employee.id);
      homeController.listenToClient(employee.id!);

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
      log('attemptSilentLogin: getCurrentClientByAuth permission-denied');
    } else {
      log('attemptSilentLogin: getCurrentClientByAuth $e');
    }
    client = null;
  } catch (e, s) {
    log('attemptSilentLogin: getCurrentClientByAuth $e');
    log('$s');
    client = null;
  }

  if (client != null) {
    log("✅ تم تسجيل دخول العميل: ${client.email}");
    if (client.status == 'active') {
      clientController.listenToClient(client.id!);

      if (!kIsWeb) {
        try {
          await fcm.unsubscribeFromTopic('employees');
          await fcm.subscribeToTopic('clients');
          await fcm.subscribeToTopic('all');
        } catch (e) {
          log('FCM subscribe (client): $e');
        }
      }

      return '/ClientHome';
    }
    return null;
  }

  return null;
}
