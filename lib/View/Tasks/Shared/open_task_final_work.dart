import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Tasks/Shared/edit_final_deliverable_dialog.dart';
import 'package:point/View/Tasks/Shared/submit_task_for_review_dialog.dart';

/// List "Final deliverable" / primary final-work button on task cards.
/// Non–promotion employees only see it after [StorageKeys.status_approved]
/// (they use the status menu for "send for review" before that).
bool shouldShowPrimaryFinalWorkTaskButton(TaskModel task, String role) {
  if (role != 'employee') return true;
  if (task.type == '0') return true;
  return FunHelper.canonicalStoredStatus(task.status) ==
      StorageKeys.status_approved;
}

/// Opens the correct final-work flow by role and task status.
void openTaskFinalWorkDialog({
  required BuildContext context,
  required TaskModel task,
}) {
  final hc = Get.find<HomeController>();
  final role = hc.currentEmployee.value?.role ?? '';
  if (role == 'admin' || role == 'supervisor') {
    showEditFinalDeliverableDialog(context: context, task: task);
    return;
  }

  final status = task.status;
  if (task.type == '0') {
    if (status == StorageKeys.status_promotion_ad_platform_review ||
        status == StorageKeys.status_promotion_running ||
        status == StorageKeys.status_promotion_finished) {
      FunHelper.showSnackbar(
        'validation.title'.tr,
        'tasks.final_work_waiting_for_approval'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }
    if (StorageKeys.isTaskSuccessfulTerminalStatus(status)) {
      FunHelper.showSnackbar(
        'validation.title'.tr,
        'tasks.final_work_already_completed'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (status == StorageKeys.status_not_start_yet ||
        status == StorageKeys.status_processing ||
        status == StorageKeys.status_promotion_in_progress ||
        status == StorageKeys.status_in_edit ||
        status == StorageKeys.status_edit_requested) {
      showSubmitTaskForReviewDialog(context: context, task: task);
      return;
    }
    FunHelper.showSnackbar(
      'validation.title'.tr,
      'tasks.final_work_action_not_available'.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.shade800,
      colorText: Colors.white,
    );
    return;
  }

  if (status == StorageKeys.status_approved) {
    showUploadFinalWorkAfterApprovalDialog(context: context, task: task);
    return;
  }
  if (status == StorageKeys.status_under_revision ||
      status == StorageKeys.status_awaiting_manager) {
    FunHelper.showSnackbar(
      'validation.title'.tr,
      'tasks.final_work_waiting_for_approval'.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.shade800,
      colorText: Colors.white,
    );
    return;
  }
  if (StorageKeys.isTaskSuccessfulTerminalStatus(status)) {
    FunHelper.showSnackbar(
      'validation.title'.tr,
      'tasks.final_work_already_completed'.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
    );
    return;
  }

  if (status == StorageKeys.status_not_start_yet ||
      status == StorageKeys.status_processing ||
      status == StorageKeys.status_in_edit ||
      status == StorageKeys.status_edit_requested) {
    showSubmitTaskForReviewDialog(context: context, task: task);
    return;
  }

  FunHelper.showSnackbar(
    'validation.title'.tr,
    'tasks.final_work_action_not_available'.tr,
    snackPosition: SnackPosition.TOP,
    backgroundColor: Colors.orange.shade800,
    colorText: Colors.white,
  );
}
