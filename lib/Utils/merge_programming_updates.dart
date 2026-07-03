import 'package:get/get.dart';
import 'package:point/Models/ProgrammingModel.dart';
import 'package:point/Models/ProgrammingUpdateModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Models/VoiceRecordEntry.dart';
import 'package:point/Services/StorageKeys.dart';

String programmingUpdateMergeKey(String value) => value.trim();

/// Whether two updates can be merged into one task (same client + assignee).
bool canMergeProgrammingUpdates(
  ProgrammingUpdateModel a,
  ProgrammingUpdateModel b,
) {
  return programmingUpdateMergeKey(a.clientName) ==
          programmingUpdateMergeKey(b.clientName) &&
      programmingUpdateMergeKey(a.assignedTo) ==
          programmingUpdateMergeKey(b.assignedTo);
}

/// Returns a translation key when [updates] cannot be merged, or null if valid.
String? validateProgrammingUpdatesMerge(List<ProgrammingUpdateModel> updates) {
  if (updates.length <= 1) return null;

  final clientKey = programmingUpdateMergeKey(updates.first.clientName);
  final employeeKey = programmingUpdateMergeKey(updates.first.assignedTo);

  for (final update in updates.skip(1)) {
    if (programmingUpdateMergeKey(update.clientName) != clientKey) {
      return 'programming.updates.merge_same_client_required';
    }
    if (programmingUpdateMergeKey(update.assignedTo) != employeeKey) {
      return 'programming.updates.merge_same_employee_required';
    }
  }
  return null;
}

/// Builds a programming task draft from one or more pending updates.
TaskModel buildTaskDraftFromUpdates(List<ProgrammingUpdateModel> updates) {
  if (updates.isEmpty) {
    throw ArgumentError('updates must not be empty');
  }

  final mergeIssue = validateProgrammingUpdatesMerge(updates);
  if (mergeIssue != null) {
    throw ArgumentError(mergeIssue.tr);
  }
  String firstNonEmpty(Iterable<String> values) {
    for (final v in values) {
      final t = v.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  DateTime? firstDate(Iterable<DateTime?> values) {
    for (final d in values) {
      if (d != null) return d;
    }
    return null;
  }

  final titles = updates.map((u) => u.title.trim()).where((t) => t.isNotEmpty);
  final title = titles.isNotEmpty
      ? titles.first
      : 'programming.updates.combined_title_fallback'
          .trParams({'count': '${updates.length}'});

  final descBlocks = <String>[];
  for (var i = 0; i < updates.length; i++) {
    final u = updates[i];
    final blockTitle = u.title.trim().isNotEmpty
        ? u.title.trim()
        : 'programming.updates.update_n'.trParams({'n': '${i + 1}'});
    final body = u.description.trim();
    if (body.isNotEmpty) {
      descBlocks.add('## $blockTitle\n$body');
    } else if (u.title.trim().isNotEmpty) {
      descBlocks.add('## $blockTitle');
    }
  }

  final mergedVoiceRecords = <VoiceRecordEntry>[];
  for (final u in updates) {
    if (u.voiceRecords.isNotEmpty) {
      mergedVoiceRecords.addAll(u.voiceRecords);
    } else if (u.voiceRecordUrl.trim().isNotEmpty) {
      mergedVoiceRecords.add(
        VoiceRecordEntry(
          url: u.voiceRecordUrl.trim(),
          durationSec: u.voiceRecordDurationSec,
        ),
      );
    }
  }

  if (mergedVoiceRecords.length > 1) {
    descBlocks.add(
      'programming.updates.multiple_voices_note'
          .trParams({'count': '${mergedVoiceRecords.length}'}),
    );
  }

  final allFiles = <String>{};
  for (final u in updates) {
    allFiles.addAll(u.files.where((f) => f.trim().isNotEmpty));
  }

  final aboutParts = updates
      .map((u) => u.aboutTask.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  final now = DateTime.now();
  final from = firstDate(updates.map((u) => u.fromDate)) ?? now;
  final to = firstDate(updates.map((u) => u.toDate)) ?? from;

  return TaskModel(
    title: title,
    description: descBlocks.join('\n\n'),
    status: StorageKeys.status_not_start_yet,
    priority: firstNonEmpty(updates.map((u) => u.priority)),
    fromDate: from,
    toDate: to,
    assignedTo: firstNonEmpty(updates.map((u) => u.assignedTo)),
    clientName: firstNonEmpty(updates.map((u) => u.clientName)),
    assignedImageUrl: '',
    actionText: '',
    type: '6',
    files: allFiles.toList(),
    voiceRecords: mergedVoiceRecords,
    voiceRecordUrl: VoiceRecordEntry.primaryUrl(mergedVoiceRecords),
    voiceRecordDurationSec:
        VoiceRecordEntry.primaryDurationSec(mergedVoiceRecords),
    sourceUpdateIds: updates.map((u) => u.id ?? '').where((id) => id.isNotEmpty).toList(),
    programmingModel: ProgrammingModel(
      category: firstNonEmpty(updates.map((u) => u.category)),
      contenturl: firstNonEmpty(updates.map((u) => u.contenturl)),
      fileurl: firstNonEmpty(updates.map((u) => u.fileurl)),
      designsDimensions: '',
      aboutTask: aboutParts.join('\n\n'),
    ),
  );
}
