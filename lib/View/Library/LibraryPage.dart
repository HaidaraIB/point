import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/library_path_utils.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/attachment_download.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Tasks/Shared/task_attachment_gallery.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';

class _Nav {
  final int level;
  final String clientId;
  final String clientName;
  final String yearMonth;
  final String category;

  const _Nav({
    this.level = 0,
    this.clientId = '',
    this.clientName = '',
    this.yearMonth = '',
    this.category = '',
  });

  _Nav goCompleted() => const _Nav(level: 1);

  _Nav goClient(String id, String name) => _Nav(
        level: 2,
        clientId: id,
        clientName: name,
      );

  _Nav goMonth(String ym) => _Nav(
        level: 3,
        clientId: clientId,
        clientName: clientName,
        yearMonth: ym,
      );

  _Nav goCategory(String cat) => _Nav(
        level: 4,
        clientId: clientId,
        clientName: clientName,
        yearMonth: yearMonth,
        category: cat,
      );

  _Nav goUp() {
    if (level <= 0) return this;
    if (level == 1) return const _Nav(level: 0);
    if (level == 2) return const _Nav(level: 1);
    if (level == 3) {
      return _Nav(level: 2, clientId: clientId, clientName: clientName);
    }
    return _Nav(
      level: 3,
      clientId: clientId,
      clientName: clientName,
      yearMonth: yearMonth,
    );
  }
}

/// Drive-style library: completed tasks → client → month → posts/stories/videos → files.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  _Nav _nav = const _Nav();

  String _monthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return ym;
    final loc = Get.locale?.toLanguageTag() ?? 'ar';
    return DateFormat.yMMM(loc).format(DateTime(y, m));
  }

  String _categoryTitle(String cat) {
    switch (cat) {
      case 'story':
        return 'library.folder_stories'.tr;
      case 'video':
        return 'library.folder_videos'.tr;
      default:
        return 'library.folder_posts'.tr;
    }
  }

  List<String> _monthKeysForClient(
    String clientId,
    String clientName,
    List<TaskModel> all,
  ) {
    final virtual = LibraryPathUtils.virtualMonthKeysFrom(DateTime.now());
    final fromData = all
        .where(
          (t) => LibraryPathUtils.taskMatchesLibraryBrowse(
            t,
            clientId,
            clientName,
          ),
        )
        .map(LibraryPathUtils.libraryMonthFolderKeyForTask)
        .toSet();
    final merged = {...virtual, ...fromData}.toList()..sort();
    return merged;
  }

  List<TaskModel> _tasksFor(
    List<TaskModel> all,
    _Nav n,
  ) {
    return all
        .where(
          (t) =>
              LibraryPathUtils.taskMatchesLibraryBrowse(
                t,
                n.clientId,
                n.clientName,
              ) &&
              LibraryPathUtils.libraryMonthFolderKeyForTask(t) == n.yearMonth &&
              LibraryPathUtils.categoryFromFinalType(t.finalDeliverableType) ==
                  n.category,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final hc = Get.find<HomeController>();
    final emp = hc.effectiveEmployee;
    if (emp?.role != 'admin' && emp?.role != 'supervisor') {
      return Scaffold(
        body: Center(child: Text('library.forbidden'.tr)),
      );
    }

    return ResponsiveScaffold(
      selectedTab: 9,
      sideMenu: true,
      body: Obx(() {
        final all =
            hc.tasks
                .where(LibraryPathUtils.libraryEntryDesired)
                .toList(growable: false);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_nav.level > 0)
                    IconButton(
                      onPressed: () => setState(() => _nav = _nav.goUp()),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'library.title'.tr,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryfontColor,
                          ),
                        ),
                        Text(
                          'library.subtitle'.tr,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _breadcrumb(context),
              const SizedBox(height: 16),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildBody(context, hc, all),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _breadcrumb(BuildContext context) {
    final labels = <String>['library.title'.tr];
    final targets = <_Nav>[const _Nav()];

    if (_nav.level >= 1) {
      labels.add('library.completed_tasks_folder'.tr);
      targets.add(const _Nav(level: 1));
    }
    if (_nav.level >= 2 && _nav.clientName.isNotEmpty) {
      labels.add(_nav.clientName);
      targets.add(
        _Nav(level: 2, clientId: _nav.clientId, clientName: _nav.clientName),
      );
    }
    if (_nav.level >= 3 && _nav.yearMonth.isNotEmpty) {
      labels.add(_monthLabel(_nav.yearMonth));
      targets.add(
        _Nav(
          level: 3,
          clientId: _nav.clientId,
          clientName: _nav.clientName,
          yearMonth: _nav.yearMonth,
        ),
      );
    }
    if (_nav.level >= 4 && _nav.category.isNotEmpty) {
      labels.add(_categoryTitle(_nav.category));
      targets.add(
        _Nav(
          level: 4,
          clientId: _nav.clientId,
          clientName: _nav.clientName,
          yearMonth: _nav.yearMonth,
          category: _nav.category,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            if (i == labels.length - 1)
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              )
            else
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _nav = targets[i]),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HomeController hc,
    List<TaskModel> all,
  ) {
    switch (_nav.level) {
      case 0:
        return _folderGrid(
          context,
          [
            _FolderTileData(
              label: 'library.completed_tasks_folder'.tr,
              icon: Icons.folder_shared_outlined,
              color: const Color(0xFF5C5589),
              onTap: () => setState(() => _nav = _nav.goCompleted()),
            ),
          ],
          emptyHint: 'library.empty_drive'.tr,
        );
      case 1:
        final clients = hc.clients.toList();
        if (clients.isEmpty) {
          return Center(child: Text('library.empty'.tr));
        }
        return _folderGrid(
          context,
          clients
              .map(
                (c) => _FolderTileData(
                  label: (c.name ?? c.id ?? '').trim().isEmpty
                      ? 'library.client_unassigned'.tr
                      : (c.name ?? c.id)!,
                  icon: Icons.person_outline_rounded,
                  color: const Color(0xFF1565C0),
                  onTap: () {
                    final rawName = (c.name ?? '').trim();
                    final rawId = (c.id ?? '').trim();
                    final browseName =
                        rawName.isNotEmpty ? rawName : rawId;
                    setState(
                      () => _nav = _nav.goClient(rawId, browseName),
                    );
                  },
                ),
              )
              .toList(),
          emptyHint: 'library.empty'.tr,
        );
      case 2:
        final months = _monthKeysForClient(
          _nav.clientId,
          _nav.clientName,
          all,
        );
        return _folderGrid(
          context,
          months
              .map(
                (ym) => _FolderTileData(
                  label: _monthLabel(ym),
                  icon: Icons.calendar_month_outlined,
                  color: const Color(0xFF2E7D32),
                  onTap: () => setState(() => _nav = _nav.goMonth(ym)),
                ),
              )
              .toList(),
          emptyHint: 'library.empty'.tr,
        );
      case 3:
        return _folderGrid(
          context,
          LibraryPathUtils.mediaCategories
              .map(
                (cat) => _FolderTileData(
                  label: _categoryTitle(cat),
                  icon: cat == 'video'
                      ? Icons.video_file_outlined
                      : cat == 'story'
                      ? Icons.auto_stories_outlined
                      : Icons.post_add_outlined,
                  color: const Color(0xFFEF6C00),
                  onTap: () => setState(() => _nav = _nav.goCategory(cat)),
                ),
              )
              .toList(),
          emptyHint: 'library.empty'.tr,
        );
      case 4:
        final files = _tasksFor(all, _nav);
        if (files.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'library.empty'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: files.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = files[i];
            return _FileEntryCard(task: e);
          },
        );
      default:
        return Center(child: Text('library.empty'.tr));
    }
  }

  Widget _folderGrid(
    BuildContext context,
    List<_FolderTileData> folders, {
    required String emptyHint,
  }) {
    if (folders.isEmpty) {
      return Center(child: Text(emptyHint));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.95,
      ),
      itemCount: folders.length,
      itemBuilder: (context, i) {
        final f = folders[i];
        return Material(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: f.onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(f.icon, size: 40, color: f.color),
                  const Spacer(),
                  Text(
                    f.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FolderTileData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _FolderTileData({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _FileEntryCard extends StatelessWidget {
  final TaskModel task;

  const _FileEntryCard({required this.task});

  String _formatTs(DateTime? d) {
    if (d == null) return '';
    final loc = Get.locale?.toLanguageTag() ?? 'ar';
    return DateFormat.yMMMd(loc).add_jm().format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final uploaded =
        LibraryPathUtils.inferredFinalDeliverableLastActivity(task) ??
        task.toDate;
    final rawType = task.finalDeliverableType.trim();
    final typeLabel = rawType.isEmpty ? '' : rawType.tr;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.description_outlined, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${'library.uploaded_at'.tr}: ${_formatTs(uploaded)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (typeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${'tasks.final_deliverable_type_label'.tr}: $typeLabel',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'tasks.final_deliverable_text_label'.tr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.finalDeliverableText.trim().isEmpty
                      ? '—'
                      : task.finalDeliverableText,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade900),
                ),
                if (task.finalDeliverableFileUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'tasks.final_deliverable_files_label'.tr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(
                      task.finalDeliverableFileUrls.length,
                      (i) {
                        final u = task.finalDeliverableFileUrls[i];
                        final name =
                            TaskDetailsDialogHelpers.attachmentFileNameFromUrl(
                              u,
                            );
                        final imgs =
                            task.finalDeliverableFileUrls
                                .where(
                                  (x) => isImageMediaUrl(x.toString()),
                                )
                                .map((x) => x.toString())
                                .toList();
                        final gi = imgs.indexOf(u);
                        return SizedBox(
                          width: 104,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 88,
                                height: 88,
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
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: 'library.download_file'.tr,
                                    iconSize: 20,
                                    onPressed: () =>
                                        launchAttachmentDownload(u),
                                    icon: const Icon(Icons.download_outlined),
                                  ),
                                  if (isImageMediaUrl(u))
                                    IconButton(
                                      tooltip: 'tasks.attachment_gallery'.tr,
                                      iconSize: 20,
                                      onPressed: () =>
                                          openTaskAttachmentGallery(
                                            imageUrls: imgs,
                                            initialIndex: gi >= 0 ? gi : 0,
                                          ),
                                      icon: const Icon(
                                        Icons.collections_outlined,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
