import 'package:get/get.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';

/// منطق تصفية المهام المشترك بين الواجهة الرئيسية وسجل المهام.
List<TaskModel> filterTasksBySearchPriorityExecutor({
  required Iterable<TaskModel> baseList,
  required String searchText,
  required String selectedPriority,
  required String selectedExecutor,
  required List<EmployeeModel> employees,
}) {
  String? executorId;
  if (selectedExecutor.isNotEmpty) {
    final matchUser = employees.firstWhereOrNull(
      (u) => u.name!.toLowerCase() == selectedExecutor.toLowerCase(),
    );
    executorId = matchUser?.id;
  }

  return baseList.where((task) {
    final title = (task.title).toLowerCase();
    final assigned = (task.assignedTo).toLowerCase();
    final priority = (task.priority).toLowerCase();

    final matchSearch =
        searchText.isEmpty
            ? true
            : (title.contains(searchText) ||
                employees.any(
                  (u) =>
                      u.name!.toLowerCase().contains(searchText) &&
                      u.id == task.assignedTo,
                ));

    final matchPriority =
        selectedPriority.isEmpty
            ? true
            : priority == selectedPriority.toLowerCase();

    final matchExecutor =
        selectedExecutor.isEmpty
            ? true
            : assigned == executorId?.toLowerCase();

    return matchSearch && matchPriority && matchExecutor;
  }).toList();
}

/// Per canonical status for admin/supervisor **ongoing** task management.
/// Order matches [StorageKeys.ongoingStatusFilterDropdownValues] for [taskType].
/// Only statuses with count > 0 are returned.
List<MapEntry<String, int>> taskManagementOngoingStatEntriesOrdered({
  required Iterable<TaskModel> tasks,
  required String taskType,
}) {
  final ordered = StorageKeys.ongoingStatusFilterDropdownValues(taskType);
  final allowed = ordered.toSet();
  final counts = <String, int>{};
  for (final t in tasks) {
    final c = FunHelper.canonicalStoredStatus(t.status);
    if (!allowed.contains(c)) continue;
    counts[c] = (counts[c] ?? 0) + 1;
  }
  final out = <MapEntry<String, int>>[];
  for (final s in ordered) {
    final n = counts[s] ?? 0;
    if (n > 0) out.add(MapEntry(s, n));
  }
  return out;
}
