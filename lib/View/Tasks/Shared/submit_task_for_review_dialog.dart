import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/StorageKeys.dart';

/// Sends task for review only (no final-work prompt).
Future<void> showSubmitTaskForReviewDialog({
  required BuildContext context,
  required TaskModel task,
}) async {
  final hc = Get.find<HomeController>();
  final nextStatus = task.type == '0'
      ? StorageKeys.status_promotion_ad_platform_review
      : StorageKeys.status_under_revision;
  final cleared = task.copyWith(
    managementEditRequestMessage: '',
    managementEditRequestFileUrls: const [],
    managementEditRequestAt: '',
  );
  final updated = task.type == '0'
      ? cleared.copyWithPromotionStatusAligned(nextStatus)
      : cleared.copyWith(status: nextStatus);
  await hc.updateTask(updated);
}
