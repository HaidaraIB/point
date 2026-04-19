import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/final_deliverable_upload_names.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';

/// Admin / supervisor: add, edit, or clear final deliverable without changing task status.
Future<void> showEditFinalDeliverableDialog({
  required BuildContext context,
  required TaskModel task,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _EditFinalDeliverableDialog(task: task),
  );
}

/// Employee flow after manager approval:
/// upload final work and mark task as completed.
Future<void> showUploadFinalWorkAfterApprovalDialog({
  required BuildContext context,
  required TaskModel task,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (ctx) => _EditFinalDeliverableDialog(
          task: task,
          forceCompleteOnSave: true,
          allowClearAll: false,
          titleKey: 'tasks.final_work_upload_after_accept_title',
          subtitleKey: 'tasks.final_work_upload_after_accept_subtitle',
          saveKey: 'tasks.final_work_complete_task_button',
        ),
  );
}

class _EditFinalDeliverableDialog extends StatefulWidget {
  final TaskModel task;
  final bool forceCompleteOnSave;
  final bool allowClearAll;
  final String titleKey;
  final String subtitleKey;
  final String saveKey;

  const _EditFinalDeliverableDialog({
    required this.task,
    this.forceCompleteOnSave = false,
    this.allowClearAll = true,
    this.titleKey = 'tasks.final_deliverable_edit_title',
    this.subtitleKey = 'tasks.final_deliverable_edit_subtitle',
    this.saveKey = 'tasks.final_deliverable_save',
  });

  @override
  State<_EditFinalDeliverableDialog> createState() =>
      _EditFinalDeliverableDialogState();
}

class _EditFinalDeliverableDialogState extends State<_EditFinalDeliverableDialog> {
  late final TextEditingController _textController;
  final _urls = <String>[];
  String _selectedType = '';
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.task.finalDeliverableText,
    );
    _urls.addAll(widget.task.finalDeliverableFileUrls);
    _selectedType = widget.task.finalDeliverableType.trim();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  TaskModel _latestTask() {
    final id = widget.task.id;
    if (id == null || id.isEmpty) return widget.task;
    final hc = Get.find<HomeController>();
    return hc.tasks.firstWhereOrNull((t) => t.id == id) ?? widget.task;
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
      final slot = _urls.length;
      final downloadName = finalDeliverableDownloadDisplayName(
        taskTitle: _latestTask().title,
        slotIndex: slot,
        originalFileName: f.name,
      );
      final url = await hc.uploadFiles(
        filePathOrBytes: bytes,
        fileName: f.name,
        friendlyDownloadName: downloadName,
      );
      if (url != null && url.isNotEmpty) {
        setState(() => _urls.add(url));
      }
    }
  }

  void _removeUrl(int index) {
    setState(() => _urls.removeAt(index));
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (widget.forceCompleteOnSave &&
        _selectedType.isEmpty &&
        widget.allowClearAll == false) {
      FunHelper.showSnackbar(
        'validation.title'.tr,
        'tasks.final_deliverable_type_required'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }
    if (widget.forceCompleteOnSave && text.isEmpty && _urls.isEmpty) {
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
    final live = _latestTask();
    final ok = await hc.updateTask(
      live.copyWith(
        status:
            widget.forceCompleteOnSave
                ? StorageKeys.status_task_completed
                : live.status,
        finalDeliverableText: text,
        finalDeliverableFileUrls: List<String>.from(_urls),
        finalDeliverableType: _selectedType,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  void _confirmClearAll() {
    FunHelper.showConfirmDailog(
      context,
      title: 'tasks.final_deliverable_clear_title'.tr,
      message: 'tasks.final_deliverable_clear_message'.tr,
      confirmText: 'tasks.final_deliverable_clear_all'.tr,
      confirmColor: Colors.red,
      onTap: () async {
        setState(() => _submitting = true);
        final hc = Get.find<HomeController>();
        hc.uploadedFilesPaths.clear();
        final live = _latestTask();
        final ok = await hc.updateTask(
          live.copyWith(
            finalDeliverableText: '',
            finalDeliverableFileUrls: const [],
            finalDeliverableType: '',
          ),
        );
        if (!mounted) return;
        setState(() => _submitting = false);
        if (ok) {
          Navigator.of(context).pop();
        }
      },
    );
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
      title: Text(widget.titleKey.tr),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.subtitleKey.tr,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedType.isEmpty ? null : _selectedType,
              decoration: InputDecoration(
                labelText: 'tasks.final_deliverable_type_label'.tr,
                border: const OutlineInputBorder(),
              ),
              items:
                  StorageKeys.finalWorkTypes
                      .map(
                        (k) => DropdownMenuItem<String>(
                          value: k,
                          child: Text(k.tr),
                        ),
                      )
                      .toList(),
              onChanged:
                  _submitting
                      ? null
                      : (v) => setState(() => _selectedType = v ?? ''),
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
        if (widget.allowClearAll)
          TextButton(
            onPressed: _submitting ? null : _confirmClearAll,
            child: Text('tasks.final_deliverable_clear_all'.tr),
          ),
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocaleKeys.commonCancel.tr),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _save,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.saveKey.tr),
        ),
      ],
    );
  }
}
