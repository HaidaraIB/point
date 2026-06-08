import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/AutoLoginService.dart';
import 'package:point/View/Shared/animated_splash_screen.dart';

/// Web cold start for client auth: restore session, then client session setup or login.
class WebClientAuthSplashDecider extends StatefulWidget {
  const WebClientAuthSplashDecider({super.key});

  @override
  State<WebClientAuthSplashDecider> createState() =>
      _WebClientAuthSplashDeciderState();
}

class _WebClientAuthSplashDeciderState extends State<WebClientAuthSplashDecider> {
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
  }

  @override
  Widget build(BuildContext context) {
    return const AnimatedSplashScreen();
  }
}
