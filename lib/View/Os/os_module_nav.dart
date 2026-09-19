import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_modules.dart';

/// Compact jump links for OS *subpages* only (not the hub).
/// Shows Hub + live modules so you can switch without going back to the grid.
class OsModuleNav extends StatefulWidget {
  const OsModuleNav({
    super.key,
    this.currentRoute,
  });

  final String? currentRoute;

  @override
  State<OsModuleNav> createState() => _OsModuleNavState();
}

class _OsModuleNavState extends State<OsModuleNav> {
  final _scrollController = ScrollController();
  final _selectedKey = GlobalKey();

  String get _active {
    final raw = widget.currentRoute ?? Get.currentRoute;
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
  void initState() {
    super.initState();
    _scheduleScrollToSelected();
  }

  @override
  void didUpdateWidget(covariant OsModuleNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) {
      _scheduleScrollToSelected();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _scrollToSelected() {
    final ctx = _selectedKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final active = _active;
    final emp = Get.find<HomeController>().effectiveEmployee;
    final modules = <OsModule>[
      if (OsPermissions.canAccessOsSection(emp)) osHubModule,
      ...OsPermissions.visibleModules(emp),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        radius: const Radius.circular(999),
        thickness: 4,
        child: SizedBox(
          height: 44,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            clipBehavior: Clip.none,
            padding: const EdgeInsetsDirectional.only(
              start: 8,
              end: 8,
              bottom: 6,
            ),
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final m = modules[index];
              final selected = m.route == active;
              return _NavPill(
                key: selected ? _selectedKey : null,
                label: m.titleKey.tr,
                icon: m.icon,
                selected: selected,
                onTap: () => _open(m),
                theme: theme,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    super.key,
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
    final fg = selected ? Colors.white : theme.primaryText;
    final bg = selected ? AppColors.primary : theme.cardSurface;
    final border = selected ? AppColors.primary : theme.border;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
