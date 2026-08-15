import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/AutoLoginService.dart';
import 'package:point/Services/mobile_version_gate.dart';
import 'package:point/Services/notification_navigation/notification_navigation_coordinator.dart';
import 'package:point/View/Shared/animated_splash_screen.dart';

class MobileSplashDecider extends StatefulWidget {
  const MobileSplashDecider({super.key});

  @override
  State<MobileSplashDecider> createState() => _MobileSplashDeciderState();
}

class _MobileSplashDeciderState extends State<MobileSplashDecider> {
  bool _navigated = false;

  String? _validatedNextRoute() {
    final raw = Get.parameters['next'];
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = Uri.decodeComponent(raw).trim();
    if (!decoded.startsWith('/')) return null;
    if (decoded.startsWith('/auth') ||
        decoded.contains('Splash') ||
        decoded == '/webAuthSplash' ||
        decoded == '/mobileSplash') {
      return null;
    }
    return decoded;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    if (!mounted || _navigated) return;

    if (!kIsWeb) {
      final gate = await MobileVersionGate.evaluate();
      if (!mounted || _navigated) return;
      if (gate.blocked) {
        _navigated = true;
        Get.offAllNamed(
          '/forceUpdate',
          arguments: ForceUpdateArgs(storeUrl: gate.storeUrl),
        );
        return;
      }
    }

    final nextRoute = await attemptSilentLogin();
    final deepLinkTarget = _validatedNextRoute();

    _navigated = true;
    if (nextRoute != null && nextRoute.isNotEmpty) {
      Get.offAllNamed(deepLinkTarget ?? nextRoute);
    } else {
      Get.offAllNamed('/auth/ChooseUserType');
    }
    NotificationNavigationCoordinator.scheduleFlush();
  }

  @override
  Widget build(BuildContext context) {
    return const AnimatedSplashScreen(useSafeArea: true);
  }
}

