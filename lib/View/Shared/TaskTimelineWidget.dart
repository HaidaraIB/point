import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';

class TaskTimelineWidget extends StatelessWidget {
  final List<TaskTimelineEvent> events;

  const TaskTimelineWidget({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }
    final sorted = List<TaskTimelineEvent>.from(events)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'tasks.timeline_title'.tr,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryfontColor,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              for (var i = 0; i < sorted.length; i++) ...[
                _TimelineRow(event: sorted[i]),
                if (i < sorted.length - 1) const SizedBox(height: 16),
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

  const _TimelineRow({required this.event});

  static String _formatValue(String v) {
    final d = DateTime.tryParse(v);
    if (d != null) return FunHelper.formatdate(d) ?? v;
    // ترجمة الحالة والأولوية وغيرها لعرضها بشكل مقروء
    return v.tr;
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Icon(_iconForType(event.type), size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.label.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.primaryfontColor,
                ),
              ),
              if (event.oldValue != null || event.newValue != null) ...[
                const SizedBox(height: 4),
                if (event.oldValue != null)
                  Text(
                    'timeline.value_from'
                        .trParams({'value': _formatValue(event.oldValue!)}),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                if (event.newValue != null)
                  Text(
                    'timeline.value_to'
                        .trParams({'value': _formatValue(event.newValue!)}),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.byUserName.tr,
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
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
