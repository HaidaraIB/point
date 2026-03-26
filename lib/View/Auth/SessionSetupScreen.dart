import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppImages.dart';

/// Shown immediately after valid employee login while prefs, FCM topics, and
/// token setup complete (avoids idle login button between auth and navigation).
class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  bool _started = false;

  String _compactErrorCode(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('apns') || raw.contains('fcm')) return 'FCM_SETUP_FAILED';
    if (raw.contains('network') || raw.contains('socket'))
      return 'NETWORK_UNAVAILABLE';
    return 'SESSION_SETUP_FAILED';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) return;
      _started = true;
      _bootstrap();
    });
  }

  String _destinationForRole(String role) {
    if (role == 'employee') return '/employeeDashboard';
    return '/';
  }

  Future<void> _applyTopicSubscriptions(String role) async {
    if (kIsWeb) return;
    final fcm = FirebaseMessaging.instance;
    await fcm.subscribeToTopic('all');
    if (role == 'supervisor' || role == 'employee') {
      await fcm.unsubscribeFromTopic('clients');
      await fcm.subscribeToTopic('employees');
    }
  }

  Future<void> _bootstrap() async {
    final hc = Get.find<HomeController>();
    final v = hc.currentemployee.value ?? hc.lastKnownEmployee.value;

    if (v == null ||
        v.id == null ||
        v.id!.isEmpty ||
        v.status != 'active') {
      Get.offAllNamed('/auth/login');
      return;
    }

    final email = (v.email ?? '').trim();
    if (email.isEmpty) {
      log('SessionSetup: missing employee email');
      await _abortSetup(hc);
      return;
    }

    try {
      await FunHelper.saveLoginData(email);
    } catch (e, st) {
      final code = 'SESSION_SAVE_LOGIN_DATA_FAILED';
      log(
        'SessionSetup critical step failed while saving login data: '
        'type=${e.runtimeType}, message=$e, code=$code, platform=${defaultTargetPlatform.name}',
        stackTrace: st,
      );
      await FirestoreServices.logClientDiagnosticError(
        source: 'SessionSetupScreen._bootstrap.saveLoginData',
        code: code,
        error: e,
        stackTrace: st,
        extra: {
          'platform': defaultTargetPlatform.name,
          'isWeb': kIsWeb,
          'employeeId': v.id,
          'email': email,
        },
      );
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.errorGeneric.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      await _abortSetup(hc);
      return;
    }

    try {
      await hc.setupFCM(v.id);
      await _applyTopicSubscriptions(v.role);
    } catch (e, st) {
      final code = _compactErrorCode(e);
      log(
        'SessionSetup non-critical push setup failed: '
        'type=${e.runtimeType}, message=$e, code=$code, platform=${defaultTargetPlatform.name}',
        stackTrace: st,
      );
      await FirestoreServices.logClientDiagnosticError(
        source: 'SessionSetupScreen._bootstrap.pushSetup',
        code: code,
        error: e,
        stackTrace: st,
        extra: {
          'platform': defaultTargetPlatform.name,
          'isWeb': kIsWeb,
          'employeeId': v.id,
          'email': email,
          'role': v.role,
        },
      );
      FunHelper.showSnackbar(
        'error'.tr,
        '${AppLocaleKeys.errorGeneric.tr} ($code)',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }

    final next = _destinationForRole(v.role);
    Get.offAllNamed(next);
  }

  Future<void> _abortSetup(HomeController hc) async {
    hc.clearEmployeeSession();
    FunHelper.removeLoginData();
    try {
      await FirestoreServices().signOut();
    } catch (_) {}
    Get.offAllNamed('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AppImages.images.logocolored,
                  width: Get.width * 0.55,
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  AppLocaleKeys.authPreparingSession.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
