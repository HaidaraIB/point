import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_modules.dart';

/// Compact jump links for OS *subpages* only (not the hub).
/// Shows Hub + live modules so you can switch without going back to the grid.
class OsModuleNav extends StatelessWidget {
  const OsModuleNav({
    super.key,
    this.currentRoute,
  });

  final String? currentRoute;

  String get _active {
    final raw = currentRoute ?? Get.currentRoute;
    final q = raw.indexOf('?');
    return q >= 0 ? raw.substring(0, q) : raw;
  }

  void _open(OsModule module) {
    final route = module.route;
    if (route == null || route.isEmpty) return;
    if (_active == route) return;
    Get.offNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final active = _active;
    // Hub + live modules only — no coming-soon clutter / clipping.
    final modules = <OsModule>[
      osHubModule,
      ...osModules.where((m) => m.isLive),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in modules)
              _NavPill(
                label: m.titleKey.tr,
                icon: m.icon,
                selected: m.route == active,
                onTap: () => _open(m),
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final AppThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : theme.cardSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : theme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : theme.primaryText,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : theme.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
