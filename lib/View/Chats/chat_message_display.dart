import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/chat_message_bidi.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/Services/chat_voice_playback_service.dart';
import 'package:point/View/Chats/chat_cached_attachment_image.dart';
import 'package:point/Utils/chat_video_controller.dart';
import 'package:point/View/Mobile/Shared/VideoCart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

const Color _kChatAccentBlue = AppColors.primary;

String _urlPathLower(String url) {
  try {
    return Uri.parse(url).path.toLowerCase();
  } catch (_) {
    return url.toLowerCase();
  }
}

/// صورة وفق امتداد المسار (يدعم روابط تحتوي `?query`).
bool isImageUrl(String url) {
  final p = _urlPathLower(url);
  return p.endsWith('.png') ||
      p.endsWith('.jpg') ||
      p.endsWith('.jpeg') ||
      p.endsWith('.gif') ||
      p.endsWith('.webp');
}

bool isVideoUrl(String url) {
  final p = _urlPathLower(url);
  return p.endsWith('.mp4') ||
      p.endsWith('.mov') ||
      p.endsWith('.webm') ||
      p.endsWith('.m4v') ||
      p.endsWith('.avi') ||
      p.endsWith('.mkv');
}

/// اسم ملف مرفق (صورة/فيديو من المعرض).
bool chatAttachmentIsVideo(String fileName) {
  final base = fileName.trim().split('/').last.split('?').first;
  final dot = base.lastIndexOf('.');
  if (dot < 0 || dot >= base.length - 1) return false;
  const v = {'mp4', 'mov', 'webm', 'm4v', 'avi', 'mkv'};
  return v.contains(base.substring(dot + 1).toLowerCase());
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

/// صورة/فيديو داخل التطبيق؛ باقي الأنواع تُفتح خارجياً (متصفح / تطبيق آخر).
Future<void> openChatMediaFromUrl(String url) async {
  final trimmed = url.trim();
  if (!trimmed.startsWith('http')) return;

  if (isImageUrl(trimmed)) {
    Get.to(() => ImagePreviewPage(url: trimmed));
    return;
  }
  if (isVideoUrl(trimmed)) {
    Get.to(() => VideoPlayerPage(url: trimmed));
    return;
  }

  final uri = Uri.parse(trimmed);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// محتوى فقاعة الرسالة حسب [messageType] مع دعم الرسائل القديمة (نص + رابط فقط).
Widget chatMessageBubbleContent(Map<String, dynamic> msg, bool isMe) {
  if (msg['deleted'] == true) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        AppLocaleKeys.chatMessageDeletedBody.tr,
        style: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: isMe ? Colors.white70 : Colors.black54,
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
          messageTextRich(caption, isMe),
        ],
      );
    }
  }
  if (type == 'image' && attachmentUrl != null && attachmentUrl.isNotEmpty) {
    final caption = text.trim();
    final hasCaption = caption.isNotEmpty && caption != '📷';
    if (!hasCaption) {
      return _ChatImageBubble(url: attachmentUrl, isMe: isMe);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatImageBubble(url: attachmentUrl, isMe: isMe),
        const SizedBox(height: 6),
        messageTextRich(caption, isMe),
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
    );
    if (!hasCaption) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        const SizedBox(height: 6),
        messageTextRich(caption, isMe),
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
    );
    if (!hasCaption) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        const SizedBox(height: 6),
        messageTextRich(caption, isMe),
      ],
    );
  }

  return messageTextRich(text, isMe);
}

String _fmtVoiceDuration(Duration d) {
  final total = d.inSeconds.clamp(0, 86400);
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

Duration _voiceHintDuration(int? sec) {
  if (sec != null && sec > 0) return Duration(seconds: sec);
  return Duration.zero;
}

class VoiceMessageRow extends StatefulWidget {
  final String url;
  final int? durationSec;
  final bool isMe;

  const VoiceMessageRow({
    super.key,
    required this.url,
    this.durationSec,
    required this.isMe,
  });

  @override
  State<VoiceMessageRow> createState() => _VoiceMessageRowState();
}

class _VoiceMessageRowState extends State<VoiceMessageRow> {
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final svc = Get.find<ChatVoicePlaybackService>();
      final isActive = svc.activeUrl.value == widget.url;
      final playing = isActive && svc.playing.value;
      final position = isActive ? svc.position.value : Duration.zero;
      final effectiveDur = isActive
          ? svc.effectiveDuration(widget.durationSec)
          : _voiceHintDuration(widget.durationSec);
      final busy = isActive && svc.loadCount.value > 0;
      final err = isActive ? svc.playbackError.value : null;
      final speedLabel = svc.playbackSpeedLabel();

      final ms = effectiveDur.inMilliseconds;
      final canScrub = ms > 0;
      double sliderValue() {
        if (ms <= 0) return 0;
        if (_dragFraction != null) return _dragFraction!.clamp(0.0, 1.0);
        return (position.inMilliseconds / ms).clamp(0.0, 1.0);
      }

      final primary = widget.isMe
          ? Colors.white
          : Theme.of(context).colorScheme.onSurface;
      final secondary = widget.isMe
          ? Colors.white.withValues(alpha: 0.72)
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
      final track = widget.isMe
          ? Colors.white.withValues(alpha: 0.35)
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18);
      final progress = widget.isMe
          ? Colors.white.withValues(alpha: 0.92)
          : _kChatAccentBlue;

      return Directionality(
        textDirection: TextDirection.ltr,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 268),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: busy
                        ? Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primary,
                              ),
                            ),
                          )
                        : IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => unawaited(
                              svc.toggle(
                                widget.url,
                                durationHintSec: widget.durationSec,
                              ),
                            ),
                            icon: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: primary,
                              size: 34,
                            ),
                          ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        activeTrackColor: progress,
                        inactiveTrackColor: track,
                        thumbColor: primary,
                        overlayColor: primary.withValues(alpha: 0.14),
                      ),
                      child: Slider(
                        value: sliderValue().clamp(0.0, 1.0),
                        onChanged: canScrub && isActive
                            ? (v) => setState(() => _dragFraction = v)
                            : null,
                        onChangeEnd: canScrub && isActive
                            ? (v) {
                                setState(() => _dragFraction = null);
                                unawaited(
                                  svc.seekToFraction(v, widget.durationSec),
                                );
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 44, end: 6),
                child: Row(
                  children: [
                    Text(
                      _fmtVoiceDuration(
                        _dragFraction != null && ms > 0
                            ? Duration(
                                milliseconds: (_dragFraction! * ms).round(),
                              )
                            : position,
                      ),
                      style: TextStyle(fontSize: 11.5, color: secondary),
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => unawaited(svc.cyclePlaybackSpeed()),
                        borderRadius: BorderRadius.circular(6),
                        child: Tooltip(
                          message: AppLocaleKeys.chatVoicePlaybackSpeed.tr,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              speedLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _fmtVoiceDuration(effectiveDur),
                      style: TextStyle(fontSize: 11.5, color: secondary),
                    ),
                  ],
                ),
              ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    AppLocaleKeys.errorsServer.tr,
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isMe
                          ? Colors.orange.shade100
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _ChatImageBubble extends StatelessWidget {
  final String url;
  final bool isMe;

  const _ChatImageBubble({required this.url, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _RetryableChatImage(
        url: url,
        width: 200,
        fit: BoxFit.cover,
        isMe: isMe,
        onImageTap: () => openChatMediaFromUrl(url),
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
  final VoidCallback? onImageTap;

  const _RetryableChatImage({
    required this.url,
    required this.width,
    required this.fit,
    required this.isMe,
    this.loadingHeight = 120,
    this.onImageTap,
  });

  @override
  State<_RetryableChatImage> createState() => _RetryableChatImageState();
}

class _RetryableChatImageState extends State<_RetryableChatImage> {
  @override
  Widget build(BuildContext context) {
    final image = ChatCachedAttachmentImage(
      url: widget.url,
      width: widget.width,
      fit: widget.fit,
      loadingBuilder: (c, w, p) => SizedBox(
        height: widget.loadingHeight,
        width: widget.width,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorBuilder: (_, __) => SizedBox(
        height: widget.loadingHeight,
        width: widget.width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.refresh,
              size: 24,
              color: widget.isMe ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(height: 4),
            Text(
              'Retry',
              style: TextStyle(
                fontSize: 11,
                color: widget.isMe ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
    if (widget.onImageTap == null) return image;
    return InkWell(onTap: widget.onImageTap, child: image);
  }
}

class _ChatVideoBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  final String? fileName;

  const _ChatVideoBubble({
    required this.url,
    required this.isMe,
    this.fileName,
  });

  @override
  State<_ChatVideoBubble> createState() => _ChatVideoBubbleState();
}

class _ChatVideoBubbleState extends State<_ChatVideoBubble> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      final c = await chatVideoControllerForUrl(widget.url)
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
    }
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
    final placeholder = Container(
      width: maxW,
      height: maxW * 9 / 16,
      alignment: Alignment.center,
      color: widget.isMe
          ? Colors.black.withValues(alpha: 0.22)
          : Colors.black.withValues(alpha: 0.07),
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: widget.isMe
              ? Colors.white70
              : Theme.of(context).colorScheme.primary,
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
                          color: Colors.black,
                          child: VideoPlayer(_controller!),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => openChatMediaFromUrl(widget.url),
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
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_rounded,
                                  size: 58,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 12,
                                      color: Colors.black54,
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
                : placeholder,
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
                color: widget.isMe ? Colors.white70 : Colors.black54,
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

  const _FileBubble({required this.url, this.fileName, required this.isMe});

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
          onTap: () => openChatMediaFromUrl(url),
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

Widget messageTextRich(String text, bool isMe) {
  return Builder(
    builder: (context) {
      final resolvedDirection = chatMessageTextDirectionFromFirstWord(text) ??
          Directionality.of(context);
      final matches = linkifiedUrlRegex.allMatches(text);

      final style = TextStyle(
        fontSize: 15,
        color: isMe ? Colors.white : Colors.black,
      );

      final child = matches.isEmpty
          ? Text(text, style: style)
          : RichText(
              text: TextSpan(children: buildMessageSpans(text, isMe), style: style),
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

List<InlineSpan> buildMessageSpans(String text, bool isMe) {
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
              child: InkWell(
                onTap: () => openChatMediaFromUrl(url),
                child: _RetryableChatImage(
                  url: url,
                  width: 200,
                  fit: BoxFit.cover,
                  isMe: isMe,
                  loadingHeight: 150,
                ),
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
            ..onTap = () => openChatMediaFromUrl(url),
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
