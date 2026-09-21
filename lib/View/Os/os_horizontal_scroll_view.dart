import 'package:flutter/material.dart';
import 'package:point/View/Shared/responsive.dart';

/// Thin bottom scrollbar matching [OsModuleNav] (desktop/web only).
class OsThinHorizontalScrollbar extends StatelessWidget {
  const OsThinHorizontalScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final scrollChild = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    );

    if (mobile) return scrollChild;

    return Scrollbar(
      controller: controller,
      thumbVisibility: false,
      interactive: true,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      radius: const Radius.circular(999),
      thickness: 4,
      child: scrollChild,
    );
  }
}

/// Horizontal [SingleChildScrollView] with OS-standard thin scrollbar.
class OsHorizontalScrollView extends StatelessWidget {
  const OsHorizontalScrollView({
    super.key,
    required this.controller,
    required this.child,
    this.padding,
    this.physics,
    this.clipBehavior = Clip.hardEdge,
  });

  final ScrollController controller;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final scrollView = SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      physics: physics ??
          const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
      clipBehavior: clipBehavior,
      padding: padding,
      child: child,
    );

    return OsThinHorizontalScrollbar(
      controller: controller,
      child: scrollView,
    );
  }
}

/// Owns a [ScrollController] for a horizontal scroller (tabs, chips, etc.).
class OsHorizontalScrollContainer extends StatefulWidget {
  const OsHorizontalScrollContainer({
    super.key,
    required this.builder,
    this.padding,
    this.physics,
    this.clipBehavior = Clip.hardEdge,
    this.height,
  });

  final Widget Function(ScrollController controller) builder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Clip clipBehavior;
  final double? height;

  @override
  State<OsHorizontalScrollContainer> createState() =>
      _OsHorizontalScrollContainerState();
}

class _OsHorizontalScrollContainerState extends State<OsHorizontalScrollContainer> {
  late final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scroll = OsHorizontalScrollView(
      controller: _controller,
      padding: widget.padding,
      physics: widget.physics,
      clipBehavior: widget.clipBehavior,
      child: widget.builder(_controller),
    );

    if (widget.height == null) return scroll;
    return SizedBox(height: widget.height, child: scroll);
  }
}

/// Wraps a scrollable [TabBar] with the OS thin horizontal scrollbar.
class OsTabBarScrollContainer extends StatefulWidget {
  const OsTabBarScrollContainer({super.key, required this.tabBarBuilder});

  final TabBar Function(TabBarScrollController scrollController) tabBarBuilder;

  @override
  State<OsTabBarScrollContainer> createState() =>
      _OsTabBarScrollContainerState();
}

class _OsTabBarScrollContainerState extends State<OsTabBarScrollContainer> {
  late final TabBarScrollController _controller = TabBarScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OsThinHorizontalScrollbar(
      controller: _controller,
      child: widget.tabBarBuilder(_controller),
    );
  }
}
