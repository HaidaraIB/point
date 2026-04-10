import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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
        child: Image.network(
          iu,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) => _thumbPlaceholder(size, Icons.broken_image_outlined),
        ),
      );
    }
    final vu = videoUrl?.trim();
    if (vu != null && vu.isNotEmpty) {
      return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: vu,
          imageFormat: ImageFormat.JPEG,
          maxWidth: (size * 3).round(),
          quality: 70,
        ),
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes != null && bytes.isNotEmpty) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(bytes, fit: BoxFit.cover),
                    Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: size * 0.45,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return SizedBox(
              width: size,
              height: size,
              child: Center(
                child: SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _thumbPlaceholder(size, Icons.videocam_outlined);
        },
      );
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
