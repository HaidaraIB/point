import 'package:point/Models/ProgrammingUpdateModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Models/VoiceRecordEntry.dart';

List<VoiceRecordEntry> voiceRecordsFromTask(TaskModel? task) {
  if (task == null) return const [];
  if (task.voiceRecords.isNotEmpty) return List.from(task.voiceRecords);
  final url = task.voiceRecordUrl.trim();
  if (url.isEmpty) return const [];
  return [
    VoiceRecordEntry(
      url: url,
      durationSec: task.voiceRecordDurationSec,
    ),
  ];
}

List<VoiceRecordEntry> voiceRecordsFromUpdate(ProgrammingUpdateModel? update) {
  if (update == null) return const [];
  if (update.voiceRecords.isNotEmpty) return List.from(update.voiceRecords);
  final url = update.voiceRecordUrl.trim();
  if (url.isEmpty) return const [];
  return [
    VoiceRecordEntry(
      url: url,
      durationSec: update.voiceRecordDurationSec,
    ),
  ];
}

TaskModel applyVoiceRecordsToTask(
  TaskModel task,
  List<VoiceRecordEntry> records,
) {
  return task.copyWith(
    voiceRecords: records,
    voiceRecordUrl: VoiceRecordEntry.primaryUrl(records),
    voiceRecordDurationSec: VoiceRecordEntry.primaryDurationSec(records),
  );
}

ProgrammingUpdateModel applyVoiceRecordsToUpdate(
  ProgrammingUpdateModel update,
  List<VoiceRecordEntry> records,
) {
  return update.copyWith(
    voiceRecords: records,
    voiceRecordUrl: VoiceRecordEntry.primaryUrl(records),
    voiceRecordDurationSec: VoiceRecordEntry.primaryDurationSec(records),
  );
}
