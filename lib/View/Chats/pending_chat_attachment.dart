import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/Chats/chat_cached_attachment_image.dart';
import 'package:point/View/Chats/chat_reply_draft_banner.dart';

/// Staged attachment (uploaded URL) until the user taps Send — same pattern as paste.
class PendingChatAttachment {
  final String messageType;
  final String attachmentUrl;
  final String? fileName;
  final int? durationSec;

  const PendingChatAttachment({
    required this.messageType,
    required this.attachmentUrl,
    this.fileName,
    this.durationSec,
  });
}

String lastMessagePreviewForPending(
  PendingChatAttachment p,
  String caption,
) {
  switch (p.messageType) {
    case 'image':
      return caption.isNotEmpty ? caption : '📷';
    case 'video':
      return caption.isNotEmpty ? caption : '🎬';
    case 'file':
      return caption.isNotEmpty ? caption : (p.fileName ?? '📎');
    case 'voice':
      return caption.isNotEmpty ? caption : '🎤';
    default:
      return caption;
  }
}

/// Grey strip above the composer for a staged image / video / file / voice.
class PendingAttachmentStrip extends StatelessWidget {
  final PendingChatAttachment pending;
  final VoidCallback onCancel;
  final EdgeInsetsGeometry padding;
  final double titleFontSize;
  final VoidCallback? onTapPreview;

  const PendingAttachmentStrip({
    super.key,
    required this.pending,
    required this.onCancel,
    this.padding = const EdgeInsets.fromLTRB(8, 0, 8, 6),
    this.titleFontSize = 13,
    this.onTapPreview,
  });

  @override
  Widget build(BuildContext context) {
    final label = _label();
    Widget leading = _leading();
    if (onTapPreview != null &&
        (pending.messageType == 'image' ||
            pending.messageType == 'video')) {
      leading = InkWell(onTap: onTapPreview, child: leading);
    }
    return Padding(
      padding: padding,
      child: Material(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          leading: leading,
          title: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: titleFontSize),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onCancel,
          ),
        ),
      ),
    );
  }

  String _label() {
    switch (pending.messageType) {
      case 'image':
        return AppLocaleKeys.chatReplyMediaPhoto.tr;
      case 'video':
        return AppLocaleKeys.chatReplyMediaVideo.tr;
      case 'file':
        return pending.fileName ?? AppLocaleKeys.chatAttachFile.tr;
      case 'voice':
        final s = pending.durationSec;
        final dur =
            s != null && s > 0 ? ' (${s}s)' : '';
        return '${AppLocaleKeys.chatAttachVoice.tr}$dur';
      default:
        return '';
    }
  }

  Widget _leading() {
    if (pending.messageType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ChatCachedAttachmentImage(
          url: pending.attachmentUrl,
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __) => const Icon(Icons.image_outlined, size: 22),
        ),
      );
    }
    if (pending.messageType == 'video') {
      return ChatReplyMediaThumb(
        videoUrl: pending.attachmentUrl,
        size: 34,
      );
    }
    if (pending.messageType == 'file') {
      return const Icon(Icons.insert_drive_file_outlined, size: 28);
    }
    return const Icon(Icons.mic_none_rounded, size: 28);
  }
}
