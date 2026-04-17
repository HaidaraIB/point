import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/StorageKeys.dart';

/// إرسال المهمة للمراجعة فقط (بدون رفع العمل النهائي).
Future<void> showSubmitTaskForReviewDialog({
  required BuildContext context,
  required TaskModel task,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SubmitTaskForReviewDialog(task: task),
  );
}

class _SubmitTaskForReviewDialog extends StatefulWidget {
  final TaskModel task;

  const _SubmitTaskForReviewDialog({required this.task});

  @override
  State<_SubmitTaskForReviewDialog> createState() =>
      _SubmitTaskForReviewDialogState();
}

class _SubmitTaskForReviewDialogState extends State<_SubmitTaskForReviewDialog> {
  var _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final hc = Get.find<HomeController>();
    final nextStatus = widget.task.type == '0'
        ? StorageKeys.status_promotion_ad_platform_review
        : StorageKeys.status_under_revision;
    final updated = widget.task.type == '0'
        ? widget.task.copyWithPromotionStatusAligned(nextStatus)
        : widget.task.copyWith(status: nextStatus);
    final ok = await hc.updateTask(updated);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('tasks.final_deliverable_dialog_title'.tr),
      content: Text(
        'tasks.send_for_review_only_message'.tr,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
          height: 1.35,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocaleKeys.commonCancel.tr),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('tasks.final_deliverable_submit'.tr),
        ),
      ],
    );
  }
}
