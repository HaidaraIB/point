import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'html_email_preview_fallback.dart';

/// Native HTML preview via WebView — created lazily after the first frame.
class HtmlEmailPreviewImpl extends StatefulWidget {
  const HtmlEmailPreviewImpl({super.key, required this.html});

  final String html;

  @override
  State<HtmlEmailPreviewImpl> createState() => _HtmlEmailPreviewImplState();
}

class _HtmlEmailPreviewImplState extends State<HtmlEmailPreviewImpl> {
  WebViewController? _controller;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
  }

  Future<void> _initController() async {
    if (!mounted || _controller != null || _failed) return;
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xFFF2F3F5));
      await controller.loadHtmlString(widget.html, baseUrl: 'about:blank');
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('HtmlEmailPreviewImpl WebView init failed: $e\n$st');
      }
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(HtmlEmailPreviewImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html && _controller != null) {
      _controller!.loadHtmlString(widget.html, baseUrl: 'about:blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return HtmlEmailPreviewFallback(html: widget.html);
    }
    if (_controller == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return WebViewWidget(controller: _controller!);
  }
}
