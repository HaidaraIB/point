import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/TaskModel.dart';

Future<void> showAddTaskCommentDialog({
  required BuildContext context,
  required TaskModel task,
}) async {
  final controller = Get.find<HomeController>();
  final formKey = GlobalKey<FormState>();
  final commentController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final BoxConstraints? dialogConstraints;
      if (kIsWeb) {
        final size = MediaQuery.sizeOf(dialogContext);
        final w = size.width;
        final h = size.height;
        // AlertDialog only grows to content width unless minWidth is set; maxWidth alone stays narrow.
        // Default showDialog inset is 40px horizontal each side.
        final horizontalInset = 40.0 * 2;
        final maxAllowed = (w - horizontalInset).clamp(280.0, 1200.0);
        final target = (w * 0.72).clamp(560.0, 960.0);
        final dialogWidth = target.clamp(280.0, maxAllowed);
        // Default showDialog vertical inset is 24px top + bottom.
        final verticalInset = 24.0 * 2;
        final maxAllowedH = (h - verticalInset).clamp(200.0, 1200.0);
        final targetH = (h * 0.48).clamp(360.0, 620.0);
        final dialogMinHeight = targetH <= maxAllowedH ? targetH : maxAllowedH;
        dialogConstraints = BoxConstraints(
          minWidth: dialogWidth,
          maxWidth: dialogWidth,
          minHeight: dialogMinHeight,
        );
      } else {
        dialogConstraints = null;
      }
      return AlertDialog(
        constraints: dialogConstraints,
        title: Text('tasks.add_comment_title'.tr),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: commentController,
            minLines: kIsWeb ? 8 : 3,
            maxLines: kIsWeb ? 14 : 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'employee.comment_hint'.tr,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'validation.comment_required'.tr;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocaleKeys.commonCancel.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final author =
                  controller.currentemployee.value?.name?.trim().isNotEmpty ==
                          true
                      ? controller.currentemployee.value!.name!.trim()
                      : 'employee.fallback_name'.tr;
              final note = NoteModel(
                note: commentController.text.trim(),
                byWho: author,
                timestamp: DateTime.now(),
              );
              await controller.updateTask(
                task.copyWith(notes: [...task.notes, note]),
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text('common.save'.tr),
          ),
        ],
      );
    },
  );
  commentController.dispose();
}
