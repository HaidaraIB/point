import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Models/VoiceRecordEntry.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Shared/safe_network_image.dart';
import 'package:point/View/Shared/voice_message_row.dart';

class TaskTimelineWidget extends StatefulWidget {
  final List<TaskTimelineEvent> events;
  /// Used to recover voice players for older comment events that only stored
  /// a text placeholder (no [TaskTimelineEvent.voiceRecords]).
  final List<NoteModel> notes;

  const TaskTimelineWidget({
    super.key,
    required this.events,
    this.notes = const [],
  });

  @override
  State<TaskTimelineWidget> createState() => _TaskTimelineWidgetState();
}

class _TaskTimelineWidgetState extends State<TaskTimelineWidget> {
  /// Default: oldest at top (story order).
  bool _oldestFirst = true;

  int _compareEvents(TaskTimelineEvent a, TaskTimelineEvent b) {
    final byTime = a.timestamp.compareTo(b.timestamp);
    if (byTime != 0) return _oldestFirst ? byTime : -byTime;
    final byType = a.type.compareTo(b.type);
    if (byType != 0) return byType;
    return a.label.compareTo(b.label);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const SizedBox.shrink();
    }
    final sorted = List<TaskTimelineEvent>.from(widget.events)
      ..sort(_compareEvents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'tasks.timeline_title'.tr,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.appTheme.primaryText,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _oldestFirst = !_oldestFirst),
              child: Text('tasks.timeline.toggle_order'.tr),
            ),
          ],
        ),
        Text(
          _oldestFirst
              ? 'tasks.timeline.order_oldest_first'.tr
              : 'tasks.timeline.order_newest_first'.tr,
          style: TextStyle(fontSize: 11, color: context.appTheme.mutedText),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: context.appTheme.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appTheme.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < sorted.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Column(
                        children: [
                          Container(
                            width: 2,
                            height: 10,
                            color:
                                i == 0
                                    ? Colors.transparent
                                    : context.appTheme.border,
                          ),
                          Text(
                            '${i + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: context.appTheme.mutedText,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 10,
                            color:
                                i == sorted.length - 1
                                    ? Colors.transparent
                                    : context.appTheme.border,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _TimelineRow(
                        event: sorted[i],
                        notes: widget.notes,
                      ),
                    ),
                  ],
                ),
                if (i < sorted.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TaskTimelineEvent event;
  final List<NoteModel> notes;

  const _TimelineRow({required this.event, this.notes = const []});

  static String _formatValue(String v) {
    final d = DateTime.tryParse(v);
    if (d != null) return FunHelper.formatdate(d) ?? v;
    // ترجمة الحالة والأولوية وغيرها لعرضها بشكل مقروء
    return v.tr;
  }

  /// Older voice-comment events stored only an emoji label in [newValue].
  static bool _isLegacyVoicePlaceholder(String value) {
    final v = value.trim();
    return v.contains('🎤') ||
        v == 'tasks.form.voice_record'.tr ||
        v.endsWith('tasks.form.voice_record'.tr);
  }

  List<VoiceRecordEntry> _resolvedVoiceRecords() {
    if (event.hasVoice) return event.voiceRecords;
    if (event.type != 'note_added' || notes.isEmpty) return const [];

    // Match older timeline comments to notes by author + nearby timestamp.
    NoteModel? best;
    var bestDiff = const Duration(minutes: 3);
    for (final note in notes) {
      if (!note.hasVoice) continue;
      if (note.byWho.trim() != event.byUserName.trim()) continue;
      final diff = note.timestamp.difference(event.timestamp).abs();
      if (diff <= bestDiff) {
        best = note;
        bestDiff = diff;
      }
    }
    return best?.voiceRecords ?? const [];
  }

  static String _attachmentFileName(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return v;
    final uri = Uri.tryParse(v);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return Uri.decodeComponent(uri.pathSegments.last);
    }
    return v;
  }

  static bool _isLikelyImage(String raw) => isImageMediaUrl(raw);

  Future<void> _openAttachment(BuildContext context, String rawUrl) async {
    await openUrlPreferInAppMedia(rawUrl);
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'created':
        return Icons.add_circle_outline;
      case 'executor_changed':
        return Icons.person_outline;
      case 'from_date_changed':
      case 'to_date_changed':
        return Icons.calendar_today_outlined;
      case 'priority_changed':
        return Icons.flag_outlined;
      case 'status_changed':
        return Icons.info_outline;
      case 'note_added':
        return Icons.note_add_outlined;
      case 'attachment_added':
        return Icons.attach_file;
      case 'final_deliverable_attachment_added':
        return Icons.outbox_outlined;
      case 'management_edit_request':
        return Icons.edit_note_outlined;
      case 'rejection_feedback':
        return Icons.cancel_outlined;
      case 'deadline_extension_requested':
        return Icons.event_repeat_outlined;
      case 'deadline_extension_approved':
        return Icons.event_available_outlined;
      case 'deadline_extension_denied':
        return Icons.event_busy_outlined;
      case 'audience_changed':
        return Icons.people_outline;
      case 'category_changed':
        return Icons.label_outline;
      case 'field_changed':
        return Icons.edit_note;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final voices = _resolvedVoiceRecords()
        .where((e) => e.url.trim().isNotEmpty)
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Icon(_iconForType(event.type), size: 18, color: context.appTheme.accentText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.label.tr,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: context.appTheme.primaryText,
                ),
              ),
              if (event.oldValue != null ||
                  event.newValue != null ||
                  voices.isNotEmpty) ...[
                const SizedBox(height: 4),
                if (event.oldValue != null)
                  LinkifiedText(
                    'timeline.value_from'
                        .trParams({'value': _formatValue(event.oldValue!)}),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTheme.secondaryText,
                    ),
                  ),
                if ((event.type == 'attachment_added' ||
                        event.type == 'final_deliverable_attachment_added') &&
                    event.newValue != null)
                  _AttachmentTimelineValue(
                    rawValue: event.newValue!,
                    onOpen: () => _openAttachment(context, event.newValue!),
                  )
                else if (event.newValue != null &&
                    !_isLegacyVoicePlaceholder(event.newValue!))
                  LinkifiedText(
                    'timeline.value_to'
                        .trParams({'value': _formatValue(event.newValue!)}),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTheme.secondaryText,
                    ),
                  ),
                if (voices.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...voices.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: VoiceMessageRow(
                        url: record.url,
                        durationSec: record.durationSec > 0
                            ? record.durationSec
                            : null,
                        isMe: false,
                        compact: true,
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.byUserName,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    FunHelper.formatdate(event.timestamp) ?? '',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTheme.mutedText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentTimelineValue extends StatelessWidget {
  final String rawValue;
  final VoidCallback onOpen;

  const _AttachmentTimelineValue({required this.rawValue, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final fileName = _TimelineRow._attachmentFileName(rawValue);
    final isImage = _TimelineRow._isLikelyImage(rawValue);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.panelTint,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child:
                      isImage
                          ? SafeNetworkImage(
                            rawValue,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => Container(
                                  color: theme.unselected,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: theme.mutedText,
                                  ),
                                ),
                          )
                          : Container(
                            color: theme.unselected,
                            child: Icon(
                              Icons.insert_drive_file_outlined,
                              color: theme.mutedText,
                            ),
                          ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new, size: 16, color: theme.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
