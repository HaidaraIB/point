import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:point/Services/chat_attachment_cache.dart';

/// Chat attachment thumbnail / bubble image loaded from [ChatAttachmentCache].
class ChatCachedAttachmentImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  const ChatCachedAttachmentImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  State<ChatCachedAttachmentImage> createState() =>
      _ChatCachedAttachmentImageState();
}

class _ChatCachedAttachmentImageState extends State<ChatCachedAttachmentImage> {
  int _retrySeed = 0;
  Future<Uint8List>? _bytesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ChatCachedAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _load();
    }
  }

  Future<Uint8List> _loadBytes() async {
    final cached = await ChatAttachmentCache.bytesFromCacheOnly(widget.url);
    if (cached != null && cached.isNotEmpty) return cached;
    return ChatAttachmentCache.bytesForUrl(widget.url);
  }

  void _load() {
    _bytesFuture = _loadBytes();
  }

  Future<void> _retry() async {
    await ChatAttachmentCache.evictUrl(widget.url);
    if (!mounted) return;
    setState(() {
      _retrySeed++;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      key: ValueKey('${widget.url}#$_retrySeed'),
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
        if (snapshot.hasError || !snapshot.hasData) {
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
