import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/VoiceRecordEntry.dart';
import 'package:point/Services/chat_voice_playback_service.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Chats/voice_recorder_scope.dart';
import 'package:point/View/Shared/voice_message_row.dart';

/// Task/update form voice field — multiple notes, full chat-style playback.
class TaskVoiceRecordField extends StatefulWidget {
  final List<VoiceRecordEntry> records;
  final ValueChanged<List<VoiceRecordEntry>> onRecordsChanged;

  const TaskVoiceRecordField({
    super.key,
    required this.records,
    required this.onRecordsChanged,
  });

  @override
  State<TaskVoiceRecordField> createState() => _TaskVoiceRecordFieldState();
}

class _TaskVoiceRecordFieldState extends State<TaskVoiceRecordField> {
  late final VoiceRecorderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VoiceRecorderController(
      scopeId: 'task_form_voice',
      usage: VoiceRecorderUsage.form,
      onSaved: _appendRecord,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _appendRecord(String url, int durationSec) async {
    final next = [
      ...widget.records,
      VoiceRecordEntry(url: url, durationSec: durationSec),
    ];
    widget.onRecordsChanged(next);
    if (mounted) setState(() {});
  }

  void _removeAt(int index) {
    final removed = widget.records[index];
    final next = [...widget.records]..removeAt(index);
    widget.onRecordsChanged(next);
    if (Get.isRegistered<ChatVoicePlaybackService>()) {
      final playback = Get.find<ChatVoicePlaybackService>();
      if (playback.activeUrl.value == removed.url && playback.playing.value) {
        unawaited(
          playback.toggle(removed.url, durationHintSec: removed.durationSec),
        );
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VoiceRecorderScope(
      controller: _controller,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tasks.form.voice_record'.tr,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryfontColor,
            ),
          ),
          const SizedBox(height: 8),
          const VoiceRecorderActiveStrip(padding: EdgeInsets.zero),
          if (widget.records.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...widget.records.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < widget.records.length - 1 ? 8 : 0,
                ),
                child: _VoiceRecordListTile(
                  index: index,
                  record: record,
                  onRemove: () => _removeAt(index),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
          _AddVoiceNoteButton(controller: _controller),
        ],
      ),
    );
  }
}

class _VoiceRecordListTile extends StatelessWidget {
  final int index;
  final VoiceRecordEntry record;
  final VoidCallback onRemove;

  const _VoiceRecordListTile({
    required this.index,
    required this.record,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppLocaleKeys.chatAttachVoice.tr} ${index + 1}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'tasks.form.voice_record_clear'.tr,
                  icon: Icon(Icons.close, color: theme.colorScheme.error, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
            VoiceMessageRow(
              url: record.url,
              durationSec: record.durationSec > 0 ? record.durationSec : null,
              isMe: false,
              compact: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddVoiceNoteButton extends StatelessWidget {
  final VoiceRecorderController controller;

  const _AddVoiceNoteButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isActive) return const SizedBox.shrink();

        return Obx(() {
          final busy = Get.find<HomeController>().isUploading.value ||
              Get.find<HomeController>().isChatUploadActiveFor(controller.scopeId);

          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : controller.startRecording,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                    )
                  : const Icon(Icons.add, color: AppColors.primary),
              label: Text(
                'tasks.form.voice_record_add'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
