import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/View/Tasks/Shared/edit_final_deliverable_dialog.dart';
import 'package:point/View/Tasks/Shared/submit_task_for_review_dialog.dart';

/// Opens edit dialog for admin/supervisor, submit-for-review dialog for others.
void openTaskFinalWorkDialog({
  required BuildContext context,
  required TaskModel task,
}) {
  final hc = Get.find<HomeController>();
  final role = hc.currentEmployee.value?.role ?? '';
  if (role == 'admin' || role == 'supervisor') {
    showEditFinalDeliverableDialog(context: context, task: task);
  } else {
    showSubmitTaskForReviewDialog(context: context, task: task);
  }
}
