import 'package:flutter/material.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:video_player/video_player.dart';

String _attachmentPathLower(String rawUrl) {
  try {
    return Uri.parse(rawUrl).path.toLowerCase();
  } catch (_) {
    return rawUrl.toLowerCase();
  }
}

/// Icon for non-image attachments from URL path extension.
IconData iconForAttachmentUrl(String rawUrl) {
  final p = _attachmentPathLower(rawUrl);
  if (p.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (p.endsWith('.zip') || p.endsWith('.rar') || p.endsWith('.7z')) {
    return Icons.folder_zip_outlined;
  }
  if (p.endsWith('.mp4') ||
      p.endsWith('.mov') ||
      p.endsWith('.webm') ||
      p.endsWith('.mkv') ||
      p.endsWith('.m4v')) {
    return Icons.video_file_outlined;
  }
  if (p.endsWith('.mp3') ||
      p.endsWith('.wav') ||
      p.endsWith('.aac') ||
      p.endsWith('.m4a') ||
      p.endsWith('.flac')) {
    return Icons.audio_file_outlined;
  }
  if (p.endsWith('.doc') ||
      p.endsWith('.docx') ||
      p.endsWith('.odt')) {
    return Icons.description_outlined;
  }
  if (p.endsWith('.xls') ||
      p.endsWith('.xlsx') ||
      p.endsWith('.ods')) {
    return Icons.table_chart_outlined;
  }
  if (p.endsWith('.ppt') ||
      p.endsWith('.pptx') ||
      p.endsWith('.odp')) {
    return Icons.slideshow_outlined;
  }
  if (p.endsWith('.txt') ||
      p.endsWith('.csv') ||
      p.endsWith('.json') ||
      p.endsWith('.xml')) {
    return Icons.article_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

/// Square attachment preview: image cover when the URL is an image, otherwise a
/// file-type icon on a neutral tile. Used in forms, tables, and task dialogs.
///
/// When [onTap] is null, the tile is not wrapped in [InkWell] (use when a
/// parent handles taps, e.g. table row or upload grid).
class AttachmentThumbnailTile extends StatelessWidget {
  const AttachmentThumbnailTile({
    super.key,
    required this.url,
    this.onTap,
    this.borderRadius = 10,
  });

  final String url;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isImage = isImageMediaUrl(url);
    final radius = BorderRadius.circular(borderRadius);

    Widget tile(double size) {
      final iconSize = (size * 0.38).clamp(22.0, 40.0);

      if (isVideoMediaUrl(url)) {
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: ClipRRect(
              borderRadius: radius,
              child: KeyedSubtree(
                key: ValueKey('video_thumb_$url'),
                child: _NetworkVideoAttachmentThumb(
                  url: url,
                  iconFallbackSize: iconSize,
                ),
              ),
            ),
          ),
        );
      }

      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: radius,
            child:
                isImage
                    ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => _filePlaceholder(
                            url,
                            iconSize,
                          ),
                    )
                    : _filePlaceholder(url, iconSize),
          ),
        ),
      );
    }

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final double size =
            constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;
        return tile(size);
      },
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: content,
    );
  }
}

Widget _filePlaceholder(String url, double iconSize) {
  return Container(
    color: Colors.blueGrey.shade100,
    child: Icon(
      iconForAttachmentUrl(url),
      color: Colors.blueGrey.shade700,
      size: iconSize,
    ),
  );
}

/// First-frame preview for remote video URLs (muted, paused). Tap is handled
/// by an ancestor [InkWell] (e.g. [FormAttachmentThumbnailsGrid]).
class _NetworkVideoAttachmentThumb extends StatefulWidget {
  const _NetworkVideoAttachmentThumb({
    required this.url,
    required this.iconFallbackSize,
  });

  final String url;
  final double iconFallbackSize;

  @override
  State<_NetworkVideoAttachmentThumb> createState() =>
      _NetworkVideoAttachmentThumbState();
}

class _NetworkVideoAttachmentThumbState
    extends State<_NetworkVideoAttachmentThumb> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final c = VideoPlayerController.networkUrl(uri);
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setVolume(0);
      await c.setLooping(false);
      await c.pause();
      await c.seekTo(Duration.zero);
      setState(() => _controller = c);
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _filePlaceholder(widget.url, widget.iconFallbackSize);
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return Container(
        color: Colors.blueGrey.shade100,
        alignment: Alignment.center,
        child: SizedBox(
          width: (widget.iconFallbackSize * 0.65).clamp(18.0, 28.0),
          height: (widget.iconFallbackSize * 0.65).clamp(18.0, 28.0),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final w = c.value.size.width;
    final h = c.value.size.height;
    if (w <= 0 || h <= 0) {
      return _filePlaceholder(widget.url, widget.iconFallbackSize);
    }

    final playSize = (widget.iconFallbackSize * 1.15).clamp(28.0, 44.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: w, height: h, child: VideoPlayer(c)),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: Icon(
            Icons.play_circle_rounded,
            color: Colors.white.withValues(alpha: 0.92),
            size: playSize,
            shadows: const [
              Shadow(blurRadius: 6, color: Colors.black45),
            ],
          ),
        ),
      ],
    );
  }
}
