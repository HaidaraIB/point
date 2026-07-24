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
import 'package:point/Utils/app_theme_extension.dart';
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
        color: resolveAppTheme().secondaryText,
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

  Color _chipBackground(Color accent) => accent.withValues(alpha: 0.18);

  ({Color fg, Color bg, IconData icon}) _statusVisuals(String status) {
    final s = status.trim().toLowerCase();
    Color fg = resolveAppTheme().secondaryText;
    Color bg = resolveAppTheme().unselected;
    IconData icon = Icons.hourglass_empty_rounded;
    if (s == 'published') {
      fg = const Color(0xFF4ADE80);
      bg = _chipBackground(fg);
      icon = Icons.check_box_rounded;
    } else if (s == 'publishing') {
      fg = const Color(0xFFFB923C);
      bg = _chipBackground(fg);
      icon = Icons.play_circle_outline_rounded;
    } else if (s == 'failed' || s == 'cancelled') {
      fg = const Color(0xFFF87171);
      bg = _chipBackground(fg);
      icon = s == 'cancelled' ? Icons.block_rounded : Icons.error_outline_rounded;
    } else if (s == 'queued' || s == 'queued_now' || s == 'scheduled') {
      fg = const Color(0xFFFBBF24);
      bg = _chipBackground(fg);
      icon = Icons.schedule_rounded;
    }
    return (fg: fg, bg: bg, icon: icon);
  }

  String _statusForAction(String action) {
    switch (action) {
      case 'publish_now':
        return 'queued';
      case 'cancel_schedule':
        return 'cancelled';
      default:
        return 'created';
    }
  }

  Widget _statusChip(String status, {bool showDropdownCaret = false}) {
    final visuals = _statusVisuals(status);
    return MouseRegion(
      cursor: showDropdownCaret
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: visuals.bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusLabel(status),
              style: TextStyle(
                color: visuals.fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(visuals.icon, size: 15, color: visuals.fg),
            if (showDropdownCaret) ...[
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: visuals.fg),
            ],
          ],
        ),
      ),
    );
  }

  Widget _postTypeChip(String postType) {
    final type = postType.trim().toLowerCase();
    Color fg = const Color(0xFFA78BFA);
    if (type == 'feed') {
      fg = const Color(0xFF818CF8);
    } else if (type == 'story') {
      fg = const Color(0xFFF472B6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _chipBackground(fg),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
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
        color: resolveAppTheme().panelTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: resolveAppTheme().border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: resolveAppTheme().primaryText,
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
      return Text('-', style: TextStyle(color: resolveAppTheme().mutedText));
    }
    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      children: items.map(_platformBadge).toList(),
    );
  }

  Future<void> _handlePostAction(
    HomeController controller,
    MetaPostModel p,
    String action,
  ) async {
    if (action == 'publish_now') {
      await controller.publishMetaPost(p.id!);
      return;
    }
    if (action == 'edit') {
      await showAddPublishDialog(existing: p);
      return;
    }
    if (action == 'cancel_schedule') {
      await controller.updateMetaPost(
        p.copyWith(status: 'cancelled', scheduledAt: p.scheduledAt),
      );
      return;
    }
    if (action == 'details') {
      await _showPostDetailsDialog(p);
      return;
    }
    if (action == 'delete') {
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
  }

  bool _showPublishNowAction(MetaPostModel p, bool canChange) {
    if (!canChange) return false;
    final status = p.status.trim().toLowerCase();
    return status == 'created' ||
        status == 'failed' ||
        status == 'cancelled' ||
        status == 'scheduled';
  }

  bool _showCancelScheduleAction(MetaPostModel p, bool canChange) {
    if (!canChange) return false;
    final status = p.status.trim().toLowerCase();
    return status == 'scheduled' ||
        status == 'queued' ||
        status == 'queued_now';
  }

  bool _showEditAction(MetaPostModel p, bool canChange) {
    if (!canChange) return false;
    final status = p.status.trim().toLowerCase();
    return status != 'publishing' && status != 'published';
  }

  List<({String action, String label})> _statusChangeOptions(
    HomeController controller,
    MetaPostModel p,
  ) {
    final canChange = ContentPermissions.canChangePostStatus(
      controller.currentEmployee.value,
    );
    if (!canChange) return [];

    final options = <({String action, String label})>[];

    if (_showPublishNowAction(p, canChange)) {
      options.add((action: 'publish_now', label: 'publish.queued'.tr));
    }
    if (_showCancelScheduleAction(p, canChange)) {
      options.add((action: 'cancel_schedule', label: 'publish.cancelled'.tr));
    }
    return options;
  }

  Widget _buildStatusControl(HomeController controller, MetaPostModel p) {
    final options = _statusChangeOptions(controller, p);
    if (options.isEmpty) {
      return _statusChip(p.status);
    }

    return Builder(
      builder: (context) {
        final chipKey = GlobalKey();
        return GestureDetector(
          key: chipKey,
          onTap: () async {
            final renderBox =
                chipKey.currentContext!.findRenderObject()! as RenderBox;
            final offset = renderBox.localToGlobal(Offset.zero);
            final size = renderBox.size;
            final overlayBox =
                Overlay.of(context).context.findRenderObject()! as RenderBox;
            final overlaySize = overlayBox.size;
            const menuWidth = 196.0;
            final centerX = offset.dx + size.width / 2;
            final left = (centerX - menuWidth / 2)
                .clamp(8.0, overlaySize.width - menuWidth - 8);

            final selected = await showMenu<String>(
              context: context,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: resolveAppTheme().cardSurface,
              elevation: 4,
              position: RelativeRect.fromLTRB(
                left,
                offset.dy + size.height + 4,
                overlaySize.width - left - menuWidth,
                0,
              ),
              items: options
                  .map((option) {
                    final visuals =
                        _statusVisuals(_statusForAction(option.action));
                    return PopupMenuItem<String>(
                      value: option.action,
                      child: SizedBox(
                        width: menuWidth - 32,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(option.label),
                            Icon(
                              visuals.icon,
                              size: 18,
                              color: visuals.fg,
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .toList(),
            );
            if (selected != null) {
              await _handlePostAction(controller, p, selected);
            }
          },
          child: _statusChip(p.status, showDropdownCaret: true),
        );
      },
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
                              color: resolveAppTheme().accentText,
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
                              color: resolveAppTheme().accentText,
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
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(p.caption!.trim()),
                ],
                if (hasMedia) ...[
                  const SizedBox(height: 12),
                  Text(
                    'publish.media'.tr,
                    style: TextStyle(fontWeight: FontWeight.w700),
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
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.metaResponse!.trim(),
                    style: TextStyle(fontSize: 12, color: resolveAppTheme().mutedText),
                  ),
                ],
                if ((p.lastError ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'publish.last_error'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.lastError!.trim(),
                    style: TextStyle(fontSize: 12, color: Colors.red),
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
    final canPublishNow = _showPublishNowAction(p, canChange);
    final canCancelSchedule = _showCancelScheduleAction(p, canChange);
    final canEdit = _showEditAction(p, canChange);
    return PopupMenuButton<String>(
      tooltip: 'tasks.options_tooltip'.tr,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: resolveAppTheme().cardSurface,
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
        if (canEdit) {
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
      onSelected: (value) => _handlePostAction(controller, p, value),
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
    final canAdd = ContentPermissions.canAccessPublishSection(
      controller.currentEmployee.value,
    );

    Widget settingsControl({required bool compact}) {
      if (compact) {
        return IconButton(
          tooltip: 'publish.meta_settings'.tr,
          onPressed: showPublishMetaSettingsDialog,
          icon: const Icon(Icons.settings_outlined, size: 22),
          color: resolveAppTheme().accentText,
        );
      }
      return TextButton.icon(
        onPressed: showPublishMetaSettingsDialog,
        icon: const Icon(Icons.settings_outlined, size: 20),
        label: Text('publish.meta_settings'.tr),
      );
    }

    Widget? addButton({required bool compact}) {
      if (!canAdd) return null;
      return MainButton(
        width: compact ? 132 : 160,
        height: 42,
        borderSize: 20,
        margin: EdgeInsets.zero,
        fontColor: Colors.white,
        backgroundColor: AppColors.primary,
        title: 'publish.add'.tr,
        onPressed: showAddPublishDialog,
      );
    }

    final title = Text(
      'publish.manage_title'.tr,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: resolveAppTheme().secondaryText,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 440;
        final compactActions = constraints.maxWidth < 560;
        final add = addButton(compact: compactActions);

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  settingsControl(compact: compactActions),
                  if (add != null) ...[
                    const SizedBox(width: 8),
                    add,
                  ],
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            settingsControl(compact: compactActions),
            if (add != null) ...[
              const SizedBox(width: 8),
              add,
            ],
          ],
        );
      },
    );
  }

  Widget _buildDesktop(BuildContext context, HomeController controller) {
    // DataTable adds [columnSpacing] between columns and [horizontalMargin] on
    // both sides — those must be included in the scroll child width or the last
    // columns (actions in RTL) get crushed with no usable scrollbar.
    const colSpacing = 12.0;
    const hMargin = 12.0;
    const colWidths = <double>[
      72, // actions (first → rightmost in RTL, always on-screen)
      180, // title
      170, // facebook page
      140, // instagram
      110, // post type
      140, // platforms
      150, // status
      140, // date
    ];
    final tableWidth = colWidths.fold<double>(0, (a, b) => a + b) +
        colSpacing * (colWidths.length - 1) +
        hMargin * 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, controller),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              final list = controller.metaPosts.toList();
              if (list.isEmpty) {
                return Center(child: Text('history.empty_data'.tr));
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = tableWidth > constraints.maxWidth
                      ? tableWidth
                      : constraints.maxWidth;
                  return Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: HorizontalScrollbarTable(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 14),
                          child: SizedBox(
                            width: width,
                            child: DataTable(
                              columnSpacing: colSpacing,
                              horizontalMargin: hMargin,
                              dataRowMinHeight: 64,
                              dataRowMaxHeight: double.infinity,
                              dataRowColor: context.tableDataRowColor,
                              headingRowColor: context.tableHeadingRowColor,
                              dividerThickness: 0.5,
                              columns: [
                                DataColumn(
                                  columnWidth: FixedColumnWidth(colWidths[0]),
                                  headingRowAlignment: MainAxisAlignment.center,
                                  label: _headerText('publish.actions'),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(colWidths[1]),
                                  headingRowAlignment: MainAxisAlignment.center,
                                  label: _headerText('title'),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(colWidths[2]),
                                  headingRowAlignment: MainAxisAlignment.center,
                                  label: _headerText('publish.page_label'),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(colWidths[3]),
                                  headingRowAlignment: MainAxisAlignment.center,
                                  label: _headerText(
                                    'publish.instagram_account',
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(colWidths[4]),
                                  headingRowAlignment: MainAxisAlignment.center,
                                  label: _headerText('publish.post_type'),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(colWidths[5]),
                                  headingRowAlignment: MainAxisAlignment.center,
                                  label: _headerText('publish.platforms'),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(colWidths[6]),
                                  headingRowAlignment: MainAxisAlignment.center,
                                  label: _headerText('publish.status'),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(colWidths[7]),
                                  headingRowAlignment: MainAxisAlignment.center,
                                  label: _headerText('publish_date'),
                                ),
                              ],
                              rows: list.map((p) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      TableCellCenter(
                                        child: _buildActionsMenu(
                                          controller,
                                          p,
                                        ),
                                      ),
                                    ),
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
                                            final label =
                                                p.pageName ?? p.pageId;
                                            if (fbUrl == null) {
                                              return Text(
                                                label,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            }
                                            return InkWell(
                                              onTap: () =>
                                                  openUrlPreferInAppMedia(
                                                fbUrl,
                                              ),
                                              child: Text(
                                                label,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: resolveAppTheme()
                                                      .accentText,
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
                                            final igUrl =
                                                _instagramAccountUrl(p);
                                            final label =
                                                _instagramAccountText(p);
                                            if (igUrl == null ||
                                                label == '-') {
                                              return Text(
                                                label,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              );
                                            }
                                            return InkWell(
                                              onTap: () =>
                                                  openUrlPreferInAppMedia(
                                                igUrl,
                                              ),
                                              child: Text(
                                                label,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: resolveAppTheme()
                                                      .accentText,
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
                                        child: _buildStatusControl(
                                          controller,
                                          p,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      TableCellCenter(
                                        child: Text(
                                          '\u2066${DateFormat('yyyy-MM-dd HH:mm').format(
                                            (p.scheduledAt ?? p.createdAt)
                                                .toLocal(),
                                          )}\u2069',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
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
              color: resolveAppTheme().cardSurface,
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
                                style: TextStyle(
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
                                  color: resolveAppTheme().mutedText,
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
                                  color: resolveAppTheme().accentText,
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
                                  color: resolveAppTheme().mutedText,
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
                                  color: resolveAppTheme().accentText,
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
                            _buildStatusControl(controller, p),
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
                              color: resolveAppTheme().mutedText,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                DateFormat('yyyy-MM-dd HH:mm').format(
                                  (p.scheduledAt ?? p.createdAt).toLocal(),
                                ),
                                style: TextStyle(
                                  color: resolveAppTheme().mutedText,
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
