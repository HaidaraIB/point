import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';

/// خطوة إرسال المهمة للمراجعة: يجب إرفاق نص و/أو ملفات كعمل نهائي.
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
  final _textController = TextEditingController();
  final _urls = <String>[];
  var _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _addFiles() async {
    final hc = Get.find<HomeController>();
    final files = await hc.pickMultiFiles();
    if (files.isEmpty) return;
    for (final f in files) {
      final bytes = f.bytes;
      if (bytes == null) {
        FunHelper.showSnackbar(
          'error'.tr,
          'tasks.final_deliverable_file_read_error'.trParams({'name': f.name}),
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.shade800,
          colorText: Colors.white,
        );
        continue;
      }
      final url = await hc.uploadFiles(
        filePathOrBytes: bytes,
        fileName: f.name,
      );
      if (url != null && url.isNotEmpty) {
        setState(() => _urls.add(url));
      }
    }
  }

  void _removeUrl(int index) {
    setState(() => _urls.removeAt(index));
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _urls.isEmpty) {
      FunHelper.showSnackbar(
        'validation.title'.tr,
        'tasks.final_deliverable_validation'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }
    setState(() => _submitting = true);
    final hc = Get.find<HomeController>();
    hc.uploadedFilesPaths.clear();
    final ok = await hc.updateTask(
      widget.task.copyWith(
        status: StorageKeys.status_under_revision,
        finalDeliverableText: text,
        finalDeliverableFileUrls: List<String>.from(_urls),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final BoxConstraints? dialogConstraints;
    if (kIsWeb) {
      final size = MediaQuery.sizeOf(context);
      final w = size.width;
      final h = size.height;
      final horizontalInset = 40.0 * 2;
      final maxAllowed = (w - horizontalInset).clamp(280.0, 1200.0);
      final target = (w * 0.72).clamp(480.0, 720.0);
      final dialogWidth = target.clamp(280.0, maxAllowed);
      final verticalInset = 24.0 * 2;
      final maxAllowedH = (h - verticalInset).clamp(200.0, 1200.0);
      final targetH = (h * 0.55).clamp(400.0, 720.0);
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
      title: Text('tasks.final_deliverable_dialog_title'.tr),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'tasks.final_deliverable_dialog_subtitle'.tr,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              minLines: kIsWeb ? 5 : 3,
              maxLines: kIsWeb ? 12 : 6,
              decoration: InputDecoration(
                labelText: 'tasks.final_deliverable_text_label'.tr,
                hintText: 'tasks.final_deliverable_text_hint'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : _addFiles,
                icon: const Icon(Icons.add_link),
                label: Text('tasks.final_deliverable_add_files'.tr),
              ),
            ),
            if (_urls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'tasks.final_deliverable_files_label'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(_urls.length, (i) {
                  final u = _urls[i];
                  final name =
                      TaskDetailsDialogHelpers.attachmentFileNameFromUrl(u);
                  return SizedBox(
                    width: 104,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: TaskDetailsDialogHelpers
                                      .attachmentThumbnail(
                                    u,
                                    onOpen: () =>
                                        openUrlPreferInAppMedia(u),
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                top: -6,
                                end: -6,
                                child: Material(
                                  color: Colors.white,
                                  elevation: 1,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _submitting
                                        ? null
                                        : () => _removeUrl(i),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Tooltip(
                          message: name,
                          child: Text(
                            name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade800,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ],
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
