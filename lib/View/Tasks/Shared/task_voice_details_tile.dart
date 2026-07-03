import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/View/Shared/voice_message_row.dart';
import 'package:point/View/Tasks/Shared/task_voice_form_helpers.dart';

/// Read-only voice note playback for task details screens.
class TaskVoiceDetailsTile extends StatelessWidget {
  final TaskModel task;

  const TaskVoiceDetailsTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final records = voiceRecordsFromTask(task);
    if (records.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tasks.form.voice_record'.tr,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...records.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index < records.length - 1 ? 8 : 0),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'tasks.form.voice_record'.tr} ${index + 1}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      VoiceMessageRow(
                        url: record.url,
                        durationSec:
                            record.durationSec > 0 ? record.durationSec : null,
                        isMe: false,
                        compact: false,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
