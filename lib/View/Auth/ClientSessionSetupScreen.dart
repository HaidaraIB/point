import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Shared/brand_logo.dart';
import 'package:point/Utils/app_log.dart';

/// Shown after successful client auth while local session and push setup finish.
class ClientSessionSetupScreen extends StatefulWidget {
  const ClientSessionSetupScreen({super.key});

  @override
  State<ClientSessionSetupScreen> createState() =>
      _ClientSessionSetupScreenState();
}

class _ClientSessionSetupScreenState extends State<ClientSessionSetupScreen> {
  bool _started = false;

  String? _validatedNextRoute() {
    final raw = Get.parameters['next'];
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = Uri.decodeComponent(raw).trim();
    if (!decoded.startsWith('/')) return null;
    if (decoded.startsWith('/auth') ||
        decoded.contains('Splash') ||
        decoded == '/clientSessionSetup') {
      return null;
    }
    return decoded;
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

  void _navigateAfterFrame(String route) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        if (!mounted) return;
        Get.offAllNamed(route);
      });
    });
  }

  Future<void> _bootstrap() async {
    final cc = Get.find<ClientController>();
    var client = cc.currentClient.value;

    if (client == null) {
      try {
        final restored = await cc.service.getCurrentClientByAuth();
        if (restored != null) {
          cc.currentClient.value = restored;
          cc.listenToClient(restored.id ?? '');
          client = restored;
        }
      } catch (e, st) {
        appLog('ClientSessionSetup restore failed: $e', stackTrace: st);
      }
    }

    if (client == null ||
        (client.id ?? '').trim().isEmpty ||
        client.status != 'active') {
      await _abortSetup();
      return;
    }

    final email = (client.email ?? '').trim();
    if (email.isEmpty) {
      await _abortSetup();
      return;
    }

    try {
      await FunHelper.saveLoginData(email);
    } catch (e, st) {
      appLog('ClientSessionSetup saveLoginData failed: $e', stackTrace: st);
      await _abortSetup();
      return;
    }

    cc.listenToClient(client.id!);
    cc.fetchContents();
    Get.find<HomeController>().fetchNotification(client.id);

    if (!kIsWeb) {
      final fcm = FirebaseMessaging.instance;
      try {
        await fcm.unsubscribeFromTopic('employees');
        await fcm.subscribeToTopic('clients');
        await fcm.subscribeToTopic('all');
      } catch (e, st) {
        appLog('ClientSessionSetup FCM setup failed: $e', stackTrace: st);
      }
    }

    _navigateAfterFrame(_validatedNextRoute() ?? '/ClientHome');
  }

  Future<void> _abortSetup() async {
    final cc = Get.find<ClientController>();
    cc.currentClient.value = null;
    FunHelper.removeLoginData();
    try {
      await FirestoreServices().signOut();
    } catch (_) {}
    _navigateAfterFrame('/auth/LoginUserAccount');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BrandLogo(
                  width: Get.width * 0.55,
                  height: 80,
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  AppLocaleKeys.authPreparingSession.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.appTheme.mutedText,
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
