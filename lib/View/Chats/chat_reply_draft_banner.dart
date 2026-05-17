import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/Chats/chat_cached_attachment_image.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';
import 'package:point/Utils/chat_video_controller.dart';
import 'package:video_player/video_player.dart';

/// Caption line for the composer when a media thumbnail is shown (no 📷/🎬 emoji).
String chatReplyComposerCaption(ChatReplyDraft d) {
  final p = d.preview.trim();
  final hasImg = d.replyImageUrl != null && d.replyImageUrl!.trim().isNotEmpty;
  final hasVid = d.replyVideoUrl != null && d.replyVideoUrl!.trim().isNotEmpty;
  if (hasImg) {
    if (p.isNotEmpty && p != '📷') return p;
    return AppLocaleKeys.chatReplyMediaPhoto.tr;
  }
  if (hasVid) {
    if (p.isNotEmpty && p != '🎬') return p;
    return AppLocaleKeys.chatReplyMediaVideo.tr;
  }
  return p;
}

/// Small thumbnail for image or video (generated frame) for reply composer strip.
class ChatReplyMediaThumb extends StatelessWidget {
  final String? imageUrl;
  final String? videoUrl;
  final double size;

  const ChatReplyMediaThumb({
    super.key,
    this.imageUrl,
    this.videoUrl,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final iu = imageUrl?.trim();
    if (iu != null && iu.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ChatCachedAttachmentImage(
          url: iu,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __) => _thumbPlaceholder(size, Icons.broken_image_outlined),
        ),
      );
    }
    final vu = videoUrl?.trim();
    if (vu != null && vu.isNotEmpty) {
      return _ChatReplyVideoThumb(videoUrl: vu, size: size);
    }
    return const SizedBox.shrink();
  }

  static Widget _thumbPlaceholder(double size, IconData icon) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.45, color: Colors.black45),
    );
  }
}

class _ChatReplyVideoThumb extends StatefulWidget {
  final String videoUrl;
  final double size;

  const _ChatReplyVideoThumb({required this.videoUrl, required this.size});

  @override
  State<_ChatReplyVideoThumb> createState() => _ChatReplyVideoThumbState();
}

class _ChatReplyVideoThumbState extends State<_ChatReplyVideoThumb> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initController(widget.videoUrl);
  }

  @override
  void didUpdateWidget(covariant _ChatReplyVideoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl == widget.videoUrl) return;
    _disposeController();
    _ready = false;
    _failed = false;
    _initController(widget.videoUrl);
  }

  Future<void> _initController(String url) async {
    try {
      final c = await chatVideoControllerForUrl(url)
        ..setLooping(false)
        ..setVolume(0);
      _controller = c;
      await c.initialize().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      await c.pause();
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    c?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _controller == null) {
      return ChatReplyMediaThumb._thumbPlaceholder(
        widget.size,
        Icons.videocam_outlined,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready && _controller!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: SizedBox(
                  width: widget.size * 0.4,
                  height: widget.size * 0.4,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: widget.size * 0.45,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grey strip above the composer: "Replying to" + optional media thumb + caption.
class ChatReplyDraftBanner extends StatelessWidget {
  final ChatReplyDraft draft;
  final VoidCallback onCancel;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const ChatReplyDraftBanner({
    super.key,
    required this.draft,
    required this.onCancel,
    this.fontSize = 13,
    this.padding = const EdgeInsets.fromLTRB(8, 0, 8, 6),
  });

  @override
  Widget build(BuildContext context) {
    final cap = chatReplyComposerCaption(draft);
    final hasThumb =
        (draft.replyImageUrl != null && draft.replyImageUrl!.trim().isNotEmpty) ||
        (draft.replyVideoUrl != null && draft.replyVideoUrl!.trim().isNotEmpty);

    return Padding(
      padding: padding,
      child: Material(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          leading:
              hasThumb
                  ? ChatReplyMediaThumb(
                    imageUrl: draft.replyImageUrl,
                    videoUrl: draft.replyVideoUrl,
                    size: fontSize >= 13 ? 40 : 36,
                  )
                  : null,
          title: Text(
            '${AppLocaleKeys.chatReplyingTo.tr}: $cap',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize),
          ),
          trailing: IconButton(
            icon: Icon(Icons.close, size: fontSize >= 13 ? 20 : 18),
            onPressed: onCancel,
          ),
        ),
      ),
    );
  }
}
