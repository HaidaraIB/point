import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/AutoLoginService.dart';
import 'package:point/View/Shared/animated_splash_screen.dart';

/// Web cold start: show loading instead of the login form while we restore
/// Firebase Auth + session (avoids users submitting login while already signed in).
class WebAuthSplashDecider extends StatefulWidget {
  const WebAuthSplashDecider({super.key});

  @override
  State<WebAuthSplashDecider> createState() => _WebAuthSplashDeciderState();
}

class _WebAuthSplashDeciderState extends State<WebAuthSplashDecider> {
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

    final nextRoute = await attemptSilentLogin();
    final deepLinkTarget = _validatedNextRoute();

    _navigated = true;
    if (nextRoute != null && nextRoute.isNotEmpty) {
      Get.offAllNamed(deepLinkTarget ?? nextRoute);
    } else {
      Get.offAllNamed('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AnimatedSplashScreen();
  }
}
