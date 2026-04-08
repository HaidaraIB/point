import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/chat_voice_cache.dart';
import 'package:point/View/Mobile/Shared/VideoCart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// روابط داخل نص الرسالة (للرسائل النصية التقليدية).
final urlRegex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

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
  final type = (msg['messageType'] as String?)?.trim();
  final attachmentUrl = (msg['attachmentUrl'] as String?)?.trim();
  final text = (msg['text'] ?? '') as String;

  if (type == 'voice') {
    final url =
        (attachmentUrl != null && attachmentUrl.isNotEmpty)
            ? attachmentUrl
            : text;
    if (url.startsWith('http')) {
      return VoiceMessageRow(
        url: url,
        durationSec: msg['durationSec'] as int?,
        isMe: isMe,
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
    return _ChatVideoBubble(
      url: attachmentUrl,
      isMe: isMe,
      fileName: msg['fileName'] as String?,
    );
  }
  if (type == 'file' && attachmentUrl != null && attachmentUrl.isNotEmpty) {
    return _FileBubble(
      url: attachmentUrl,
      fileName: msg['fileName'] as String?,
      isMe: isMe,
    );
  }

  return messageTextRich(text, isMe);
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
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _sourceReady = false;
  int _loadCount = 0;
  Object? _error;
  double? _dragFraction;

  @override
  void initState() {
    super.initState();
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
    final hint = widget.durationSec;
    if (hint != null && hint > 0) {
      _duration = Duration(seconds: hint);
    }

    _posSub = _player.onPositionChanged.listen((d) {
      if (!mounted || _dragFraction != null) return;
      setState(() => _position = d);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted || d <= Duration.zero) return;
      setState(() => _duration = d);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
        _dragFraction = null;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_posSub?.cancel());
    unawaited(_durSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_completeSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Duration get _effectiveDuration {
    if (_duration > Duration.zero) return _duration;
    final hint = widget.durationSec;
    if (hint != null && hint > 0) return Duration(seconds: hint);
    return Duration.zero;
  }

  String _fmt(Duration d) {
    final total = d.inSeconds.clamp(0, 86400);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  double get _sliderValue {
    final ms = _effectiveDuration.inMilliseconds;
    if (ms <= 0) return 0;
    if (_dragFraction != null) return _dragFraction!.clamp(0.0, 1.0);
    return (_position.inMilliseconds / ms).clamp(0.0, 1.0);
  }

  Future<void> _ensureSourceLoaded({required bool trackBusy}) async {
    if (_sourceReady) return;
    if (trackBusy && mounted) setState(() => _loadCount++);
    try {
      final source = await ChatVoiceCache.sourceForUrl(widget.url);
      if (!mounted) return;
      await _player.setSource(source);
      if (!mounted) return;
      setState(() {
        _sourceReady = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
      rethrow;
    } finally {
      if (trackBusy && mounted) {
        setState(() {
          if (_loadCount > 0) _loadCount--;
        });
      }
    }
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        return;
      }
      if (!_sourceReady) {
        if (mounted) setState(() => _loadCount++);
        try {
          final source = await ChatVoiceCache.sourceForUrl(widget.url);
          if (!mounted) return;
          await _player.play(source);
          if (mounted) {
            setState(() {
              _sourceReady = true;
              _error = null;
            });
          }
        } catch (e) {
          if (mounted) setState(() => _error = e);
        } finally {
          if (mounted) {
            setState(() {
              if (_loadCount > 0) _loadCount--;
            });
          }
        }
        return;
      }
      await _player.resume();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _onSeekEnd(double fraction) async {
    final ms = _effectiveDuration.inMilliseconds;
    if (ms <= 0) return;
    setState(() => _dragFraction = null);
    final target = Duration(milliseconds: (fraction * ms).round());
    try {
      await _ensureSourceLoaded(trackBusy: !_sourceReady);
      if (!mounted) return;
      await _player.seek(target);
      setState(() => _position = target);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary =
        widget.isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final secondary =
        widget.isMe
            ? Colors.white.withValues(alpha: 0.72)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final track =
        widget.isMe
            ? Colors.white.withValues(alpha: 0.35)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18);
    final progress =
        widget.isMe
            ? Colors.white.withValues(alpha: 0.92)
            : Theme.of(context).colorScheme.primary;

    final busy = _loadCount > 0;
    final canScrub = _effectiveDuration.inMilliseconds > 0;

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
                  child:
                      busy
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
                            onPressed: _toggle,
                            icon: Icon(
                              _playing
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
                      value: _sliderValue.clamp(0.0, 1.0),
                      onChanged:
                          canScrub
                              ? (v) => setState(() => _dragFraction = v)
                              : null,
                      onChangeEnd: canScrub ? _onSeekEnd : null,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 44, end: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(
                      _dragFraction != null
                          ? Duration(
                            milliseconds:
                                (_dragFraction! *
                                        _effectiveDuration.inMilliseconds)
                                    .round(),
                          )
                          : _position,
                    ),
                    style: TextStyle(fontSize: 11.5, color: secondary),
                  ),
                  Text(
                    _fmt(_effectiveDuration),
                    style: TextStyle(fontSize: 11.5, color: secondary),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  AppLocaleKeys.errorsServer.tr,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        widget.isMe
                            ? Colors.orange.shade100
                            : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
  int _retrySeed = 0;

  void _retry() {
    final provider = NetworkImage(widget.url);
    provider.evict();
    setState(() => _retrySeed++);
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      widget.url,
      key: ValueKey('${widget.url}#$_retrySeed'),
      width: widget.width,
      fit: widget.fit,
      loadingBuilder: (c, w, p) {
        if (p == null) return w;
        return SizedBox(
          height: widget.loadingHeight,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder:
          (_, __, ___) => InkWell(
            onTap: _retry,
            child: SizedBox(
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
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.url))
          ..setLooping(false)
          ..setVolume(0);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          _controller.pause();
          setState(() => _ready = true);
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
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
      color:
          widget.isMe
              ? Colors.black.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.07),
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color:
              widget.isMe
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
            child:
                _ready && _controller.value.aspectRatio > 0
                    ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: Colors.black,
                            child: VideoPlayer(_controller),
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
    final title =
        _isStorageStyleUuidName(titleBase)
            ? AppLocaleKeys.chatFileUntitled.tr
            : titleBase;

    final tapHint = AppLocaleKeys.chatFileTapToOpen.tr;
    final subtitle =
        ext.isNotEmpty ? '${ext.toUpperCase()} · $tapHint' : tapHint;

    final primary =
        isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final secondary =
        isMe
            ? Colors.white.withValues(alpha: 0.72)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final iconBg =
        isMe
            ? Colors.white.withValues(alpha: 0.22)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    final iconFg = isMe ? Colors.white : Theme.of(context).colorScheme.primary;
    final tileBg =
        isMe
            ? Colors.white.withValues(alpha: 0.2)
            : Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);
    final borderColor =
        isMe
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
  final matches = urlRegex.allMatches(text);

  if (matches.isEmpty) {
    return Text(
      text,
      style: TextStyle(fontSize: 15, color: isMe ? Colors.white : Colors.black),
    );
  }

  return RichText(
    text: TextSpan(
      children: buildMessageSpans(text, isMe),
      style: TextStyle(fontSize: 15, color: isMe ? Colors.white : Colors.black),
    ),
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

  for (final match in urlRegex.allMatches(text)) {
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
                child: Image.network(
                  url,
                  width: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, w, p) {
                    if (p == null) return w;
                    return const SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder:
                      (_, __, ___) => _RetryableChatImage(
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
          recognizer:
              TapGestureRecognizer()..onTap = () => openChatMediaFromUrl(url),
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
