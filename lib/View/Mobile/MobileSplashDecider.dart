import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/AutoLoginService.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MobileSplashDecider extends StatefulWidget {
  const MobileSplashDecider({super.key});

  @override
  State<MobileSplashDecider> createState() => _MobileSplashDeciderState();
}

class _MobileSplashDeciderState extends State<MobileSplashDecider> {
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
    final password = (pref.get('password') ?? '').toString();

    if (!isLoggedIn || email.isEmpty || password.isEmpty) {
      _navigated = true;
      Get.offAllNamed('/auth/ChooseUserType');
      return;
    }

    final nextRoute = await attemptSilentLogin(
      email: email,
      password: password,
    );

    _navigated = true;
    if (nextRoute != null && nextRoute.isNotEmpty) {
      Get.offAllNamed(nextRoute);
    } else {
      Get.offAllNamed('/auth/ChooseUserType');
    }
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
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

