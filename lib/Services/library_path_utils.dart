import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';

/// Virtual folder layout + filtering helpers for the Library (Drive-style).
class LibraryPathUtils {
  LibraryPathUtils._();

  static String yearMonthFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// Months from [start]'s month through December of the same calendar year.
  static List<String> virtualMonthKeysFrom(DateTime start) {
    final y = start.year;
    final first = DateTime(y, start.month, 1);
    final last = DateTime(y, 12, 1);
    final out = <String>[];
    for (var d = first; !d.isAfter(last); d = DateTime(d.year, d.month + 1, 1)) {
      out.add(yearMonthFor(d));
    }
    return out;
  }

  static const List<String> mediaCategories = [
    'post',
    'story',
    'video',
    'documents',
  ];

  static String categoryFromFinalType(String raw) {
    final t = raw.trim();
    if (t == StorageKeys.finalWorkTypeStory) return 'story';
    if (t == StorageKeys.finalWorkTypeVideoReel) return 'video';
    if (t == StorageKeys.finalWorkTypeDocuments) return 'documents';
    return 'post';
  }

  /// Types kept on the task but not listed in the Library drive.
  static bool finalDeliverableTypeExcludedFromLibrary(String raw) =>
      raw.trim() == StorageKeys.finalWorkTypeOther;

  static bool taskHasArchivablePayload(TaskModel t) {
    return t.finalDeliverableText.trim().isNotEmpty ||
        t.finalDeliverableFileUrls.isNotEmpty ||
        t.finalDeliverableType.trim().isNotEmpty;
  }

  static bool taskEligibleForLibraryBrowse(TaskModel t) {
    if (t.type == '0') {
      return FunHelper.canonicalStoredStatus(t.status) ==
          StorageKeys.status_promotion_finished;
    }
    final s = FunHelper.canonicalStoredStatus(t.status);
    return StorageKeys.isTaskSuccessfulTerminalStatus(s);
  }

  /// Completed task with final-work payload (shown in Library from live task data).
  static bool libraryEntryDesired(TaskModel t) {
    return taskHasArchivablePayload(t) &&
        taskEligibleForLibraryBrowse(t) &&
        !finalDeliverableTypeExcludedFromLibrary(t.finalDeliverableType);
  }

  /// Latest activity on final deliverable fields (timeline), for month folder grouping.
  static DateTime? inferredFinalDeliverableLastActivity(TaskModel t) {
    DateTime? best;
    for (final e in t.timelineEvents) {
      final fk = e.fieldKey ?? '';
      if (fk == 'finalDeliverableText' ||
          e.type == 'final_deliverable_attachment_added') {
        if (best == null || e.timestamp.isAfter(best)) {
          best = e.timestamp;
        }
      }
    }
    return best;
  }

  /// `YYYY-MM` folder key for this task (stable from timeline when possible).
  static String libraryMonthFolderKeyForTask(TaskModel t) {
    final at = inferredFinalDeliverableLastActivity(t);
    if (at != null) return yearMonthFor(at);
    return yearMonthFor(t.toDate);
  }

  /// Aligns a task with the Library client folder.
  ///
  /// In Firestore, [TaskModel.clientName] is often the **client document id** (see task
  /// forms / details that resolve `clients.firstWhere((c) => c.id == task.clientName)`).
  /// The folder supplies both [clientId] and the display [clientName] from [ClientModel].
  static bool taskMatchesLibraryBrowse(
    TaskModel t,
    String clientId,
    String clientName,
  ) {
    final raw = t.clientName.trim();
    if (raw.isEmpty) return false;

    final cid = clientId.trim();
    final cname = clientName.trim();
    if (cid.isNotEmpty && raw == cid) return true;
    if (cname.isNotEmpty && raw.toLowerCase() == cname.toLowerCase()) {
      return true;
    }
    return false;
  }
}
