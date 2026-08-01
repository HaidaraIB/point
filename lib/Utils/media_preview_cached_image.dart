import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/chat_attachment_cache.dart';
import 'package:point/View/Shared/safe_network_image.dart';

/// Full-screen preview image.
///
/// - **Mobile / desktop:** loads bytes via [ChatAttachmentCache] (offline-friendly).
/// - **Web:** uses [SafeNetworkImage] (`webHtmlElementStrategy.prefer`) so the
///   viewer still works when R2/CDN CORS blocks CanvasKit / XHR byte fetches.
///   (Thumbnails already used that path — the viewer previously did not, which
///   caused “fails until DevTools opens” / retry that never reloads.)
class MediaPreviewCachedImage extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const MediaPreviewCachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
  });

  @override
  State<MediaPreviewCachedImage> createState() =>
      _MediaPreviewCachedImageState();
}

class _MediaPreviewCachedImageState extends State<MediaPreviewCachedImage> {
  int _retrySeed = 0;
  Future<Uint8List>? _bytesFuture;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _load();
  }

  @override
  void didUpdateWidget(MediaPreviewCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url && !kIsWeb) _load();
  }

  void _load() {
    _bytesFuture = _loadBytes();
  }

  Future<Uint8List> _loadBytes() async {
    final cached = await ChatAttachmentCache.bytesFromCacheOnly(widget.url);
    if (cached != null && cached.isNotEmpty) return cached;
    return ChatAttachmentCache.bytesForUrl(widget.url);
  }

  Future<void> _retry() async {
    await ChatAttachmentCache.evictUrl(widget.url);
    if (!mounted) return;
    setState(() {
      _retrySeed++;
      if (!kIsWeb) _load();
    });
  }

  Widget _failed() {
    return InkWell(
      onTap: _retry,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 58,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 18),
            Text(
              AppLocaleKeys.chatPreviewLoadFailed.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Icon(
              Icons.refresh,
              size: 28,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SafeNetworkImage(
        widget.url,
        key: ValueKey('web_preview_${widget.url}#$_retrySeed'),
        fit: widget.fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: 220,
            child: Center(
              child: SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _failed(),
      );
    }

    return FutureBuilder<Uint8List>(
      key: ValueKey('${widget.url}#$_retrySeed'),
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            height: 220,
            child: Center(
              child: SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _failed();
        }
        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          gaplessPlayback: true,
        );
      },
    );
  }
}
