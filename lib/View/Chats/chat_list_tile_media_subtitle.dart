import 'package:flutter/material.dart';
import 'package:point/Utils/chat_message_bidi.dart';
import 'package:point/View/Chats/chat_reply_draft_banner.dart';

/// Chat list subtitle: small media thumbnail + text (replaces raw 📷 / 🎬 in the row).
class ChatListTileMediaSubtitle extends StatelessWidget {
  final String? imageUrl;
  final String? videoUrl;
  final String text;
  final int maxLines;

  const ChatListTileMediaSubtitle({
    super.key,
    this.imageUrl,
    this.videoUrl,
    required this.text,
    this.maxLines = 2,
  });

  bool get _hasThumb =>
      (imageUrl != null && imageUrl!.trim().isNotEmpty) ||
      (videoUrl != null && videoUrl!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final resolvedDirection =
        chatMessageTextDirectionFromFirstWord(text) ??
            Directionality.of(context);
    final ambientDirection = Directionality.of(context);
    final avatarSideAlign =
        chatListSubtitleAlignToAmbientAvatarSide(ambientDirection);
    if (!_hasThumb) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(),
        textDirection: resolvedDirection,
        textAlign: avatarSideAlign,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ChatReplyMediaThumb(
          imageUrl: imageUrl?.trim(),
          videoUrl: videoUrl?.trim(),
          size: 40,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textDirection: resolvedDirection,
            textAlign: avatarSideAlign,
          ),
        ),
      ],
    );
  }
}
