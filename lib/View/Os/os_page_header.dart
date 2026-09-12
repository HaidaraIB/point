import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_module_nav.dart';

/// Shared header for OS sub-routes: back to `/os` + title + optional actions.
class OsPageHeader extends StatelessWidget {
  const OsPageHeader({
    super.key,
    required this.title,
    this.actions,
    this.subtitle,
    this.showModuleNav = true,
    this.currentRoute,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  /// Horizontal OS module jump links under the title row.
  final bool showModuleNav;

  /// Highlighted nav route; defaults to [Get.currentRoute].
  final String? currentRoute;

  void _goBackToOs() {
    if (Get.previousRoute == '/os') {
      Get.back();
      return;
    }
    Get.offNamed('/os');
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                tooltip: AppLocaleKeys.osBackToHub.tr,
                onPressed: _goBackToOs,
                // arrow_back mirrors automatically in RTL (points right in Arabic).
                icon: Icon(Icons.arrow_back, size: 26, color: theme.primaryText),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
        if (showModuleNav) OsModuleNav(currentRoute: currentRoute),
      ],
    );
  }
}
