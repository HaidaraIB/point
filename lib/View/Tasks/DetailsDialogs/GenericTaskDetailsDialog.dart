import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/HorizontalScrollbarAttachments.dart';
import 'package:point/View/Shared/TaskTimelineWidget.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Generic web dialog for task details. Renders common shell (header, notes,
/// attachments, timeline) and a type-specific middle section.
class GenericTaskDetailsDialog extends StatelessWidget {
  final TaskModel task;
  final Widget typeSpecificSection;
  /// Dialog width as fraction of Get.width (e.g. 0.8 or 0.7).
  final double dialogWidthFraction;

  const GenericTaskDetailsDialog({
    super.key,
    required this.task,
    required this.typeSpecificSection,
    this.dialogWidthFraction = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dialogWidth = Get.width * dialogWidthFraction;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.grey.shade100,
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
                _buildHeader(context),
                const SizedBox(height: 20),
                typeSpecificSection,
                const SizedBox(height: 24),
                _buildNotesAndAttachmentsRow(context, textTheme, dialogWidth),
                const SizedBox(height: 24),
                TaskTimelineWidget(events: task.timelineEvents),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 23),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: Get.width * 0.7 - 300,
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: Get.width * 0.7 - 300,
                child: Text(
                  task.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: NetworkImage(
                  task.assignedImageUrl.isEmpty
                      ? '${StorageKeys.supabaseStorageBaseUrl}/Avatar.png'
                      : task.assignedImageUrl,
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المنفذ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    Get.find<HomeController>().employees
                            .firstWhereOrNull(
                              (emp) => emp.id == task.assignedTo,
                            )
                            ?.name ??
                        '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesAndAttachmentsRow(
    BuildContext context,
    TextTheme textTheme,
    double dialogWidth,
  ) {
    final notesWidth = dialogWidth * 0.35 - 35;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الملاحظات', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              height: 200,
              width: notesWidth,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var note in task.notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.note,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryfontColor,
                            ),
                          ),
                          Text(
                            note.byWho,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المرفقات', style: textTheme.titleMedium),
            const SizedBox(height: 10),
            Container(
              width: notesWidth,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(10),
              child: HorizontalScrollbarAttachments(
                child: kIsWeb
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < task.files.length; i++) ...[
                            if (i > 0) const SizedBox(width: 16),
                            TaskDetailsDialogHelpers.attachmentCard(
                              FunHelper.getFileNameFromUrl(task.files[i]),
                              '',
                              onDownload: () => _launchUrl(task.files[i]),
                            ),
                          ],
                        ],
                      )
                    : Wrap(
                        spacing: 16,
                        children: [
                          for (var att in task.files)
                            TaskDetailsDialogHelpers.attachmentCard(
                              FunHelper.getFileNameFromUrl(att),
                              '',
                              onDownload: () => _launchUrl(att),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'لا يمكن فتح الرابط $url';
    }
  }
}
