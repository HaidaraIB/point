import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/Mobile/Shared/VideoCart.dart';
import 'package:url_launcher/url_launcher.dart';

final RegExp _urlRegex = RegExp(
  r'((?:https?:\/\/|www\.|(?:[a-z0-9-]+\.)+[a-z]{2,})(?:\/[^\s]*)?)',
  caseSensitive: false,
);
final RegExp linkifiedUrlRegex = _urlRegex;

String _mediaPathLower(String rawUrl) {
  try {
    return Uri.parse(rawUrl).path.toLowerCase();
  } catch (_) {
    return rawUrl.toLowerCase();
  }
}

bool isImageMediaUrl(String rawUrl) {
  final p = _mediaPathLower(rawUrl);
  return p.endsWith('.png') ||
      p.endsWith('.jpg') ||
      p.endsWith('.jpeg') ||
      p.endsWith('.gif') ||
      p.endsWith('.webp');
}

bool isVideoMediaUrl(String rawUrl) {
  final p = _mediaPathLower(rawUrl);
  return p.endsWith('.mp4') ||
      p.endsWith('.mov') ||
      p.endsWith('.webm') ||
      p.endsWith('.m4v') ||
      p.endsWith('.avi') ||
      p.endsWith('.mkv');
}

/// Attachment kind from URL **path** extension (query strings ignored).
///
/// Use this instead of `url.toLowerCase().endsWith('.jpg')` — prod URLs often
/// look like `file.jpg?alt=media&token=…` / `?download=…` and those fail naive checks.
String getFileType(String url) {
  if (isImageMediaUrl(url)) return 'image';
  if (isVideoMediaUrl(url)) return 'video';
  final path = _mediaPathLower(url);
  if (path.endsWith('.pdf')) return 'pdf';
  return 'unknown';
}

String normalizeUrlForLaunch(String rawUrl) {
  final trimmed = rawUrl.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('www.')) {
    return 'https://$trimmed';
  }
  if (!lower.startsWith('http://') &&
      !lower.startsWith('https://') &&
      RegExp(r'^(?:[a-z0-9-]+\.)+[a-z]{2,}(?:[\/?#].*)?$', caseSensitive: false)
          .hasMatch(trimmed)) {
    return 'https://$trimmed';
  }
  return trimmed;
}

bool containsUrlText(String text) => _urlRegex.hasMatch(text);

bool isLikelyUrlValue(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(
    r'^(?:https?:\/\/|www\.|(?:[a-z0-9-]+\.)+[a-z]{2,})(?:[\/?#].*)?$',
    caseSensitive: false,
  ).hasMatch(trimmed);
}

Future<bool> openUrlPreferInAppMedia(
  String rawUrl, {
  bool showErrorSnackbar = true,
}) async {
  final trimmed = normalizeUrlForLaunch(rawUrl);
  if (trimmed.isEmpty) return false;

  if (isImageMediaUrl(trimmed)) {
    Get.to(() => ImagePreviewPage(url: trimmed));
    return true;
  }
  if (isVideoMediaUrl(trimmed)) {
    Get.to(() => VideoPlayerPage(url: trimmed));
    return true;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    if (showErrorSnackbar) {
      FunHelper.showSnackbar(
        'error'.tr,
        'errors.cannot_open_link_param'.trParams({'url': trimmed}),
      );
    }
    return false;
  }

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && showErrorSnackbar) {
    FunHelper.showSnackbar(
      'error'.tr,
      'errors.cannot_open_link_param'.trParams({'url': trimmed}),
    );
  }
  return ok;
}

class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool selectable;
  final Future<void> Function(String url)? onOpenUrl;

  const LinkifiedText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
    this.selectable = false,
    this.onOpenUrl,
  });

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _urlRegex.allMatches(widget.text).toList();
    if (matches.isEmpty) {
      if (widget.selectable) {
        return SelectableText(
          widget.text,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          style: widget.style,
        );
      }
      return Text(
        widget.text,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        style: widget.style,
      );
    }

    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var lastIndex = 0;
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(widget.style);
    final effectiveLinkStyle = effectiveStyle.merge(
      widget.linkStyle ??
          TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
    );

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: widget.text.substring(lastIndex, match.start)));
      }

      final url = match.group(0)!;
      final recognizer =
          TapGestureRecognizer()
            ..onTap = () {
              final open = widget.onOpenUrl ?? openUrlPreferInAppMedia;
              open(url);
            };
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(text: url, style: effectiveLinkStyle, recognizer: recognizer),
      );
      lastIndex = match.end;
    }

    if (lastIndex < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(lastIndex)));
    }

    final rich = TextSpan(style: effectiveStyle, children: spans);
    if (widget.selectable) {
      return SelectableText.rich(
        rich,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
      );
    }
    return Text.rich(
      rich,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
