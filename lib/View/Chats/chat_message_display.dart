import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:url_launcher/url_launcher.dart';

/// روابط داخل نص الرسالة (للرسائل النصية التقليدية).
final urlRegex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

/// محتوى فقاعة الرسالة حسب [messageType] مع دعم الرسائل القديمة (نص + رابط فقط).
Widget chatMessageBubbleContent(Map<String, dynamic> msg, bool isMe) {
  final type = (msg['messageType'] as String?)?.trim();
  final attachmentUrl = (msg['attachmentUrl'] as String?)?.trim();
  final text = (msg['text'] ?? '') as String;

  if (type == 'voice') {
    final url = (attachmentUrl != null && attachmentUrl.isNotEmpty)
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
  if (type == 'image' &&
      attachmentUrl != null &&
      attachmentUrl.isNotEmpty) {
    return _ChatImageBubble(url: attachmentUrl, isMe: isMe);
  }
  if (type == 'file' &&
      attachmentUrl != null &&
      attachmentUrl.isNotEmpty) {
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
  StreamSubscription<void>? _completeSub;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    unawaited(_completeSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    await _player.play(UrlSource(widget.url));
    if (mounted) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final dur = widget.durationSec;
    final label =
        dur != null ? '${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}' : '…';
    final iconColor = widget.isMe ? Colors.white : Colors.black87;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggle,
          icon: Icon(
            _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: iconColor,
            size: 32,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: iconColor),
        ),
      ],
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
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Image.network(
          url,
          width: 200,
          fit: BoxFit.cover,
          loadingBuilder: (c, w, p) {
            if (p == null) return w;
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (_, __, ___) => Icon(
            Icons.broken_image,
            size: 40,
            color: isMe ? Colors.white70 : Colors.black45,
          ),
        ),
      ),
    );
  }
}

class _FileBubble extends StatelessWidget {
  final String url;
  final String? fileName;
  final bool isMe;

  const _FileBubble({
    required this.url,
    this.fileName,
    required this.isMe,
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
    final subtitle = ext.isNotEmpty ? '${ext.toUpperCase()} · $tapHint' : tapHint;

    final primary = isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final secondary = isMe
        ? Colors.white.withValues(alpha: 0.72)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final iconBg = isMe
        ? Colors.white.withValues(alpha: 0.22)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    final iconFg = isMe ? Colors.white : Theme.of(context).colorScheme.primary;
    final tileBg = isMe
        ? Colors.white.withValues(alpha: 0.2)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.65,
            );
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
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
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
                        style: TextStyle(
                          fontSize: 11,
                          color: secondary,
                        ),
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
      style: TextStyle(
        fontSize: 15,
        color: isMe ? Colors.white : Colors.black,
      ),
    );
  }

  return RichText(
    text: TextSpan(
      children: buildMessageSpans(text, isMe),
      style: TextStyle(
        fontSize: 15,
        color: isMe ? Colors.white : Colors.black,
      ),
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

bool isImageUrl(String url) {
  final u = url.toLowerCase();
  return u.endsWith('.png') ||
      u.endsWith('.jpg') ||
      u.endsWith('.jpeg') ||
      u.endsWith('.gif') ||
      u.endsWith('.webp');
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
                onTap: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
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
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    size: 40,
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
              TapGestureRecognizer()
                ..onTap = () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
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
