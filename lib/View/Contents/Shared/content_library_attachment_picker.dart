import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/library_path_utils.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';

enum ContentAttachmentSource { library, local }

class _LibraryAttachmentItem {
  final String url;
  final String taskTitle;
  final String clientName;
  final String typeLabel;
  final String monthLabel;

  const _LibraryAttachmentItem({
    required this.url,
    required this.taskTitle,
    required this.clientName,
    required this.typeLabel,
    required this.monthLabel,
  });
}

Future<ContentAttachmentSource?> showContentAttachmentSourceDialog(
  BuildContext context,
) async {
  Widget sourceBody(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'content.attachment_source_title'.tr,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                () => Navigator.of(ctx).pop(ContentAttachmentSource.library),
            icon: const Icon(Icons.video_library_outlined),
            label: Text('content.attachment_source_library'.tr),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(ContentAttachmentSource.local),
            icon: const Icon(Icons.upload_file_outlined),
            label: Text('content.attachment_source_local'.tr),
          ),
        ],
      ),
    );
  }

  if (kIsWeb) {
    return showDialog<ContentAttachmentSource>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            contentPadding: EdgeInsets.zero,
            content: sourceBody(ctx),
          ),
    );
  }

  return showModalBottomSheet<ContentAttachmentSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(child: sourceBody(ctx)),
  );
}

Future<List<String>> showLibraryAttachmentPickerDialog(
  BuildContext context, {
  List<String> initiallySelected = const <String>[],
}) async {
  final hc = Get.find<HomeController>();
  final selected = Set<String>.from(initiallySelected);
  final search = TextEditingController();
  final allItems = _buildLibraryItemsFromTasks(
    hc.tasks.where(LibraryPathUtils.libraryEntryDesired).toList(growable: false),
  );
  final result = await showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder:
        (dialogCtx) => StatefulBuilder(
          builder: (context, setState) {
            final q = search.text.trim().toLowerCase();
            final items =
                q.isEmpty
                    ? allItems
                    : allItems.where((e) {
                      final haystack =
                          '${e.taskTitle} ${e.clientName} ${e.typeLabel} ${e.monthLabel} '
                              '${TaskDetailsDialogHelpers.attachmentFileNameFromUrl(e.url)}'
                              .toLowerCase();
                      return haystack.contains(q);
                    }).toList(growable: false);
            return AlertDialog(
              title: Text('content.library_picker_title'.tr),
              content: SizedBox(
                width: 780,
                height: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'content.library_picker_search_hint'.tr,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child:
                          items.isEmpty
                              ? Center(
                                child: Text(
                                  'content.library_picker_empty'.tr,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              )
                              : GridView.builder(
                                itemCount: items.length,
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 210,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      mainAxisExtent: 182,
                                    ),
                                itemBuilder: (_, i) {
                                  final item = items[i];
                                  final checked = selected.contains(item.url);
                                  final fileName = TaskDetailsDialogHelpers
                                      .attachmentFileNameFromUrl(item.url);
                                  return Material(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        setState(() {
                                          if (checked) {
                                            selected.remove(item.url);
                                          } else {
                                            selected.add(item.url);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Checkbox(
                                                  value: checked,
                                                  onChanged: (_) {
                                                    setState(() {
                                                      if (checked) {
                                                        selected.remove(item.url);
                                                      } else {
                                                        selected.add(item.url);
                                                      }
                                                    });
                                                  },
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    item.taskTitle,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child:
                                                    TaskDetailsDialogHelpers
                                                        .attachmentThumbnail(
                                                          item.url,
                                                          onOpen: () {},
                                                        ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              fileName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            Text(
                                              '${item.clientName} • ${item.monthLabel}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(const <String>[]),
                  child: Text('common.cancel'.tr),
                ),
                ElevatedButton(
                  onPressed:
                      () => Navigator.of(dialogCtx).pop(selected.toList()),
                  child: Text(
                    'content.library_picker_select_count'.trParams({
                      'count': '${selected.length}',
                    }),
                  ),
                ),
              ],
            );
          },
        ),
  );
  search.dispose();
  return result ?? const <String>[];
}

List<_LibraryAttachmentItem> _buildLibraryItemsFromTasks(List<TaskModel> tasks) {
  final out = <_LibraryAttachmentItem>[];
  for (final t in tasks) {
    final urls =
        t.finalDeliverableFileUrls
            .where((u) => u.trim().isNotEmpty)
            .map((u) => u.trim());
    if (urls.isEmpty) continue;
    final typeRaw = t.finalDeliverableType.trim();
    final monthKey = LibraryPathUtils.libraryMonthFolderKeyForTask(t);
    for (final url in urls) {
      out.add(
        _LibraryAttachmentItem(
          url: url,
          taskTitle: t.title.trim().isEmpty ? '-' : t.title.trim(),
          clientName:
              t.clientName.trim().isEmpty ? 'library.client_unassigned'.tr : t.clientName.trim(),
          typeLabel: typeRaw.isEmpty ? '' : typeRaw.tr,
          monthLabel: monthKey,
        ),
      );
    }
  }
  return out;
}
