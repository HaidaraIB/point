import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/Shared/app_date_time_picker.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Assignee asks to move [toDate] to a later value (pending manager approval).
Future<void> showDeadlineExtensionRequestDialog({
  required BuildContext context,
  required TaskModel task,
}) async {
  final hc = Get.find<HomeController>();
  final reasonController = TextEditingController();
  DateTime? picked = task.deadlineExtensionRequestedTo ?? task.toDate;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> pickDate() async {
            final initial = picked ?? task.toDate;
            final first = task.toDate;
            final d = await pickAppDateTime(
              dialogContext,
              initialDateTime: initial.isAfter(first) ? initial : first,
              firstDate: first,
              lastDate: DateTime(first.year + 3),
            );
            if (d != null) setState(() => picked = d);
          }

          Future<void> submit() async {
            if (picked == null) return;
            if (!picked!.isAfter(task.toDate)) {
              FunHelper.showSnackbar(
                'validation.title'.tr,
                'tasks.deadline_extension_pick_later'.tr,
                snackPosition: SnackPosition.TOP,
                backgroundColor: Colors.orange.shade800,
                colorText: Colors.white,
              );
              return;
            }
            final emp = hc.currentEmployee.value;
            final by = (emp?.id ?? emp?.name ?? '').trim();
            final at = DateTime.now().toUtc().toIso8601String();
            await hc.updateTask(
              task.copyWith(
                deadlineExtensionStatus: TaskModel.kDeadlineExtensionPending,
                deadlineExtensionRequestedTo: picked,
                deadlineExtensionReason: reasonController.text.trim(),
                deadlineExtensionRequestedAt: at,
                deadlineExtensionRequestedBy: by.isEmpty ? '—' : by,
                deadlineExtensionDeniedNote: '',
              ),
            );
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          }

          return AlertDialog(
            title: Text('tasks.deadline_extension_title'.tr),
            content: SizedBox(
              width: kIsWeb ? 400 : double.maxFinite,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'tasks.deadline_extension_current'
                          .trParams({'date': FunHelper.formatdate(task.toDate) ?? ''}),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTheme.mutedText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: pickDate,
                      child: Text(
                        picked == null
                            ? 'tasks.deadline_extension_new_date'.tr
                            : (FunHelper.formatdate(picked!) ??
                                picked!.toIso8601String()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: 'tasks.deadline_extension_reason_hint'.tr,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(AppLocaleKeys.commonCancel.tr),
              ),
              ElevatedButton(
                onPressed: submit,
                child: Text('tasks.deadline_extension_submit'.tr),
              ),
            ],
          );
        },
      );
    },
  );
  reasonController.dispose();
}
