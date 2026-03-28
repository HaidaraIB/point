import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
    final name = fileName ?? url.split('/').last.split('?').first;
    final color = isMe ? Colors.white : Colors.blue.shade800;
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: color, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                color: color,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
