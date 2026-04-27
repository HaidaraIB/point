import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/MetaPostModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/ContentPermissions.dart';
import 'package:point/View/Publish/publish_add_dialog.dart';
import 'package:point/View/Publish/publish_meta_settings_dialog.dart';
import 'package:point/View/Shared/HorizontalScroll.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/TableCellCenter.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:point/Utils/media_url_opener.dart';
class PublishTable extends StatelessWidget {
  const PublishTable({super.key});

  String _instagramAccountText(MetaPostModel p) {
    final name = (p.instagramUserName ?? '').trim();
    if (name.isNotEmpty) return '\u2066$name\u2069';
    final id = (p.instagramUserId ?? '').trim();
    if (id.isNotEmpty) return '\u2066$id\u2069';
    return '-';
  }

  String? _facebookPageUrl(MetaPostModel p) {
    final pageId = p.pageId.trim();
    if (pageId.isEmpty) return null;
    return 'https://www.facebook.com/$pageId';
  }

  String? _instagramAccountUrl(MetaPostModel p) {
    final userName = (p.instagramUserName ?? '').trim();
    if (userName.isNotEmpty) {
      return 'https://www.instagram.com/$userName/';
    }
    return null;
  }

  Text _headerText(String key) {
    return Text(
      key.tr,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.fontColorGrey,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _postTypeLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'reel':
        return 'publish.post_type_reel'.tr;
      case 'story':
        return 'publish.post_type_story'.tr;
      default:
        return 'publish.post_type_feed'.tr;
    }
  }

  Widget _statusChip(String status) {
    final s = status.trim().toLowerCase();
    Color fg = Colors.grey.shade700;
    Color bg = Colors.grey.shade100;
    IconData icon = Icons.hourglass_empty_rounded;
    if (s == 'published') {
      fg = Colors.lightGreen.shade700;
      bg = Colors.lightGreen.shade50;
      icon = Icons.check_box_rounded;
    } else if (s == 'publishing') {
      fg = Colors.orange.shade700;
      bg = Colors.orange.shade50;
      icon = Icons.play_circle_outline_rounded;
    } else if (s == 'failed' || s == 'cancelled') {
      fg = Colors.red.shade700;
      bg = Colors.red.shade50;
      icon = s == 'cancelled' ? Icons.block_rounded : Icons.error_outline_rounded;
    } else if (s == 'queued' || s == 'queued_now' || s == 'scheduled') {
      fg = Colors.amber.shade800;
      bg = Colors.amber.shade50;
      icon = Icons.schedule_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _statusLabel(status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 15, color: fg),
          ],
        ),
      ),
    );
  }

  Widget _postTypeChip(String postType) {
    final type = postType.trim().toLowerCase();
    Color fg = Colors.purple.shade700;
    Color bg = Colors.purple.shade100;
    if (type == 'feed') {
      fg = Colors.indigo.shade700;
      bg = Colors.indigo.shade50;
    } else if (type == 'story') {
      fg = Colors.pink.shade700;
      bg = Colors.pink.shade50;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _postTypeLabel(postType),
        style: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _platformBadge(String platform) {
    final p = platform.trim().toLowerCase();
    IconData icon = Icons.public;
    Color iconColor = Colors.blueGrey.shade700;
    String label = platform.tr;
    if (p == 'facebook') {
      icon = Icons.facebook;
      iconColor = const Color(0xFF1877F2);
      label = 'platform_facebook'.tr;
    } else if (p == 'instagram') {
      icon = Icons.camera_alt_outlined;
      iconColor = const Color(0xFFC13584);
      label = 'platform_instagram'.tr;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: AppColors.fontColorGrey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _platformsWrap(
    List<dynamic> rawPlatforms, {
    WrapAlignment alignment = WrapAlignment.center,
  }) {
    final items = rawPlatforms
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    if (items.isEmpty) {
      return Text('-', style: TextStyle(color: Colors.grey.shade700));
    }
    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      children: items.map(_platformBadge).toList(),
    );
  }

  Future<void> _showPostDetailsDialog(MetaPostModel p) async {
    final mediaUrl = (p.mediaUrl ?? '').trim();
    final hasMedia = mediaUrl.isNotEmpty;
    final String scheduleText = DateFormat('yyyy-MM-dd HH:mm').format(
      (p.scheduledAt ?? p.createdAt).toLocal(),
    );
    await Get.dialog<void>(
      AlertDialog(
        title: Text('publish.details_title'.tr),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${'title'.tr}: ${p.title}'),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${'publish.page_label'.tr}: '),
                    Builder(
                      builder: (_) {
                        final fbUrl = _facebookPageUrl(p);
                        final label = p.pageName ?? p.pageId;
                        if (fbUrl == null) {
                          return Text(label);
                        }
                        return InkWell(
                          onTap: () => openUrlPreferInAppMedia(fbUrl),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${'publish.instagram_account'.tr}: '),
                    Builder(
                      builder: (_) {
                        final igUrl = _instagramAccountUrl(p);
                        final label = _instagramAccountText(p);
                        if (igUrl == null || label == '-') {
                          return Text(label);
                        }
                        return InkWell(
                          onTap: () => openUrlPreferInAppMedia(igUrl),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('${'publish.post_type'.tr}: '),
                    const SizedBox(width: 4),
                    _postTypeChip(p.postType),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${'publish.platforms'.tr}: '),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _platformsWrap(
                        p.platforms,
                        alignment: WrapAlignment.start,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('${'publish.status'.tr}: '),
                    const SizedBox(width: 4),
                    _statusChip(p.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${'publish_date'.tr}: $scheduleText'),
                if ((p.caption ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'publish.caption'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(p.caption!.trim()),
                ],
                if (hasMedia) ...[
                  const SizedBox(height: 12),
                  Text(
                    'publish.media'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: TaskDetailsDialogHelpers.attachmentThumbnail(
                      mediaUrl,
                      onOpen: () {
                        openUrlPreferInAppMedia(mediaUrl);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => openUrlPreferInAppMedia(mediaUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text('publish.open_media'.tr),
                  ),
                ],
                if ((p.metaResponse ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'publish.meta_response'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.metaResponse!.trim(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
                if ((p.lastError ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'publish.last_error'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.lastError!.trim(),
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('common.cancel'.tr)),
        ],
      ),
      barrierDismissible: true,
    );
  }

  Widget _buildActionsMenu(
    HomeController controller,
    MetaPostModel p, {
    bool compact = false,
  }) {
    final canChange = ContentPermissions.canChangePostStatus(
      controller.currentEmployee.value,
    );
    final canDelete = ContentPermissions.canDeleteContent(
      controller.currentEmployee.value,
    );
    final canPublishNow = canChange &&
        (p.status == 'created' ||
            p.status == 'failed' ||
            p.status == 'cancelled' ||
            p.status == 'scheduled' ||
            p.status == 'queued' ||
            p.status == 'queued_now');
    final canCancelSchedule = canChange &&
        (p.status == 'scheduled' || p.status == 'queued' || p.status == 'queued_now');
    return PopupMenuButton<String>(
      tooltip: 'tasks.options_tooltip'.tr,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 4,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];
        if (canPublishNow) {
          items.add(
            PopupMenuItem<String>(
              value: 'publish_now',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('publish.publish_now'.tr),
                  const Icon(Icons.rocket_launch_outlined, size: 18),
                ],
              ),
            ),
          );
        }
        if (canChange) {
          items.add(
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('edit'.tr),
                  const Icon(Icons.edit, size: 18, color: Colors.green),
                ],
              ),
            ),
          );
        }
        if (canDelete) {
          items.add(
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('publish.delete'.tr),
                  const Icon(Icons.delete, size: 18, color: Colors.red),
                ],
              ),
            ),
          );
        }
        if (canCancelSchedule) {
          items.add(
            PopupMenuItem<String>(
              value: 'cancel_schedule',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('publish.cancel_schedule'.tr),
                  const Icon(Icons.schedule, size: 18),
                ],
              ),
            ),
          );
        }
        items.add(
          PopupMenuItem<String>(
            value: 'details',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('publish.view_details'.tr),
                const Icon(Icons.remove_red_eye_outlined, size: 18),
              ],
            ),
          ),
        );
        
        return items;
      },
      onSelected: (value) async {
        if (value == 'publish_now') {
          await controller.publishMetaPost(p.id!);
          return;
        }
        if (value == 'edit') {
          await showAddPublishDialog(existing: p);
          return;
        }
        if (value == 'cancel_schedule') {
          await controller.updateMetaPost(
            p.copyWith(status: 'cancelled', scheduledAt: p.scheduledAt),
          );
          return;
        }
        if (value == 'details') {
          await _showPostDetailsDialog(p);
          return;
        }
        if (value == 'delete') {
          await FunHelper.showConfirmDailog(
            Get.context!,
            title: 'publish.delete'.tr,
            message: 'content.bulk_delete_confirm_title'.tr,
            confirmText: 'delete'.tr,
            confirmColor: Colors.red,
            onTap: () async {
              await controller.deleteMetaPost(p.id!);
            },
          );
        }
      },
      child: compact
          ? const Icon(Icons.more_vert, size: 20)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.more_vert, size: 20),
              ],
            ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'queued':
      case 'queued_now':
        return 'publish.queued'.tr;
      case 'scheduled':
        return 'publish.scheduled'.tr;
      case 'published':
        return 'publish.published'.tr;
      case 'failed':
        return 'publish.failed'.tr;
      case 'publishing':
        return 'publish.publishing'.tr;
      case 'cancelled':
        return 'publish.cancelled'.tr;
      default:
        return 'publish.created'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().currentEmployee.value;
    final canAccessPublish = ContentPermissions.canAccessPublishSection(emp);
    if (!canAccessPublish) {
      return ResponsiveScaffold(
        selectedTab: 10,
        sideMenu: emp?.role != 'employee',
        body: Center(child: Text('errors.forbidden'.tr)),
      );
    }
    return ResponsiveScaffold(
      selectedTab: 10,
      sideMenu: emp?.role != 'employee',
      body: GetBuilder<HomeController>(
        builder: (controller) {
          return Responsive(
            mobileBreakpoint: 850,
            mobile: _buildMobile(context, controller),
            desktop: _buildDesktop(context, controller),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, HomeController controller) {
    return Row(
      children: [
        Text(
          'publish.manage_title'.tr,
          style: TextStyle(
            color: AppColors.fontColorGrey,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => showPublishMetaSettingsDialog(),
          icon: const Icon(Icons.settings_outlined, size: 20),
          label: Text('publish.meta_settings'.tr),
        ),
        if (ContentPermissions.canAccessPublishSection(controller.currentEmployee.value)) ...[
          const SizedBox(width: 8),
          MainButton(
            width: 160,
            height: 42,
            borderSize: 20,
            fontColor: Colors.white,
            backgroundColor: AppColors.primary,
            title: 'publish.add'.tr,
            onPressed: () => showAddPublishDialog(),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktop(BuildContext context, HomeController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, controller),
          const SizedBox(height: 16),
          Obx(() {
            final list = controller.metaPosts.toList();
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('history.empty_data'.tr)),
              );
            }
            return HorizontalScrollbarTable(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 14),
                child: SizedBox(
                  width: 1500,
                  child: DataTable(
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: double.infinity,
                      dataRowColor: WidgetStateProperty.all(Colors.white),
                      dividerThickness: 0.5,
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                      columns: [
                        DataColumn(
                          columnWidth: const FixedColumnWidth(220),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: _headerText('title'),
                        ),
                        DataColumn(
                          columnWidth: const FixedColumnWidth(210),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: _headerText('publish.page_label'),
                        ),
                        DataColumn(
                          columnWidth: const FixedColumnWidth(180),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: _headerText('publish.instagram_account'),
                        ),
                        DataColumn(
                          columnWidth: const FixedColumnWidth(150),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: _headerText('publish.post_type'),
                        ),
                        DataColumn(
                          columnWidth: const FixedColumnWidth(170),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: _headerText('publish.platforms'),
                        ),
                        DataColumn(
                          columnWidth: const FixedColumnWidth(150),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: _headerText('publish.status'),
                        ),
                        DataColumn(
                          columnWidth: const FixedColumnWidth(180),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: _headerText('publish_date'),
                        ),
                        DataColumn(
                          columnWidth: const FixedColumnWidth(290),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: _headerText('publish.actions'),
                        ),
                      ],
                    rows: list.map((p) {
                      return DataRow(
                        cells: [
                          DataCell(
                            TableCellCenter(
                              child: Text(
                                p.title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            TableCellCenter(
                              child: Builder(
                                builder: (_) {
                                  final fbUrl = _facebookPageUrl(p);
                                  final label = p.pageName ?? p.pageId;
                                  if (fbUrl == null) {
                                    return Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }
                                  return InkWell(
                                    onTap: () => openUrlPreferInAppMedia(fbUrl),
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          DataCell(
                            TableCellCenter(
                              child: Builder(
                                builder: (_) {
                                  final igUrl = _instagramAccountUrl(p);
                                  final label = _instagramAccountText(p);
                                  if (igUrl == null || label == '-') {
                                    return Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }
                                  return InkWell(
                                    onTap: () => openUrlPreferInAppMedia(igUrl),
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          DataCell(
                            TableCellCenter(
                              child: _postTypeChip(p.postType),
                            ),
                          ),
                          DataCell(
                            TableCellCenter(
                              child: _platformsWrap(p.platforms),
                            ),
                          ),
                          DataCell(
                            TableCellCenter(
                              child: _statusChip(p.status),
                            ),
                          ),
                          DataCell(
                            TableCellCenter(
                              child: Text(
                                DateFormat('yyyy-MM-dd HH:mm').format(
                                  (p.scheduledAt ?? p.createdAt).toLocal(),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          DataCell(
                            TableCellCenter(
                              child: _buildActionsMenu(controller, p),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context, HomeController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, controller),
          const SizedBox(height: 12),
          Expanded(
            child: Obx(() {
              final list = controller.metaPosts.toList();
              if (list.isEmpty) {
                return Center(child: Text('history.empty_data'.tr));
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final p = list[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildActionsMenu(controller, p, compact: true),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (_) {
                            final fbUrl = _facebookPageUrl(p);
                            final label = p.pageName ?? p.pageId;
                            if (fbUrl == null) {
                              return Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 14,
                                ),
                              );
                            }
                            return InkWell(
                              onTap: () => openUrlPreferInAppMedia(fbUrl),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        Builder(
                          builder: (_) {
                            final igUrl = _instagramAccountUrl(p);
                            final label = _instagramAccountText(p);
                            if (igUrl == null || label == '-') {
                              return Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              );
                            }
                            return InkWell(
                              onTap: () => openUrlPreferInAppMedia(igUrl),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _postTypeChip(p.postType),
                            _statusChip(p.status),
                          ],
                        ),
                        if (p.platforms.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _platformsWrap(
                            p.platforms,
                            alignment: WrapAlignment.start,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 15,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                DateFormat('yyyy-MM-dd HH:mm').format(
                                  (p.scheduledAt ?? p.createdAt).toLocal(),
                                ),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
