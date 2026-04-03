import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/AutoLoginService.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web cold start: show loading instead of the login form while we restore
/// Firebase Auth + session (avoids users submitting login while already signed in).
class WebAuthSplashDecider extends StatefulWidget {
  const WebAuthSplashDecider({super.key});

  @override
  State<WebAuthSplashDecider> createState() => _WebAuthSplashDeciderState();
}

class _WebAuthSplashDeciderState extends State<WebAuthSplashDecider> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    if (!mounted || _navigated) return;

    final pref = await SharedPreferences.getInstance();
    final isLoggedIn = (pref.get('isLoggedIn') ?? false) == true;
    final email = (pref.get('email') ?? '').toString();

    if (!isLoggedIn || email.isEmpty) {
      _navigated = true;
      Get.offAllNamed('/auth/login');
      return;
    }

    final nextRoute = await attemptSilentLogin();

    _navigated = true;
    if (nextRoute != null && nextRoute.isNotEmpty) {
      Get.offAllNamed(nextRoute);
    } else {
      Get.offAllNamed('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
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
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
