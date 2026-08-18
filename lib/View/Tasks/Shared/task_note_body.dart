import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Shared/voice_message_row.dart';

/// Text + optional voice playback for a task [NoteModel].
class TaskNoteBody extends StatelessWidget {
  final NoteModel note;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle? style;
  final bool compactVoice;
  final bool linkify;
  final bool selectable;

  const TaskNoteBody({
    super.key,
    required this.note,
    this.maxLines,
    this.overflow,
    this.style,
    this.compactVoice = true,
    this.linkify = true,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = note.note.trim();
    final voices = note.voiceRecords
        .where((e) => e.url.trim().isNotEmpty)
        .toList();
    final resolvedStyle = style ??
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.appTheme.primaryText,
        );

    if (text.isEmpty && voices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text.isNotEmpty)
          linkify
              ? LinkifiedText(
                  text,
                  selectable: selectable,
                  maxLines: maxLines,
                  overflow: overflow ??
                      (maxLines == null
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis),
                  style: resolvedStyle,
                )
              : selectable
                  ? SelectableText(
                      text,
                      maxLines: maxLines,
                      style: resolvedStyle,
                    )
                  : Text(
                      text,
                      maxLines: maxLines,
                      overflow: overflow ??
                          (maxLines == null
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis),
                      style: resolvedStyle,
                    )
        else if (voices.isNotEmpty)
          Text(
            'tasks.form.voice_record'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolvedStyle,
          ),
        if (voices.isNotEmpty) ...[
          if (text.isNotEmpty) const SizedBox(height: 6),
          ...voices.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < voices.length - 1 ? 6 : 0,
              ),
              child: VoiceMessageRow(
                url: record.url,
                durationSec: record.durationSec > 0 ? record.durationSec : null,
                isMe: false,
                compact: compactVoice,
              ),
            );
          }),
        ],
      ],
    );
  }
}
