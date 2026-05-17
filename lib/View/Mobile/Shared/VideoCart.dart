import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Utils/chat_video_controller.dart';
import 'package:point/Utils/media_preview_cached_image.dart';
import 'package:point/Utils/media_preview_download.dart';
import 'package:point/View/Mobile/Shared/PdfViewr.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:dots_indicator/dots_indicator.dart';

class VideoCard extends StatelessWidget {
  final ContentModel model;
  VideoCard({required this.model});
  // const VideoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: Get.width,
        margin: EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ClipRRect(
            //   borderRadius: BorderRadius.circular(12),
            //   child: Stack(
            //     alignment: Alignment.center,
            //     children: [
            //       Container(
            //         height: 160,
            //         width: double.infinity,
            //         color: Colors.grey[300],
            //       ),
            //       Icon(
            //         Icons.file_copy_outlined,
            //         size: 60,
            //         color: Colors.white70,
            //       ),

            //       Positioned(
            //         left: 8,
            //         bottom: 8,
            //         child: Container(
            //           height: 4,
            //           width: 120,
            //           decoration: BoxDecoration(
            //             color: Colors.white54,
            //             borderRadius: BorderRadius.circular(2),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            FilesPreviewWidget(files: model.files?.cast<String>() ?? []),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'title'.tr,
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 4),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                model.title,
                textAlign: TextAlign.start,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ),

            const SizedBox(height: 12),
            if (model.notes != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'notes'.tr,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                model.notes ?? '',
                textAlign: TextAlign.start,
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

String getFileType(String url) {
  final lowerUrl = url.toLowerCase();
  if (lowerUrl.endsWith('.jpg') ||
      lowerUrl.endsWith('.jpeg') ||
      lowerUrl.endsWith('.png') ||
      lowerUrl.endsWith('.gif') ||
      lowerUrl.endsWith('.webp')) {
    return 'image';
  } else if (lowerUrl.endsWith('.mp4') ||
      lowerUrl.endsWith('.mov') ||
      lowerUrl.endsWith('.avi') ||
      lowerUrl.endsWith('.mkv')) {
    return 'video';
  } else if (lowerUrl.endsWith('.pdf')) {
    return 'pdf';
  } else {
    return 'unknown';
  }
}

Widget buildFilePreview(String url) {
  final type = getFileType(url);

  switch (type) {
    case 'image':
      return InkWell(
        onTap: () {
          Get.to(() => ImagePreviewPage(url: url));
        },
        child: Image.network(url, fit: BoxFit.cover),
      );

    case 'video':
      return InkWell(
        onTap: () {
          Get.to(() => VideoPlayerPage(url: url));
        },
        child: const Icon(
          Icons.play_circle_fill,
          color: Colors.deepPurple,
          size: 52,
        ),
      );

    case 'pdf':
      return InkWell(
        onTap: () {
          Get.to(() => PdfViewerPage(url: url));
        },
        child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 48),
      );

    default:
      return InkWell(
        onTap: () {
          Get.to(() => UnknownFilePage(url: url));
        },
        child: const Icon(
          Icons.insert_drive_file,
          color: Colors.grey,
          size: 46,
        ),
      );
  }
}

class ImagePreviewPage extends StatelessWidget {
  final String url;
  const ImagePreviewPage({super.key, required this.url});

  static const _bg = Color(0xFF0A0A0F);

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.9),
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        leading: IconButton(
          onPressed: () => Get.back(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.close_rounded, size: 22),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
        title: Text(
          AppLocaleKeys.chatPreviewImageTitle.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          MediaPreviewDownloadButton(url: url),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.55,
              maxScale: 5,
              boundaryMargin: const EdgeInsets.all(72),
              clipBehavior: Clip.none,
              child: Center(
                child: MediaPreviewCachedImage(url: url),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18 + bottomSafe,
            child: Text(
              AppLocaleKeys.chatPreviewPinchHint.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String url;
  const VideoPlayerPage({super.key, required this.url});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _failed = false;
  /// أثناء السحب على شريط التقدم؛ يمنع تعارض التحديث مع موضع المشغّل.
  double? _scrubFraction;

  static String _fmtTime(Duration d) {
    if (d < Duration.zero) d = Duration.zero;
    final sec = d.inSeconds;
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onVideoTick() {
    if (!mounted || _scrubFraction != null) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final c = await chatVideoControllerForUrl(widget.url);
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_onVideoTick);
      _controller = c;
      await c.initialize();
      if (!mounted) return;
      setState(() => _isReady = true);
      await c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  Duration get _effectivePosition {
    final ctrl = _controller;
    if (ctrl == null) return Duration.zero;
    final total = ctrl.value.duration;
    if (_scrubFraction != null && total.inMilliseconds > 0) {
      return Duration(
        milliseconds:
            (_scrubFraction!.clamp(0.0, 1.0) * total.inMilliseconds).round(),
      );
    }
    return ctrl.value.position;
  }

  double get _sliderValue {
    final ctrl = _controller;
    if (ctrl == null) return 0;
    final total = ctrl.value.duration;
    if (total.inMilliseconds <= 0) return 0;
    if (_scrubFraction != null) return _scrubFraction!.clamp(0.0, 1.0);
    final p = ctrl.value.position.inMilliseconds / total.inMilliseconds;
    return p.clamp(0.0, 1.0);
  }

  Widget _buildSeekRow(BuildContext context) {
    final ctrl = _controller!;
    final total = ctrl.value.duration;
    final timeStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.92),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 5,
        trackShape: const RoundedRectSliderTrackShape(),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 8,
          elevation: 3,
          pressedElevation: 5,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
        activeTrackColor: const Color(0xff00A389),
        inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
        thumbColor: Colors.white,
        overlayColor: const Color(0xff00A389).withValues(alpha: 0.28),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: _sliderValue,
        onChangeStart: (_) {
          final t = ctrl.value.duration;
          double frac = 0;
          if (t.inMilliseconds > 0) {
            frac =
                (ctrl.value.position.inMilliseconds / t.inMilliseconds)
                    .clamp(0.0, 1.0);
          }
          setState(() => _scrubFraction = frac);
        },
        onChanged: (v) => setState(() => _scrubFraction = v),
        onChangeEnd: (v) {
          final t = ctrl.value.duration;
          if (t.inMilliseconds > 0) {
            ctrl.seekTo(
              Duration(milliseconds: (v * t.inMilliseconds).round()),
            );
          }
          setState(() => _scrubFraction = null);
        },
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(_fmtTime(_effectivePosition), style: timeStyle),
        ),
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: slider,
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            _fmtTime(total),
            style: timeStyle,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.9),
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        leading: IconButton(
          onPressed: () => Get.back(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.close_rounded, size: 22),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
        title: Text(
          AppLocaleKeys.chatPreviewVideoTitle.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          MediaPreviewDownloadButton(url: widget.url),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child:
            _failed
                ? Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_off_outlined,
                        size: 52,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocaleKeys.chatPreviewVideoFailed.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
                : !_isReady
                ? SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                )
                : AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned.fill(child: VideoPlayer(_controller!)),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                              10,
                              32,
                              10,
                              8 + bottomSafe,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.88),
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildSeekRow(context),
                                IconButton(
                                  iconSize: 52,
                                  onPressed: () async {
                                    final c = _controller!;
                                    if (c.value.isPlaying) {
                                      await c.pause();
                                    } else {
                                      await c.play();
                                    }
                                    if (mounted) setState(() {});
                                  },
                                  icon: Icon(
                                    _controller!.value.isPlaying
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.play_circle_fill_rounded,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        blurRadius: 12,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}

class UnknownFilePage extends StatelessWidget {
  final String url;
  const UnknownFilePage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5C5589),
        title: const Text(
          'عرض الملف',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'لا يمكن عرض هذا الملف داخل التطبيق',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C5589),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.open_in_new, color: Colors.white),
              label: const Text(
                'فتح الملف',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {});
        controller.play();
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return controller.value.isInitialized
        ? VideoPlayer(controller)
        : const Center(child: CircularProgressIndicator());
  }
}

class FilesPreviewWidget extends StatefulWidget {
  final List<String> files;

  const FilesPreviewWidget({super.key, required this.files});

  @override
  State<FilesPreviewWidget> createState() => _FilesPreviewWidgetState();
}

class _FilesPreviewWidgetState extends State<FilesPreviewWidget> {
  double currentIndexPage = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView(
            scrollDirection: Axis.horizontal,
            onPageChanged: (index) {
              setState(() {
                currentIndexPage = index.toDouble();
              });
            },
            children: [
              for (var url in widget.files)
                Container(
                  height: 150,
                  width: Get.width - 100,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.grey.shade200, blurRadius: 5),
                    ],
                  ),
                  child: buildFilePreview(url),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DotsIndicator(
          dotsCount: widget.files.length < 1 ? 1 : widget.files.length,
          position: currentIndexPage,
          decorator: DotsDecorator(
            size: const Size.square(8.0),
            activeSize: const Size(18.0, 8.0),
            activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0),
            ),
            activeColor: Colors.blue,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}
