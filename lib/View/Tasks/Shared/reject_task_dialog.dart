import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/final_deliverable_upload_names.dart';

Future<void> showRejectTaskDialog({
  required BuildContext context,
  required TaskModel task,
  VoidCallback? onSuccess,
}) async {
  final hc = Get.find<HomeController>();
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();
  final urls = <String>[];

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> addFiles() async {
            final files = await hc.pickMultiFiles();
            if (files.isEmpty) return;
            for (final f in files) {
              final bytes = f.bytes;
              if (bytes == null) {
                FunHelper.showSnackbar(
                  'error'.tr,
                  'tasks.final_deliverable_file_read_error'
                      .trParams({'name': f.name}),
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.orange.shade800,
                  colorText: Colors.white,
                );
                continue;
              }
              final downloadName = finalDeliverableDownloadDisplayName(
                taskTitle: task.title,
                slotIndex: urls.length,
                originalFileName: f.name,
              );
              final url = await hc.uploadFiles(
                filePathOrBytes: bytes,
                fileName: f.name,
                friendlyDownloadName: downloadName,
              );
              if (url != null && url.isNotEmpty) {
                setState(() => urls.add(url));
              }
            }
          }

          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            final at = DateTime.now().toUtc().toIso8601String();
            final reason = reasonController.text.trim();
            final next =
                task.type == '0'
                    ? task.copyWithPromotionStatusAligned(
                      StorageKeys.status_rejected,
                    ).copyWith(
                      rejectionMessage: reason,
                      rejectionFileUrls: List<String>.from(urls),
                      rejectionAt: at,
                    )
                    : task.copyWith(
                      status: StorageKeys.status_rejected,
                      rejectionMessage: reason,
                      rejectionFileUrls: List<String>.from(urls),
                      rejectionAt: at,
                    );
            await hc.updateTask(next);
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            onSuccess?.call();
          }

          return AlertDialog(
            title: Text('tasks.reject_dialog_title'.tr),
            content: SizedBox(
              width: kIsWeb ? 480 : double.maxFinite,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'tasks.reject_dialog_subtitle'.tr,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: reasonController,
                        minLines: 4,
                        maxLines: 10,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: 'tasks.reject_dialog_reason'.tr,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'tasks.reject_dialog_reason_required'.tr;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: hc.isUploading.value ? null : addFiles,
                        icon: const Icon(Icons.attach_file),
                        label: Text('tasks.reject_dialog_add_files'.tr),
                      ),
                      if (urls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'tasks.reject_dialog_attached_count'
                                .trParams({'count': '${urls.length}'}),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    hc.isUploading.value
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                child: Text(AppLocaleKeys.commonCancel.tr),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: hc.isUploading.value ? null : submit,
                child: Text('tasks.reject'.tr),
              ),
            ],
          );
        },
      );
    },
  );
  reasonController.dispose();
}
