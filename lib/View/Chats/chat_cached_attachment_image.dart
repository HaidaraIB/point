import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:point/Services/chat_attachment_cache.dart';
import 'package:point/View/Chats/chat_media_load_progress.dart';
import 'package:point/View/Shared/safe_network_image.dart';

enum ChatAttachmentLoadPolicy {
  /// Cache then network as soon as the widget mounts.
  eager,

  /// Disk cache only until [loadRequested] is true; then network fetch.
  onDemand,
}

/// Chat attachment thumbnail / bubble image loaded from [ChatAttachmentCache].
/// On web, renders via [SafeNetworkImage] so CORS-blocked byte fetches do not
/// blank the bubble (same strategy as content thumbs / full image preview).
class ChatCachedAttachmentImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ChatAttachmentLoadPolicy loadPolicy;
  final bool loadRequested;
  final bool? isMe;
  final VoidCallback? onLoadComplete;
  final Widget Function(BuildContext, Object?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final Widget Function(BuildContext)? placeholderBuilder;

  const ChatCachedAttachmentImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.loadPolicy = ChatAttachmentLoadPolicy.eager,
    this.loadRequested = false,
    this.isMe,
    this.onLoadComplete,
    this.errorBuilder,
    this.loadingBuilder,
    this.placeholderBuilder,
  });

  @override
  State<ChatCachedAttachmentImage> createState() =>
      _ChatCachedAttachmentImageState();
}

class _ChatCachedAttachmentImageState extends State<ChatCachedAttachmentImage> {
  int _retrySeed = 0;
  Stream<ChatAttachmentBytesEvent>? _bytesStream;
  bool _cacheOnly = false;
  bool _reportedLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _startLoad();
  }

  @override
  void didUpdateWidget(ChatCachedAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb) {
      if (oldWidget.url != widget.url) {
        _reportedLoaded = false;
      }
      return;
    }
    if (oldWidget.url != widget.url) {
      _reportedLoaded = false;
      _startLoad();
      return;
    }
    if (widget.loadPolicy == ChatAttachmentLoadPolicy.onDemand &&
        !oldWidget.loadRequested &&
        widget.loadRequested) {
      _startLoad();
    }
  }

  void _startLoad() {
    _cacheOnly = widget.loadPolicy == ChatAttachmentLoadPolicy.onDemand &&
        !widget.loadRequested;
    if (_cacheOnly) {
      _bytesStream = Stream.fromFuture(
        ChatAttachmentCache.bytesFromCacheOnly(widget.url),
      ).map(
        (bytes) => ChatAttachmentBytesEvent(
          downloaded: bytes?.length ?? 0,
          totalSize: bytes?.length,
          bytes: bytes,
        ),
      );
      return;
    }
    _bytesStream = ChatAttachmentCache.bytesStreamForUrl(widget.url);
  }

  Future<void> _retry() async {
    await ChatAttachmentCache.evictUrl(widget.url);
    if (!mounted) return;
    setState(() {
      _retrySeed++;
      _reportedLoaded = false;
      if (!kIsWeb) _startLoad();
    });
  }

  void _maybeReportLoaded([Uint8List? data]) {
    if (_reportedLoaded) return;
    if (data != null && data.isEmpty) return;
    _reportedLoaded = true;
    final callback = widget.onLoadComplete;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  Widget _defaultPlaceholder(BuildContext context) {
    final isMe = widget.isMe;
    final iconColor = isMe == null
        ? Colors.black45
        : (isMe ? Colors.white70 : Colors.black45);
    final bg = isMe == null
        ? Colors.black12
        : (isMe
            ? Colors.black.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.07));
    return SizedBox(
      width: widget.width,
      height: widget.height ?? 120,
      child: ColoredBox(
        color: bg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 32, color: iconColor),
            const SizedBox(height: 6),
            Icon(Icons.touch_app_outlined, size: 18, color: iconColor),
          ],
        ),
      ),
    );
  }

  Widget _loadingWidget(BuildContext context, ImageChunkEvent? progress) {
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(
        context,
        const SizedBox.shrink(),
        progress,
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height ?? 24,
      child: Center(
        child: ChatMediaCircularProgress(
          value: chatMediaProgressValue(progress),
          size: 20,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _webImage() {
    if (widget.loadPolicy == ChatAttachmentLoadPolicy.onDemand &&
        !widget.loadRequested) {
      if (widget.placeholderBuilder != null) {
        return widget.placeholderBuilder!(context);
      }
      return _defaultPlaceholder(context);
    }
    return SafeNetworkImage(
      widget.url,
      key: ValueKey('chat_web_${widget.url}#$_retrySeed'),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (context, child, progress) {
            // Flutter contract: progress == null means the frame is ready —
            // callers must return [child]. Always report load here so custom
            // loadingBuilder overrides cannot skip onLoadComplete.
            if (progress == null) {
              _maybeReportLoaded();
            }
            if (widget.loadingBuilder != null) {
              return widget.loadingBuilder!(context, child, progress);
            }
            if (progress == null) return child;
            return SizedBox(
              width: widget.width,
              height: widget.height ?? 24,
              child: Center(
                child: ChatMediaCircularProgress(
                  value: chatMediaProgressValue(progress),
                  size: 20,
                  strokeWidth: 2,
                ),
              ),
            );
          },
      errorBuilder: (context, error, stackTrace) {
        if (widget.errorBuilder != null) {
          return widget.errorBuilder!(context, error);
        }
        return InkWell(
          onTap: _retry,
          child: SizedBox(
            width: widget.width,
            height: widget.height ?? 40,
            child: const Icon(Icons.refresh, size: 22),
          ),
        );
      },
    );
  }

  ImageChunkEvent? _chunkFromEvent(ChatAttachmentBytesEvent event) {
    if (event.hasBytes) return null;
    return ImageChunkEvent(
      cumulativeBytesLoaded: event.downloaded,
      expectedTotalBytes: event.totalSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _webImage();

    return StreamBuilder<ChatAttachmentBytesEvent>(
      key: ValueKey('${widget.url}#$_retrySeed#${widget.loadRequested}'),
      stream: _bytesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (_cacheOnly) {
            if (widget.placeholderBuilder != null) {
              return widget.placeholderBuilder!(context);
            }
            return _defaultPlaceholder(context);
          }
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(context, snapshot.error);
          }
          return InkWell(
            onTap: _retry,
            child: SizedBox(
              width: widget.width,
              height: widget.height ?? 40,
              child: const Icon(Icons.refresh, size: 22),
            ),
          );
        }

        final event = snapshot.data;
        if (event != null && event.hasBytes) {
          _maybeReportLoaded(event.bytes);
          return Image.memory(
            event.bytes!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
          );
        }

        if (_cacheOnly &&
            snapshot.connectionState == ConnectionState.done &&
            (event == null || !event.hasBytes)) {
          if (widget.placeholderBuilder != null) {
            return widget.placeholderBuilder!(context);
          }
          return _defaultPlaceholder(context);
        }

        if (snapshot.connectionState == ConnectionState.done &&
            (event == null || !event.hasBytes) &&
            !_cacheOnly) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(context, null);
          }
          return InkWell(
            onTap: _retry,
            child: SizedBox(
              width: widget.width,
              height: widget.height ?? 40,
              child: const Icon(Icons.refresh, size: 22),
            ),
          );
        }

        return _loadingWidget(
          context,
          event == null
              ? const ImageChunkEvent(
                  cumulativeBytesLoaded: 0,
                  expectedTotalBytes: null,
                )
              : (_chunkFromEvent(event) ??
                  const ImageChunkEvent(
                    cumulativeBytesLoaded: 0,
                    expectedTotalBytes: null,
                  )),
        );
      },
    );
  }
}
