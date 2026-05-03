import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/library_path_utils.dart';
import 'package:point/View/Library/library_folder_browser.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';

enum ContentAttachmentSource { library, local }

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
            onPressed: () =>
                Navigator.of(ctx).pop(ContentAttachmentSource.library),
            icon: const Icon(Icons.video_library_outlined),
            label: Text('content.attachment_source_library'.tr),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(ctx).pop(ContentAttachmentSource.local),
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
      builder: (ctx) => AlertDialog(
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

  /// `1` = one attachment only (e.g. Meta publish). Omit or `null` = multi-select (Content).
  int? maxSelections,
  String? title,
}) async {
  final hc = Get.find<HomeController>();
  final single = maxSelections == 1;
  final initial = single && initiallySelected.length > 1
      ? <String>[initiallySelected.first]
      : initiallySelected;
  final result = await showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => _LibraryAttachmentPickerDialog(
      dialogContext: dialogCtx,
      single: single,
      title: title,
      initial: List<String>.from(initial),
      maxSelections: maxSelections,
      homeController: hc,
    ),
  );
  return result ?? const <String>[];
}

class _LibraryAttachmentPickerDialog extends StatefulWidget {
  final BuildContext dialogContext;
  final bool single;
  final String? title;
  final List<String> initial;
  final int? maxSelections;
  final HomeController homeController;

  const _LibraryAttachmentPickerDialog({
    required this.dialogContext,
    required this.single,
    required this.title,
    required this.initial,
    required this.maxSelections,
    required this.homeController,
  });

  @override
  State<_LibraryAttachmentPickerDialog> createState() =>
      _LibraryAttachmentPickerDialogState();
}

class _LibraryAttachmentRow {
  final TaskModel task;
  final String url;

  const _LibraryAttachmentRow({required this.task, required this.url});
}

class _LibraryAttachmentPickerDialogState
    extends State<_LibraryAttachmentPickerDialog> {
  late final TextEditingController _search;
  LibraryBrowseNav _nav = const LibraryBrowseNav();
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _selected = Set<String>.from(widget.initial);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applySelectionTap(String url, {required bool currentlySelected}) {
    final single = widget.single;
    final cap = widget.maxSelections;
    if (single) {
      if (currentlySelected) {
        _selected.remove(url);
      } else {
        _selected
          ..clear()
          ..add(url);
      }
    } else {
      if (currentlySelected) {
        _selected.remove(url);
      } else {
        if (cap == null || _selected.length < cap) {
          _selected.add(url);
        }
      }
    }
  }

  String _contextLine(LibraryBrowseNav nav) {
    final client = nav.clientName.trim().isEmpty
        ? 'library.client_unassigned'.tr
        : nav.clientName.trim();
    final month = libraryMonthDisplayLabel(nav.yearMonth);
    final type = libraryCategoryTitle(nav.category);
    return '$client • $month • $type';
  }

  List<_LibraryAttachmentRow> _rowsForTasks(List<TaskModel> tasksInFolder) {
    final out = <_LibraryAttachmentRow>[];
    for (final t in tasksInFolder) {
      for (final raw in t.finalDeliverableFileUrls) {
        final u = raw.trim();
        if (u.isNotEmpty) {
          out.add(_LibraryAttachmentRow(task: t, url: u));
        }
      }
    }
    return out;
  }

  List<_LibraryAttachmentRow> _filteredRows(List<TaskModel> tasksInFolder) {
    final rows = _rowsForTasks(tasksInFolder);
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows
        .where((row) {
          final t = row.task;
          final title = t.title.trim().toLowerCase();
          final file = TaskDetailsDialogHelpers.attachmentFileNameFromUrl(
            row.url,
          ).toLowerCase();
          final typeRaw = t.finalDeliverableType.trim();
          final typeLabel = typeRaw.isEmpty ? '' : typeRaw.tr.toLowerCase();
          final clientField = t.clientName.trim().toLowerCase();
          final ym = LibraryPathUtils.libraryMonthFolderKeyForTask(t);
          final monthDisp = libraryMonthDisplayLabel(ym).toLowerCase();
          final navClient = _nav.clientName.trim().toLowerCase();
          final navMonth = _nav.yearMonth.toLowerCase();
          final navCat = libraryCategoryTitle(_nav.category).toLowerCase();
          final haystack =
              '$title $file $typeLabel $clientField $ym $monthDisp $navClient $navMonth $navCat';
          return haystack.contains(q);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final hc = widget.homeController;
    final tasksSnapshot = hc.tasks
        .where(LibraryPathUtils.libraryEntryDesired)
        .toList(growable: false);

    return AlertDialog(
      title: widget.single
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title ?? 'publish.library_picker_title'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'publish.library_picker_single_hint'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            )
          : Text(widget.title ?? 'content.library_picker_title'.tr),
      content: SizedBox(
        width: 780,
        height: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _search,
              enabled: _nav.level == 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: _nav.level == 4
                    ? 'content.library_picker_search_hint'.tr
                    : 'content.library_picker_search_nav_hint'.tr,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LibraryFolderBrowser(
                nav: _nav,
                onNavChanged: (n) => setState(() => _nav = n),
                tasks: tasksSnapshot,
                clients: hc.clients.toList(),
                buildLeaf: (ctx, nav, files) {
                  final rows = _filteredRows(files);
                  if (rows.isEmpty) {
                    return Center(
                      child: Text(
                        'content.library_picker_empty'.tr,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      final checked = _selected.contains(row.url);
                      final fileName =
                          TaskDetailsDialogHelpers.attachmentFileNameFromUrl(
                            row.url,
                          );
                      final titleText = row.task.title.trim().isEmpty
                          ? '-'
                          : row.task.title.trim();
                      return Material(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              _applySelectionTap(
                                row.url,
                                currentlySelected: checked,
                              );
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: checked,
                                  onChanged: (_) {
                                    setState(() {
                                      _applySelectionTap(
                                        row.url,
                                        currentlySelected: checked,
                                      );
                                    });
                                  },
                                ),
                                SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child:
                                        TaskDetailsDialogHelpers.attachmentThumbnail(
                                          row.url,
                                          onOpen: () {},
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        titleText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fileName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _contextLine(nav),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade700,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(widget.dialogContext).pop(const <String>[]),
          child: Text('common.cancel'.tr),
        ),
        ElevatedButton(
          onPressed: widget.single && _selected.isEmpty
              ? null
              : () =>
                    Navigator.of(widget.dialogContext).pop(_selected.toList()),
          child: Text(
            widget.single
                ? (_selected.isEmpty
                      ? 'publish.library_picker_select_one'.tr
                      : 'common.confirm'.tr)
                : 'content.library_picker_select_count'.trParams({
                    'count': '${_selected.length}',
                  }),
          ),
        ),
      ],
    );
  }
}
