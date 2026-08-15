import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/AutoLoginService.dart';
import 'package:point/Services/mobile_version_gate.dart';
import 'package:point/Services/notification_navigation/notification_navigation_coordinator.dart';
import 'package:point/View/Shared/animated_splash_screen.dart';

/// Mobile cold start for client auth: restore session, then client session setup or login.
class MobileClientSplashDecider extends StatefulWidget {
  const MobileClientSplashDecider({super.key});

  @override
  State<MobileClientSplashDecider> createState() =>
      _MobileClientSplashDeciderState();
}

class _MobileClientSplashDeciderState extends State<MobileClientSplashDecider> {
  bool _navigated = false;

  String? _validatedNextRoute() {
    final raw = Get.parameters['next'];
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = Uri.decodeComponent(raw).trim();
    if (!decoded.startsWith('/')) return null;
    if (decoded.startsWith('/auth') ||
        decoded.contains('Splash') ||
        decoded == '/clientSessionSetup' ||
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
          arguments: ForceUpdateArgs(
            storeUrl: gate.storeUrl,
            returnSplashRoute: '/mobileClientSplash',
          ),
        );
        return;
      }
    }

    final nextRoute = await attemptSilentLogin();
    final deepLinkTarget = _validatedNextRoute();

    _navigated = true;
    if (nextRoute == '/clientSessionSetup' || nextRoute == '/ClientHome') {
      if (deepLinkTarget != null && deepLinkTarget.isNotEmpty) {
        Get.offAllNamed(
          '/clientSessionSetup?next=${Uri.encodeComponent(deepLinkTarget)}',
        );
      } else {
        Get.offAllNamed('/clientSessionSetup');
      }
    } else {
      Get.offAllNamed('/auth/LoginUserAccount');
    }
    NotificationNavigationCoordinator.scheduleFlush();
  }

  @override
  Widget build(BuildContext context) {
    return const AnimatedSplashScreen(useSafeArea: true);
  }
}
