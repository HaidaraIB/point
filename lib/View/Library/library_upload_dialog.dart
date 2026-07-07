import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/LibraryFileModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/Library/library_folder_browser.dart';

Future<void> showLibraryUploadDialog({
  required BuildContext context,
  required LibraryBrowseNav nav,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _LibraryUploadDialog(nav: nav),
  );
}

class _LibraryUploadDialog extends StatefulWidget {
  final LibraryBrowseNav nav;

  const _LibraryUploadDialog({required this.nav});

  @override
  State<_LibraryUploadDialog> createState() => _LibraryUploadDialogState();
}

class _LibraryUploadDialogState extends State<_LibraryUploadDialog> {
  var _uploading = false;

  String _folderContextLine() {
    final client = widget.nav.clientName.trim().isEmpty
        ? 'library.client_unassigned'.tr
        : widget.nav.clientName.trim();
    final month = libraryMonthDisplayLabel(widget.nav.yearMonth);
    final type = libraryCategoryTitle(widget.nav.category);
    return '$client • $month • $type';
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final hc = Get.find<HomeController>();
    final files = await hc.pickMultiFiles();
    if (files.isEmpty) return;

    setState(() => _uploading = true);
    var uploadedCount = 0;
    final empId = hc.effectiveEmployee?.id?.trim() ?? '';

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
      if (url == null || url.trim().isEmpty) continue;

      final ok = await hc.addLibraryFile(
        LibraryFileModel(
          clientId: widget.nav.clientId,
          clientName: widget.nav.clientName,
          yearMonth: widget.nav.yearMonth,
          category: widget.nav.category,
          url: url.trim(),
          fileName: f.name.trim().isEmpty ? 'file' : f.name.trim(),
          uploadedAt: DateTime.now().toUtc(),
          uploadedBy: empId,
        ),
      );
      if (ok) uploadedCount++;
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    if (uploadedCount > 0) {
      FunHelper.showSnackbar(
        'common.save'.tr,
        'library.upload_success'.trParams({'count': '$uploadedCount'}),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('library.upload_files'.tr),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _folderContextLine(),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text(
              'library.upload_hint'.tr,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
            if (_uploading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'library.uploading'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr),
        ),
        ElevatedButton.icon(
          onPressed: _uploading ? null : _pickAndUpload,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text('library.upload_files'.tr),
        ),
      ],
    );
  }
}
