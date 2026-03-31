import 'package:flutter/material.dart';

class Responsive extends StatelessWidget {
  final Widget? mobile;
  final Widget? tablet;
  final Widget desktop;

  /// Below this width, [mobile] is used (when not null). Default 850.
  /// Use a lower value (e.g. 600) on web when a wide data table should replace card layout sooner.
  final double mobileBreakpoint;

  const Responsive({
    Key? key,
    this.mobile,
    this.tablet,
    required this.desktop,
    this.mobileBreakpoint = 850,
  }) : super(key: key);

  // This size work fine on my design, maybe you need some customization depends on your design

  // This isMobile, isTablet, isDesktop help us later
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 850;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width < 1100 &&
      MediaQuery.of(context).size.width >= 850;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  /// Min width for auth screens that show a side cover + form (e.g. login).
  static const double authSplitMinWidth = 1280;

  static bool showAuthSplitLayout(double layoutWidth) =>
      layoutWidth >= authSplitMinWidth;

  /// Flex ratio for branding cover vs form in split auth layouts (narrower than 50/50).
  /// 2:5 is roughly 29% cover, 71% form.
  static const int authSplitCoverFlex = 2;
  static const int authSplitFormFlex = 5;

  @override
  Widget build(BuildContext context) {
    final Size _size = MediaQuery.of(context).size;
    // If our width is more than 1100 then we consider it a desktop
    if (_size.width >= 1100) {
      return desktop;
    }
    // If width it less then 1100 and more then [mobileBreakpoint] we consider it as tablet
    else if (_size.width >= mobileBreakpoint) {
      return tablet ?? desktop;
    }
    // Or less then that we called it mobile
    else {
      return mobile ?? desktop;
    }
  }
}
