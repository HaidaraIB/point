import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';

/// Shared task list filtering (ongoing Tasks + Task History).
///
/// [selectedPriorities] / [selectedExecutors] are multi-select; empty = no filter.
/// [selectedExecutors] holds employee ids.
List<TaskModel> filterTasksBySearchPriorityExecutor({
  required Iterable<TaskModel> baseList,
  required String searchText,
  required List<String> selectedPriorities,
  required List<String> selectedExecutors,
  required List<EmployeeModel> employees,
}) {
  final prioritySet = selectedPriorities
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final executorSet = selectedExecutors
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  return baseList.where((task) {
    final title = (task.title).toLowerCase();
    final assigned = (task.assignedTo).trim();
    final priority = (task.priority).toLowerCase();

    final matchSearch = searchText.isEmpty
        ? true
        : (title.contains(searchText) ||
            employees.any(
              (u) =>
                  (u.name ?? '').toLowerCase().contains(searchText) &&
                  u.id == task.assignedTo,
            ));

    final matchPriority =
        prioritySet.isEmpty || prioritySet.contains(priority);

    final matchExecutor =
        executorSet.isEmpty || executorSet.contains(assigned);

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
