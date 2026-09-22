import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_modules.dart';
import 'package:point/View/Os/os_horizontal_scroll_view.dart';
import 'package:point/View/Shared/responsive.dart';

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
    final oldRaw = oldWidget.currentRoute ?? '';
    final oldQ = oldRaw.indexOf('?');
    final oldActive = oldQ >= 0 ? oldRaw.substring(0, oldQ) : oldRaw;
    if (oldActive != _active) {
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

  void _scrollToSelected({int attempt = 0}) {
    if (!mounted || attempt > 12) return;

    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToSelected(attempt: attempt + 1),
      );
      return;
    }

    final ctx = _selectedKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToSelected(attempt: attempt + 1),
      );
      return;
    }

    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToSelected(attempt: attempt + 1),
      );
      return;
    }

    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;

    final position = _scrollController.position;
    final target = viewport.getOffsetToReveal(box, 0.5).offset;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((position.pixels - clamped).abs() < 0.5) return;

    position.animateTo(
      clamped,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
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

    final mobile = Responsive.isMobile(context);
    const pillRowHeight = 44.0;
    // Desktop/web: extra room so the horizontal thumb sits under the pills, not on them.
    final stripHeight = mobile ? pillRowHeight : pillRowHeight + 10;

    // Row (not ListView) so every pill is laid out; lazy lists skip off-screen
    // children and break scroll-to-selected via GlobalKey.
    final pillChildren = <Widget>[];
    for (var i = 0; i < modules.length; i++) {
      if (i > 0) pillChildren.add(const SizedBox(width: 8));
      final m = modules[i];
      final selected = m.route == active;
      pillChildren.add(
        _NavPill(
          key: selected ? _selectedKey : null,
          label: m.titleKey.tr,
          icon: m.icon,
          selected: selected,
          onTap: () => _open(m),
          theme: theme,
        ),
      );
    }

    final pillRow = SizedBox(
      height: stripHeight,
      child: OsHorizontalScrollView(
        controller: _scrollController,
        // Clip so scrolled pills cannot paint over the app sidebar.
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsetsDirectional.only(
          start: 4,
          end: 4,
          bottom: mobile ? 0 : 8,
        ),
        child: Row(children: pillChildren),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          pillRow,
          if (mobile) ...[
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        theme.pageBackground,
                        theme.pageBackground.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              width: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerEnd,
                      end: AlignmentDirectional.centerStart,
                      colors: [
                        theme.pageBackground,
                        theme.pageBackground.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
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
