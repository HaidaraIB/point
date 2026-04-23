import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/attachment_download.dart';

/// Full-screen gallery for image URLs: swipe between pages, pinch-zoom,
/// keyboard ← / → (web & desktop), on-screen chevrons.
class TaskAttachmentGalleryPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const TaskAttachmentGalleryPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<TaskAttachmentGalleryPage> createState() =>
      _TaskAttachmentGalleryPageState();
}

class _TaskAttachmentGalleryPageState extends State<TaskAttachmentGalleryPage> {
  late final PageController _pageController;
  late final FocusNode _focusNode;
  late int _index;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final urls = widget.imageUrls;
    final next = (_index + delta).clamp(0, urls.length - 1);
    if (next == _index) return;
    setState(() => _index = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    if (urls.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocaleKeys.appClose.tr)),
        body: const Center(child: Text('')),
      );
    }
    const bg = Color(0xFF0A0A0F);

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${urls.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'tasks.download'.tr,
            onPressed: () => launchAttachmentDownload(urls[_index]),
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focusNode.requestFocus(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: urls.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  return _ZoomableNetworkImage(url: urls[i]);
                },
              ),
              if (urls.length > 1) ...[
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: Colors.black38,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        iconSize: 36,
                        onPressed: _index > 0 ? () => _go(-1) : null,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: Colors.black38,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        iconSize: 36,
                        onPressed:
                            _index < urls.length - 1 ? () => _go(1) : null,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinch-zoom without stealing horizontal drags from [PageView] while at ~1×.
class _ZoomableNetworkImage extends StatefulWidget {
  final String url;

  const _ZoomableNetworkImage({required this.url});

  @override
  State<_ZoomableNetworkImage> createState() => _ZoomableNetworkImageState();
}

class _ZoomableNetworkImageState extends State<_ZoomableNetworkImage> {
  final TransformationController _tc = TransformationController();
  double _scale = 1.0;

  static const double _kPanScaleThreshold = 1.06;
  static const double _kResetScale = 1.02;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final nextScale = _tc.value.getMaxScaleOnAxis();
    if (nextScale <= _kResetScale && _scale > _kResetScale) {
      _tc.removeListener(_onTransformChanged);
      _tc.value = Matrix4.identity();
      _tc.addListener(_onTransformChanged);
      setState(() => _scale = 1.0);
      return;
    }
    if ((nextScale - _scale).abs() > 0.008) {
      setState(() => _scale = nextScale);
    }
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransformChanged);
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _tc,
      panEnabled: _scale > _kPanScaleThreshold,
      scaleEnabled: true,
      minScale: 0.55,
      maxScale: 5,
      boundaryMargin: const EdgeInsets.all(48),
      child: Center(
        child: Image.network(
          widget.url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

void openTaskAttachmentGallery({
  required List<String> imageUrls,
  int initialIndex = 0,
}) {
  if (imageUrls.isEmpty) return;
  Get.to(
    () => TaskAttachmentGalleryPage(
      imageUrls: imageUrls,
      initialIndex: initialIndex,
    ),
  );
}
