import 'package:get/get.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/TaskModel.dart';

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
