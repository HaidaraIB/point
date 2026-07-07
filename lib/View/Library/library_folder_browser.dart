import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/LibraryFileModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/library_path_utils.dart';
import 'package:point/Utils/AppColors.dart';

/// Navigation state for drive-style library: completed → client → month → category → leaf.
class LibraryBrowseNav {
  final int level;
  final String clientId;
  final String clientName;
  final String yearMonth;
  final String category;

  const LibraryBrowseNav({
    this.level = 0,
    this.clientId = '',
    this.clientName = '',
    this.yearMonth = '',
    this.category = '',
  });

  LibraryBrowseNav goCompleted() => const LibraryBrowseNav(level: 1);

  LibraryBrowseNav goClient(String id, String name) =>
      LibraryBrowseNav(level: 2, clientId: id, clientName: name);

  LibraryBrowseNav goMonth(String ym) => LibraryBrowseNav(
    level: 3,
    clientId: clientId,
    clientName: clientName,
    yearMonth: ym,
  );

  LibraryBrowseNav goCategory(String cat) => LibraryBrowseNav(
    level: 4,
    clientId: clientId,
    clientName: clientName,
    yearMonth: yearMonth,
    category: cat,
  );

  LibraryBrowseNav goUp() {
    if (level <= 0) return this;
    if (level == 1) return const LibraryBrowseNav(level: 0);
    if (level == 2) return const LibraryBrowseNav(level: 1);
    if (level == 3) {
      return LibraryBrowseNav(
        level: 2,
        clientId: clientId,
        clientName: clientName,
      );
    }
    return LibraryBrowseNav(
      level: 3,
      clientId: clientId,
      clientName: clientName,
      yearMonth: yearMonth,
    );
  }
}

String libraryMonthDisplayLabel(String ym) {
  final parts = ym.split('-');
  if (parts.length != 2) return ym;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (y == null || m == null) return ym;
  final loc = Get.locale?.toLanguageTag() ?? 'ar';
  return DateFormat.yMMM(loc).format(DateTime(y, m));
}

String libraryCategoryTitle(String cat) {
  switch (cat) {
    case 'story':
      return 'library.folder_stories'.tr;
    case 'video':
      return 'library.folder_videos'.tr;
    case 'documents':
      return 'library.folder_documents'.tr;
    default:
      return 'library.folder_posts'.tr;
  }
}

List<String> libraryMonthKeysForClient(
  String clientId,
  String clientName,
  List<TaskModel> all,
  List<LibraryFileModel> libraryFiles,
) {
  return LibraryPathUtils.libraryMonthKeysForClientBrowse(
    clientId: clientId,
    clientName: clientName,
    tasks: all,
    libraryFiles: libraryFiles,
  );
}

List<TaskModel> libraryTasksInLeafFolder(
  List<TaskModel> all,
  LibraryBrowseNav n,
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

/// Breadcrumb + folder drill-down + customizable leaf (file list / picker).
class LibraryFolderBrowser extends StatelessWidget {
  final LibraryBrowseNav nav;
  final ValueChanged<LibraryBrowseNav> onNavChanged;
  final List<TaskModel> tasks;
  final List<LibraryFileModel> libraryFiles;
  final List<ClientModel> clients;
  final Widget Function(
    BuildContext context,
    LibraryBrowseNav nav,
    List<TaskModel> tasksInFolder,
    List<LibraryFileModel> directFilesInFolder,
  )
  buildLeaf;

  const LibraryFolderBrowser({
    super.key,
    required this.nav,
    required this.onNavChanged,
    required this.tasks,
    required this.libraryFiles,
    required this.clients,
    required this.buildLeaf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _breadcrumb(context),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _breadcrumb(BuildContext context) {
    final labels = <String>['library.title'.tr];
    final targets = <LibraryBrowseNav>[const LibraryBrowseNav()];

    if (nav.level >= 1) {
      labels.add('library.completed_tasks_folder'.tr);
      targets.add(const LibraryBrowseNav(level: 1));
    }
    if (nav.level >= 2 && nav.clientName.isNotEmpty) {
      labels.add(nav.clientName);
      targets.add(
        LibraryBrowseNav(
          level: 2,
          clientId: nav.clientId,
          clientName: nav.clientName,
        ),
      );
    }
    if (nav.level >= 3 && nav.yearMonth.isNotEmpty) {
      labels.add(libraryMonthDisplayLabel(nav.yearMonth));
      targets.add(
        LibraryBrowseNav(
          level: 3,
          clientId: nav.clientId,
          clientName: nav.clientName,
          yearMonth: nav.yearMonth,
        ),
      );
    }
    if (nav.level >= 4 && nav.category.isNotEmpty) {
      labels.add(libraryCategoryTitle(nav.category));
      targets.add(
        LibraryBrowseNav(
          level: 4,
          clientId: nav.clientId,
          clientName: nav.clientName,
          yearMonth: nav.yearMonth,
          category: nav.category,
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
                  onTap: () => onNavChanged(targets[i]),
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

  Widget _buildBody(BuildContext context) {
    switch (nav.level) {
      case 0:
        return _folderGrid(context, [
          _FolderTileData(
            label: 'library.completed_tasks_folder'.tr,
            icon: Icons.folder_shared_outlined,
            color: AppColors.primary,
            onTap: () => onNavChanged(nav.goCompleted()),
          ),
        ], emptyHint: 'library.empty_drive'.tr);
      case 1:
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
                    final browseName = rawName.isNotEmpty ? rawName : rawId;
                    onNavChanged(nav.goClient(rawId, browseName));
                  },
                ),
              )
              .toList(),
          emptyHint: 'library.empty'.tr,
        );
      case 2:
        final months = libraryMonthKeysForClient(
          nav.clientId,
          nav.clientName,
          tasks,
          libraryFiles,
        );
        return _folderGrid(
          context,
          months
              .map(
                (ym) => _FolderTileData(
                  label: libraryMonthDisplayLabel(ym),
                  icon: Icons.calendar_month_outlined,
                  color: const Color(0xFF2E7D32),
                  onTap: () => onNavChanged(nav.goMonth(ym)),
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
                  label: libraryCategoryTitle(cat),
                  icon: cat == 'video'
                      ? Icons.video_file_outlined
                      : cat == 'story'
                      ? Icons.auto_stories_outlined
                      : cat == 'documents'
                      ? Icons.description_outlined
                      : Icons.post_add_outlined,
                  color: const Color(0xFFEF6C00),
                  onTap: () => onNavChanged(nav.goCategory(cat)),
                ),
              )
              .toList(),
          emptyHint: 'library.empty'.tr,
        );
      case 4:
        final files = libraryTasksInLeafFolder(tasks, nav);
        final directFiles = LibraryPathUtils.libraryFilesInLeafFolder(
          libraryFiles,
          nav.clientId,
          nav.clientName,
          nav.yearMonth,
          nav.category,
        );
        return buildLeaf(context, nav, files, directFiles);
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
