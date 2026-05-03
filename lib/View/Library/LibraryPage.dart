import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/library_path_utils.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/attachment_download.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Library/library_folder_browser.dart';
import 'package:point/View/Tasks/Shared/task_attachment_gallery.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';

/// Drive-style library: completed tasks → client → month → posts/stories/videos/documents → files.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryBrowseNav _nav = const LibraryBrowseNav();

  @override
  Widget build(BuildContext context) {
    final hc = Get.find<HomeController>();
    final emp = hc.effectiveEmployee;
    if (emp?.role != 'admin' && emp?.role != 'supervisor') {
      return Scaffold(body: Center(child: Text('library.forbidden'.tr)));
    }

    return ResponsiveScaffold(
      selectedTab: 9,
      sideMenu: true,
      body: Obx(() {
        final all = hc.tasks
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: LibraryFolderBrowser(
                      nav: _nav,
                      onNavChanged: (n) => setState(() => _nav = n),
                      tasks: all,
                      clients: hc.clients.toList(),
                      buildLeaf: (context, nav, files) {
                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: files.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            return _FileEntryCard(task: files[i]);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
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
                        final imgs = task.finalDeliverableFileUrls
                            .where((x) => isImageMediaUrl(x.toString()))
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
                                  child:
                                      TaskDetailsDialogHelpers.attachmentThumbnail(
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
