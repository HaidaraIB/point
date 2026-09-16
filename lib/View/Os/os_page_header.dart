import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppFonts.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_module_nav.dart';
import 'package:point/View/Os/os_settings_gear_button.dart';

/// Shared header for OS sub-routes: back to `/os` + title + optional actions.
class OsPageHeader extends StatelessWidget {
  const OsPageHeader({
    super.key,
    required this.title,
    this.actions,
    this.subtitle,
    this.showModuleNav = true,
    this.showSettingsGear = true,
    this.currentRoute,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  /// Horizontal OS module jump links under the title row.
  final bool showModuleNav;

  /// Highlighted nav route; defaults to [Get.currentRoute].
  final String? currentRoute;

  /// Gear shortcut to `/os/settings` on the far side of the title row.
  final bool showSettingsGear;

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
    final width = MediaQuery.sizeOf(context).width;
    final stackActions = width < 900 && (actions?.isNotEmpty ?? false);

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Appfonts.text(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: theme.primaryText,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Appfonts.text(
              fontSize: 14,
              color: theme.secondaryText,
            ),
          ),
        ],
      ],
    );

    final actionsRow = actions == null
        ? null
        : Wrap(
            // End = far side (left in RTL, right in LTR).
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: actions!,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
          child: stackActions
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: AppLocaleKeys.osBackToHub.tr,
                          onPressed: _goBackToOs,
                          icon: Icon(
                            Icons.arrow_back,
                            size: 26,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: titleBlock),
                        if (showSettingsGear) const OsSettingsGearButton(),
                      ],
                    ),
                    if (actionsRow != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: actionsRow,
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: AppLocaleKeys.osBackToHub.tr,
                      onPressed: _goBackToOs,
                      icon: Icon(
                        Icons.arrow_back,
                        size: 26,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: titleBlock),
                    if (showSettingsGear) const OsSettingsGearButton(),
                    if (actionsRow != null) ...[
                      const SizedBox(width: 16),
                      actionsRow,
                    ],
                  ],
                ),
        ),
        if (showModuleNav) OsModuleNav(currentRoute: currentRoute),
      ],
    );
  }
}
