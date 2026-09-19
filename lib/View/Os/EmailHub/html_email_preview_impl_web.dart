import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class HtmlEmailPreviewImpl extends StatefulWidget {
  const HtmlEmailPreviewImpl({super.key, required this.html});

  final String html;

  @override
  State<HtmlEmailPreviewImpl> createState() => _HtmlEmailPreviewImplState();
}

class _HtmlEmailPreviewImplState extends State<HtmlEmailPreviewImpl> {
  late final String _viewType;
  web.HTMLIFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _viewType =
        'point-email-preview-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      _iframe = web.HTMLIFrameElement()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#F2F3F5';
      _iframe!.setAttribute('srcdoc', widget.html);
      return _iframe!;
    });
  }

  @override
  void didUpdateWidget(HtmlEmailPreviewImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _iframe?.setAttribute('srcdoc', widget.html);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 520,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
