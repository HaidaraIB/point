import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Horizontal scrollable area with a visible scrollbar (on web).
/// Use for attachments row so users can drag the scrollbar.
class HorizontalScrollbarAttachments extends StatefulWidget {
  const HorizontalScrollbarAttachments({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<HorizontalScrollbarAttachments> createState() =>
      _HorizontalScrollbarAttachmentsState();
}

class _HorizontalScrollbarAttachmentsState
    extends State<HorizontalScrollbarAttachments> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: kIsWeb,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
  }
}
