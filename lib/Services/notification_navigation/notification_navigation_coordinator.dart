import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/notification_navigation/notification_destination.dart';
import 'package:point/Services/notification_navigation/notification_destination_parser.dart';
import 'package:point/Services/notification_navigation/notification_navigator.dart';
import 'package:point/Utils/app_log.dart';

/// Queues a notification tap until auth/session is ready, then opens the UI.
class NotificationNavigationCoordinator extends GetxService {
  static NotificationDestination? _earlyPending;

  NotificationDestination? _pending;
  bool _flushing = false;
  NotificationDestination? _lastFlushed;
  DateTime? _lastFlushedAt;
  Worker? _employeeWorker;
  Worker? _clientWorker;

  /// Safe from FCM init (may run before GetX bindings).
  static void handlePayload(Map<dynamic, dynamic>? data) {
    final dest = NotificationDestinationParser.parse(data);
    if (dest == null) return;
    if (Get.isRegistered<NotificationNavigationCoordinator>()) {
      Get.find<NotificationNavigationCoordinator>().enqueue(dest);
    } else {
      _earlyPending = dest;
    }
  }

  static void scheduleFlush() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        if (!Get.isRegistered<NotificationNavigationCoordinator>()) return;
        unawaited(Get.find<NotificationNavigationCoordinator>().flushIfReady());
      });
    });
  }

  @override
  void onInit() {
    super.onInit();
    if (_earlyPending != null) {
      _pending = _earlyPending;
      _earlyPending = null;
    }
    if (Get.isRegistered<HomeController>()) {
      _employeeWorker = ever<EmployeeModel?>(
        Get.find<HomeController>().currentEmployee,
        (_) => scheduleFlush(),
      );
    }
    if (Get.isRegistered<ClientController>()) {
      _clientWorker = ever<ClientModel?>(
        Get.find<ClientController>().currentClient,
        (_) => scheduleFlush(),
      );
    }
    scheduleFlush();
  }

  @override
  void onClose() {
    _employeeWorker?.dispose();
    _clientWorker?.dispose();
    super.onClose();
  }

  void enqueue(NotificationDestination dest) {
    _pending = dest;
    scheduleFlush();
  }

  Future<void> flushIfReady() async {
    final dest = _pending;
    if (dest == null || _flushing) return;
    if (!_isSessionReady()) return;

    final now = DateTime.now();
    if (_lastFlushed == dest &&
        _lastFlushedAt != null &&
        now.difference(_lastFlushedAt!) < const Duration(seconds: 2)) {
      _pending = null;
      return;
    }

    _flushing = true;
    _pending = null;
    try {
      await NotificationNavigator.open(dest);
      _lastFlushed = dest;
      _lastFlushedAt = DateTime.now();
    } catch (e, st) {
      appLog('notification navigation failed: $e\n$st');
    } finally {
      _flushing = false;
    }
  }

  bool _isSessionReady() {
    if (!_hasSignedInUser()) return false;
    return !_isGatedRoute(Get.currentRoute);
  }

  bool _hasSignedInUser() {
    if (Get.isRegistered<HomeController>()) {
      final emp = Get.find<HomeController>().currentEmployee.value;
      if (emp != null && (emp.id ?? '').trim().isNotEmpty) return true;
    }
    if (Get.isRegistered<ClientController>()) {
      final client = Get.find<ClientController>().currentClient.value;
      if (client != null && (client.id ?? '').trim().isNotEmpty) return true;
    }
    return false;
  }

  static bool _isGatedRoute(String route) {
    final r = route.split('?').first.trim();
    if (r.isEmpty) return true;
    if (r.startsWith('/auth')) return true;
    const gated = <String>{
      '/webAuthSplash',
      '/webClientAuthSplash',
      '/mobileSplash',
      '/mobileClientSplash',
      '/forceUpdate',
      '/sessionSetup',
      '/clientSessionSetup',
    };
    return gated.contains(r);
  }
}
