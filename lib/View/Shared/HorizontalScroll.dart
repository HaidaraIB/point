import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps [child] in a horizontal Scrollbar with a shared ScrollController
/// on desktop/web. On Android and iOS the scrollbar is hidden (scroll still works).
///
/// When the parent gives a finite height (e.g. [Expanded]), the child is
/// scrolled vertically inside that viewport so the horizontal scrollbar stays
/// visible at the bottom of the screen instead of at the end of a tall table.
class HorizontalScrollbarTable extends StatefulWidget {
  final Widget child;
  const HorizontalScrollbarTable({super.key, required this.child});

  @override
  State<HorizontalScrollbarTable> createState() =>
      _HorizontalScrollbarTableState();
}

class _HorizontalScrollbarTableState extends State<HorizontalScrollbarTable> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pinHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : null;

        Widget content = widget.child;
        if (pinHeight != null) {
          Widget verticalBody = SingleChildScrollView(
            controller: _verticalController,
            child: widget.child,
          );
          if (!_isMobile) {
            verticalBody = Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: verticalBody,
            );
          }
          content = SizedBox(height: pinHeight, child: verticalBody);
        }

        final scrollView = SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: content,
        );
        if (_isMobile) {
          return scrollView;
        }
        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: scrollView,
        );
      },
    );
  }
}

class HorizontalDragScroll extends StatefulWidget {
  final Widget child;
  const HorizontalDragScroll({super.key, required this.child});

  @override
  State<HorizontalDragScroll> createState() => _HorizontalDragScrollState();
}

class _HorizontalDragScrollState extends State<HorizontalDragScroll> {
  final ScrollController _controller = ScrollController();
  double _dragStartX = 0.0;
  double _scrollStartX = 0.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _dragStartX = event.position.dx;
        _scrollStartX = _controller.offset;
      },
      onPointerMove: (event) {
        final delta = _dragStartX - event.position.dx;
        _controller.jumpTo(
          (_scrollStartX + delta).clamp(
            0.0,
            _controller.position.maxScrollExtent,
          ),
        );
      },
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
  }
}
