import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/chat_message_bidi.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/Services/chat_attachment_cache.dart';
import 'package:point/View/Chats/chat_cached_attachment_image.dart';
import 'package:point/View/Chats/chat_media_load_progress.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';
import 'package:point/Utils/chat_video_controller.dart';
import 'package:point/View/Chats/chat_media_gallery.dart';
import 'package:point/View/Shared/voice_message_row.dart';
import 'package:video_player/video_player.dart';
import 'package:point/Utils/app_theme_extension.dart';

export 'chat_media_gallery.dart' show openChatMediaFromUrl;

/// صورة وفق امتداد المسار (يدعم روابط تحتوي `?query`).
bool isImageUrl(String url) => isImageMediaUrl(url);

bool isVideoUrl(String url) => isVideoMediaUrl(url);

/// اسم ملف مرفق (صورة/فيديو من المعرض).
bool chatAttachmentIsVideo(String fileName) {
  final base = fileName.trim().split('/').last.split('?').first;
  final dot = base.lastIndexOf('.');
  if (dot < 0 || dot >= base.length - 1) return false;
  const v = {'mp4', 'mov', 'webm', 'm4v', 'avi', 'mkv'};
  return v.contains(base.substring(dot + 1).toLowerCase());
}

bool _fileNameLooksLikeImage(String? fileName) {
  if (fileName == null) return false;
  final base = fileName.trim().split('/').last.split('?').first.toLowerCase();
  return base.endsWith('.png') ||
      base.endsWith('.jpg') ||
      base.endsWith('.jpeg') ||
      base.endsWith('.gif') ||
      base.endsWith('.webp');
}

bool _messageShowsAsVideo(
  String? messageType,
  String attachmentUrl,
  String? fileName,
) {
  if (messageType == 'video') return true;
  if (isVideoUrl(attachmentUrl)) return true;
  if (fileName != null && chatAttachmentIsVideo(fileName)) return true;
  return false;
}

/// محتوى فقاعة الرسالة حسب [messageType] مع دعم الرسائل القديمة (نص + رابط فقط).
Widget chatMessageBubbleContent(
  Map<String, dynamic> msg,
  bool isMe, {
  String? chatId,
  String? messageId,
}) {
  if (msg['deleted'] == true) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          AppLocaleKeys.chatMessageDeletedBody.tr,
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: chatBubbleMutedTextColor(context, isMe),
          ),
        ),
      ),
    );
  }
  final type = (msg['messageType'] as String?)?.trim();
  final attachmentUrl = (msg['attachmentUrl'] as String?)?.trim();
  final text = (msg['text'] ?? '') as String;

  if (type == 'voice') {
    final url = (attachmentUrl != null && attachmentUrl.isNotEmpty)
        ? attachmentUrl
        : text;
    if (url.startsWith('http')) {
      var caption = text.trim();
      if (caption.isNotEmpty &&
          (caption == url ||
              caption.startsWith('http://') ||
              caption.startsWith('https://'))) {
        caption = '';
      }
      final hasCaption = caption.isNotEmpty && caption != '🎤';
      final row = VoiceMessageRow(
        url: url,
        durationSec: msg['durationSec'] as int?,
        isMe: isMe,
      );
      if (!hasCaption) return row;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          row,
          const SizedBox(height: 6),
          messageTextRich(caption, isMe, chatId: chatId, messageId: messageId),
        ],
      );
    }
  }
  final showsAsImage = attachmentUrl != null &&
      attachmentUrl.isNotEmpty &&
      (type == 'image' ||
          ((type == 'file' || type == null || type.isEmpty) &&
              (isImageMediaUrl(attachmentUrl) ||
                  _fileNameLooksLikeImage(msg['fileName'] as String?))));
  if (showsAsImage) {
    final caption = text.trim();
    final fn = (msg['fileName'] as String?)?.trim() ?? '';
    final hasCaption = caption.isNotEmpty &&
        caption != '📷' &&
        caption != fn &&
        caption != '📎';
    if (!hasCaption) {
      return _ChatImageBubble(
        url: attachmentUrl,
        isMe: isMe,
        chatId: chatId,
        messageId: messageId,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatImageBubble(
          url: attachmentUrl,
          isMe: isMe,
          chatId: chatId,
          messageId: messageId,
        ),
        const SizedBox(height: 6),
        messageTextRich(caption, isMe, chatId: chatId, messageId: messageId),
      ],
    );
  }
  if (attachmentUrl != null &&
      attachmentUrl.isNotEmpty &&
      _messageShowsAsVideo(type, attachmentUrl, msg['fileName'] as String?)) {
    final caption = text.trim();
    final hasCaption = caption.isNotEmpty && caption != '🎬';
    final bubble = _ChatVideoBubble(
      url: attachmentUrl,
      isMe: isMe,
      fileName: msg['fileName'] as String?,
      chatId: chatId,
      messageId: messageId,
    );
    if (!hasCaption) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        const SizedBox(height: 6),
        messageTextRich(caption, isMe, chatId: chatId, messageId: messageId),
      ],
    );
  }
  if (type == 'file' && attachmentUrl != null && attachmentUrl.isNotEmpty) {
    final fn = (msg['fileName'] as String?)?.trim() ?? '';
    var caption = text.trim();
    if (caption.isNotEmpty && (caption == fn || caption == '📎')) {
      caption = '';
    }
    final hasCaption = caption.isNotEmpty;
    final bubble = _FileBubble(
      url: attachmentUrl,
      fileName: msg['fileName'] as String?,
      isMe: isMe,
      chatId: chatId,
      messageId: messageId,
    );
    if (!hasCaption) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        const SizedBox(height: 6),
        messageTextRich(caption, isMe, chatId: chatId, messageId: messageId),
      ],
    );
  }

  return messageTextRich(text, isMe, chatId: chatId, messageId: messageId);
}

class _ChatImageBubble extends StatelessWidget {
  final String url;
  final bool isMe;
  final String? chatId;
  final String? messageId;

  const _ChatImageBubble({
    required this.url,
    required this.isMe,
    this.chatId,
    this.messageId,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _RetryableChatImage(
        url: url,
        width: 200,
        fit: BoxFit.cover,
        isMe: isMe,
        chatId: chatId,
        messageId: messageId,
      ),
    );
  }
}

class _RetryableChatImage extends StatefulWidget {
  final String url;
  final double width;
  final BoxFit fit;
  final bool isMe;
  final double loadingHeight;
  final String? chatId;
  final String? messageId;

  const _RetryableChatImage({
    required this.url,
    required this.width,
    required this.fit,
    required this.isMe,
    this.loadingHeight = 120,
    this.chatId,
    this.messageId,
  });

  @override
  State<_RetryableChatImage> createState() => _RetryableChatImageState();
}

class _RetryableChatImageState extends State<_RetryableChatImage> {
  bool _loadRequested = false;
  bool _loaded = false;
  int _retrySeed = 0;

  Future<void> _retryLoad() async {
    await ChatAttachmentCache.evictUrl(widget.url);
    if (!mounted) return;
    setState(() {
      _retrySeed++;
      _loaded = false;
      _loadRequested = true;
    });
  }

  void _onTap() {
    if (!_loaded) {
      if (!_loadRequested) {
        setState(() => _loadRequested = true);
        return;
      }
      // Stuck or failed after a load attempt — allow tap to retry.
      unawaited(_retryLoad());
      return;
    }
    unawaited(
      openChatMediaFromUrl(
        widget.url,
        chatId: widget.chatId,
        messageId: widget.messageId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _onTap,
      child: ChatCachedAttachmentImage(
        key: ValueKey('chat_img_${widget.url}#$_retrySeed'),
        url: widget.url,
        width: widget.width,
        fit: widget.fit,
        loadPolicy: ChatAttachmentLoadPolicy.onDemand,
        loadRequested: _loadRequested,
        isMe: widget.isMe,
        onLoadComplete: () {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        loadingBuilder: (c, child, p) {
          // Must return [child] when progress is null (image frame ready).
          if (p == null) return child;
          return SizedBox(
            height: widget.loadingHeight,
            width: widget.width,
            child: Center(
              child: ChatMediaCircularProgress(
                value: chatMediaProgressValue(p),
                size: 28,
                strokeWidth: 2.2,
                color: widget.isMe
                    ? Colors.white70
                    : Theme.of(c).colorScheme.primary,
              ),
            ),
          );
        },
        errorBuilder: (_, __) => SizedBox(
          height: widget.loadingHeight,
          width: widget.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.refresh,
                size: 24,
                color: widget.isMe ? Colors.white70 : context.appTheme.secondaryText,
              ),
              const SizedBox(height: 4),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isMe ? Colors.white70 : context.appTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatVideoBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  final String? fileName;
  final String? chatId;
  final String? messageId;

  const _ChatVideoBubble({
    required this.url,
    required this.isMe,
    this.fileName,
    this.chatId,
    this.messageId,
  });

  @override
  State<_ChatVideoBubble> createState() => _ChatVideoBubbleState();
}

class _ChatVideoBubbleState extends State<_ChatVideoBubble> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _loadRequested = false;
  bool _booting = false;
  double? _loadProgress;

  Future<void> _boot() async {
    if (_booting) return;
    _booting = true;
    try {
      final c = await chatVideoControllerForUrl(
        widget.url,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _loadProgress = p);
        },
      )
        ..setLooping(false)
        ..setVolume(0);
      if (!mounted) {
        await c.dispose();
        return;
      }
      _controller = c;
      await c.initialize();
      if (!mounted) return;
      await c.pause();
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _booting = false;
    }
  }

  void _onPlaceholderTap() {
    if (_loadRequested || _ready || _failed) return;
    setState(() => _loadRequested = true);
    unawaited(_boot());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _FileBubble(
        url: widget.url,
        fileName: widget.fileName,
        isMe: widget.isMe,
      );
    }

    const maxW = 232.0;
    final loadingPlaceholder = Container(
      width: maxW,
      height: maxW * 9 / 16,
      alignment: Alignment.center,
      color: widget.isMe
          ? Colors.black.withValues(alpha: 0.22)
          : Colors.black.withValues(alpha: 0.07),
      child: ChatMediaCircularProgress(
        value: _loadProgress,
        size: 30,
        strokeWidth: 2.2,
        color: widget.isMe
            ? Colors.white70
            : Theme.of(context).colorScheme.primary,
      ),
    );
    final idlePlaceholder = Material(
      color: widget.isMe
          ? Colors.black.withValues(alpha: 0.22)
          : Colors.black.withValues(alpha: 0.07),
      child: InkWell(
        onTap: _onPlaceholderTap,
        child: SizedBox(
          width: maxW,
          height: maxW * 9 / 16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_outlined,
                size: 36,
                color: widget.isMe ? Colors.white70 : context.appTheme.secondaryText,
              ),
              const SizedBox(height: 8),
              Icon(
                Icons.touch_app_outlined,
                size: 20,
                color: widget.isMe ? Colors.white54 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: maxW,
            child: _ready &&
                    _controller != null &&
                    _controller!.value.aspectRatio > 0
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: context.appTheme.primaryText,
                          child: VideoPlayer(_controller!),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => openChatMediaFromUrl(
                              widget.url,
                              chatId: widget.chatId,
                              messageId: widget.messageId,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.02),
                                    Colors.black.withValues(alpha: 0.52),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.play_circle_rounded,
                                  size: 58,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 12,
                                      color: context.appTheme.secondaryText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : (_loadRequested ? loadingPlaceholder : idlePlaceholder),
          ),
        ),
        if ((widget.fileName ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.fileName!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: widget.isMe ? Colors.white70 : context.appTheme.secondaryText,
              ),
            ),
          ),
      ],
    );
  }
}

class _FileBubble extends StatelessWidget {
  final String url;
  final String? fileName;
  final bool isMe;
  final String? chatId;
  final String? messageId;

  const _FileBubble({
    required this.url,
    this.fileName,
    required this.isMe,
    this.chatId,
    this.messageId,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackBase = _basenameFromUrlOrName(url);
    final stored = (fileName ?? '').trim();
    final baseForMeta = stored.isNotEmpty ? stored : fallbackBase;
    final ext = _fileExtensionFromName(baseForMeta);
    final icon = _fileIconForExtension(ext);

    final rawTitle = stored.isNotEmpty ? stored : fallbackBase;
    final titleBase = _basenameFromUrlOrName(rawTitle);
    final title = _isStorageStyleUuidName(titleBase)
        ? AppLocaleKeys.chatFileUntitled.tr
        : titleBase;

    final tapHint = AppLocaleKeys.chatFileTapToOpen.tr;
    final subtitle = ext.isNotEmpty
        ? '${ext.toUpperCase()} · $tapHint'
        : tapHint;

    final primary = isMe
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final secondary = isMe
        ? Colors.white.withValues(alpha: 0.72)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final iconBg = isMe
        ? Colors.white.withValues(alpha: 0.22)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    final iconFg = isMe ? Colors.white : Theme.of(context).colorScheme.primary;
    final tileBg = isMe
        ? Colors.white.withValues(alpha: 0.2)
        : Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);
    final borderColor = isMe
        ? Colors.white.withValues(alpha: 0.35)
        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Material(
        color: tileBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openChatMediaFromUrl(
            url,
            chatId: chatId,
            messageId: messageId,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconFg, size: 26),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget messageTextRich(
  String text,
  bool isMe, {
  String? chatId,
  String? messageId,
}) {
  return Builder(
    builder: (context) {
      final resolvedDirection = chatMessageTextDirectionFromFirstWord(text) ??
          Directionality.of(context);
      final matches = linkifiedUrlRegex.allMatches(text);

      final style = TextStyle(
        fontSize: 15,
        color: chatBubbleTextColor(context, isMe),
      );

      final child = matches.isEmpty
          ? Text(text, style: style)
          : RichText(
              text: TextSpan(
                children: buildMessageSpans(
                  text,
                  isMe,
                  chatId: chatId,
                  messageId: messageId,
                ),
                style: style,
              ),
            );

      return Directionality(textDirection: resolvedDirection, child: child);
    },
  );
}

final _uuidFileStemRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

String _basenameFromUrlOrName(String s) =>
    s.trim().split('/').last.split('?').first;

bool _isStorageStyleUuidName(String baseName) {
  final dot = baseName.lastIndexOf('.');
  final stem = dot >= 0 ? baseName.substring(0, dot) : baseName;
  return _uuidFileStemRegex.hasMatch(stem);
}

String _fileExtensionFromName(String name) {
  final base = _basenameFromUrlOrName(name);
  final dot = base.lastIndexOf('.');
  if (dot < 0 || dot == base.length - 1) return '';
  return base.substring(dot + 1).toLowerCase();
}

IconData _fileIconForExtension(String ext) {
  switch (ext) {
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'doc':
    case 'docx':
      return Icons.description_outlined;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Icons.table_chart_outlined;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow_outlined;
    case 'zip':
    case 'rar':
    case '7z':
      return Icons.folder_zip_outlined;
    case 'mp3':
    case 'wav':
    case 'm4a':
    case 'aac':
      return Icons.audio_file_outlined;
    case 'mp4':
    case 'mov':
    case 'webm':
      return Icons.video_file_outlined;
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
      return Icons.image_outlined;
    case 'txt':
      return Icons.article_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

List<InlineSpan> buildMessageSpans(
  String text,
  bool isMe, {
  String? chatId,
  String? messageId,
}) {
  final spans = <InlineSpan>[];
  int lastIndex = 0;
  final linkColor = isMe ? Colors.lightBlueAccent : Colors.blue;

  for (final match in linkifiedUrlRegex.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
    }

    final url = match.group(0)!;

    if (isImageUrl(url)) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _RetryableChatImage(
                url: url,
                width: 200,
                fit: BoxFit.cover,
                isMe: isMe,
                loadingHeight: 150,
                chatId: chatId,
                messageId: messageId,
              ),
            ),
          ),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => openChatMediaFromUrl(
              url,
              chatId: chatId,
              messageId: messageId,
            ),
        ),
      );
    }

    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    spans.add(TextSpan(text: text.substring(lastIndex)));
  }

  return spans;
}
