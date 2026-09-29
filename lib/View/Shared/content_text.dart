import 'package:flutter/material.dart';
import 'package:point/Utils/chat_message_bidi.dart';

/// Read-only text with paragraph direction from [text] content, not UI locale.
class ContentText extends StatelessWidget {
  const ContentText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      textDirection: contentParagraphTextDirection(text),
    );
  }
}

/// Selectable variant of [ContentText].
class ContentSelectableText extends StatelessWidget {
  const ContentSelectableText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: style,
      maxLines: maxLines,
      textAlign: textAlign,
      textDirection: contentParagraphTextDirection(text),
    );
  }
}
