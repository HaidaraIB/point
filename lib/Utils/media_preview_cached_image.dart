import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/chat_attachment_cache.dart';

/// Full-screen preview image loaded from [ChatAttachmentCache] (works offline).
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
    _load();
  }

  @override
  void didUpdateWidget(MediaPreviewCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
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
        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          gaplessPlayback: true,
        );
      },
    );
  }
}
