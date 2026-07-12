import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:point/View/Shared/brand_logo.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Branded splash with entrance animation, used after the native launch screen.
class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key, this.useSafeArea = false});

  final bool useSafeArea;

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _loaderEntranceController;
  late final AnimationController _dotsController;
  late final Animation<double> _loaderFade;
  late final Animation<Offset> _loaderSlide;
  bool _nativeSplashRemoved = false;

  @override
  void initState() {
    super.initState();

    _loaderEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _loaderFade = CurvedAnimation(
      parent: _loaderEntranceController,
      curve: Curves.easeOut,
    );
    _loaderSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _loaderEntranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  void _startAnimation() {
    if (!mounted) return;
    if (!_nativeSplashRemoved) {
      FlutterNativeSplash.remove();
      _nativeSplashRemoved = true;
    }
    _loaderEntranceController.forward().then((_) {
      if (mounted) {
        _dotsController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _loaderEntranceController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  double _dotOpacity(int index) {
    final phase = (_dotsController.value + index * 0.22) % 1.0;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.25 + 0.75 * Curves.easeInOut.transform(wave);
  }

  @override
  Widget build(BuildContext context) {
    final logoWidth =
        kIsWeb ? min(Get.width * 0.35, 280.0) : min(Get.width * 0.45, 320.0);
    const logoHeight = kIsWeb ? 64.0 : 72.0;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandLogo(
              width: logoWidth,
              height: logoHeight,
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _loaderFade,
              child: SlideTransition(
                position: _loaderSlide,
                child: AnimatedBuilder(
                  animation: _dotsController,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Opacity(
                            opacity: _dotOpacity(index),
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: context.appTheme.accentText,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: widget.useSafeArea ? SafeArea(child: content) : content,
    );
  }
}
