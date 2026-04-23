import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/final_deliverable_upload_names.dart';

/// Admin/supervisor: request changes while task is under review.
Future<void> showRequestTaskModificationDialog({
  required BuildContext context,
  required TaskModel task,
}) async {
  final hc = Get.find<HomeController>();
  final formKey = GlobalKey<FormState>();
  final messageController = TextEditingController();
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
            final msg = messageController.text.trim();
            final at = DateTime.now().toUtc().toIso8601String();
            final nextStatus =
                task.type == '0'
                    ? StorageKeys.status_promotion_in_progress
                    : StorageKeys.status_edit_requested;
            final updated =
                task.type == '0'
                    ? task.copyWithPromotionStatusAligned(nextStatus).copyWith(
                      managementEditRequestMessage: msg,
                      managementEditRequestFileUrls: List<String>.from(urls),
                      managementEditRequestAt: at,
                    )
                    : task.copyWith(
                      status: nextStatus,
                      managementEditRequestMessage: msg,
                      managementEditRequestFileUrls: List<String>.from(urls),
                      managementEditRequestAt: at,
                    );
            await hc.updateTask(updated);
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          }

          return AlertDialog(
            title: Text('tasks.request_modification_title'.tr),
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
                        'tasks.request_modification_subtitle'.tr,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: messageController,
                        minLines: 4,
                        maxLines: 10,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: 'tasks.request_modification_message'.tr,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'validation.comment_required'.tr;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          onPressed: hc.isUploading.value ? null : addFiles,
                          icon: const Icon(Icons.attach_file),
                          label: Text('tasks.request_modification_add_files'.tr),
                        ),
                      ),
                      if (urls.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'tasks.request_modification_attached_count'
                              .trParams({'count': '${urls.length}'}),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
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
                onPressed: hc.isUploading.value ? null : submit,
                child: Text('tasks.request_modification_submit'.tr),
              ),
            ],
          );
        },
      );
    },
  );
  messageController.dispose();
}
