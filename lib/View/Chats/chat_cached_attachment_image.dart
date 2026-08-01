import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:point/Services/chat_attachment_cache.dart';
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
  Future<Uint8List?>? _bytesFuture;
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
    if (widget.loadPolicy == ChatAttachmentLoadPolicy.onDemand &&
        !widget.loadRequested) {
      _bytesFuture = ChatAttachmentCache.bytesFromCacheOnly(widget.url);
      return;
    }
    _bytesFuture = _loadBytes();
  }

  Future<Uint8List?> _loadBytes() async {
    final cached = await ChatAttachmentCache.bytesFromCacheOnly(widget.url);
    if (cached != null && cached.isNotEmpty) return cached;
    return ChatAttachmentCache.bytesForUrl(widget.url);
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
      loadingBuilder: widget.loadingBuilder ??
          (context, child, progress) {
            if (progress == null) {
              _maybeReportLoaded();
              return child;
            }
            return SizedBox(
              width: widget.width,
              height: widget.height ?? 24,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
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

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _webImage();

    return FutureBuilder<Uint8List?>(
      key: ValueKey('${widget.url}#$_retrySeed#${widget.loadRequested}'),
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          if (widget.loadingBuilder != null) {
            return widget.loadingBuilder!(
              context,
              const SizedBox.shrink(),
              null,
            );
          }
          return SizedBox(
            width: widget.width,
            height: widget.height ?? 24,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          if (widget.loadPolicy == ChatAttachmentLoadPolicy.onDemand &&
              !widget.loadRequested) {
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
        _maybeReportLoaded(snapshot.data!);
        return Image.memory(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
        );
      },
    );
  }
}
