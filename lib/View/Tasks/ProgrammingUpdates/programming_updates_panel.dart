import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ProgrammingUpdateModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/merge_programming_updates.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/ProgrammingUpdates/add_programming_update_dialog.dart';
import 'package:point/View/Tasks/ProgrammingUpdates/programming_update_details.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Pending updates list with multi-select and create-task action.
class ProgrammingPendingUpdatesPanel extends StatefulWidget {
  const ProgrammingPendingUpdatesPanel({super.key});

  @override
  State<ProgrammingPendingUpdatesPanel> createState() =>
      _ProgrammingPendingUpdatesPanelState();
}

class _ProgrammingPendingUpdatesPanelState
    extends State<ProgrammingPendingUpdatesPanel> {
  final Set<String> _selectedIds = {};

  void _toggleSelect(String id, List<ProgrammingUpdateModel> allPending) {
    if (_selectedIds.contains(id)) {
      setState(() => _selectedIds.remove(id));
      return;
    }

    if (_selectedIds.isNotEmpty) {
      final anchor = allPending.firstWhereOrNull(
        (u) => u.id != null && _selectedIds.contains(u.id),
      );
      final candidate = allPending.firstWhereOrNull((u) => u.id == id);
      if (anchor != null &&
          candidate != null &&
          !canMergeProgrammingUpdates(anchor, candidate)) {
        FunHelper.showSnackbar(
          'programming.updates.form_title'.tr,
          'programming.updates.merge_selection_mismatch'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade800,
          colorText: Colors.white,
        );
        return;
      }
    }

    setState(() => _selectedIds.add(id));
  }

  Future<void> _deleteUpdate(ProgrammingUpdateModel update) async {
    final id = update.id;
    if (id == null || id.isEmpty) return;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('common.confirm'.tr),
        content: Text('programming.updates.delete_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('common.cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Get.find<HomeController>().deleteProgrammingUpdate(id);
    if (mounted) setState(() => _selectedIds.remove(id));
  }

  void _createTaskFromSelection(List<ProgrammingUpdateModel> allPending) {
    final selected = allPending
        .where((u) => u.id != null && _selectedIds.contains(u.id))
        .toList();
    if (selected.isEmpty) return;

    final mergeIssue = validateProgrammingUpdatesMerge(selected);
    if (mergeIssue != null) {
      FunHelper.showSnackbar(
        'programming.updates.form_title'.tr,
        mergeIssue.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    final draft = buildTaskDraftFromUpdates(selected);
    programmingDialog(
      context,
      model: draft,
      sourceUpdates: selected,
    );
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pending = Get.find<HomeController>()
          .programmingUpdates
          .where((u) => u.isPending)
          .toList();

      return Stack(
        children: [
          ProgrammingUpdatesList(
            items: pending,
            selectable: true,
            selectedIds: _selectedIds,
            onToggle: (id) => _toggleSelect(id, pending),
            onEdit: (u) => showAddProgrammingUpdateDialog(context, model: u),
            onView: (u) => showProgrammingUpdateDetails(context, update: u),
            onDelete: _deleteUpdate,
            emptyMessage: 'programming.updates.empty_pending'.tr,
          ),
          if (_selectedIds.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(28),
                color: context.appTheme.navSurface,
                child: InkWell(
                  onTap: () => _createTaskFromSelection(pending),
                  borderRadius: BorderRadius.circular(28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.task_alt, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'programming.updates.create_task'
                              .trParams({'count': '${_selectedIds.length}'}),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Read-only list of updates grouped by the task they were merged into.
class ProgrammingConvertedUpdatesPanel extends StatelessWidget {
  const ProgrammingConvertedUpdatesPanel({super.key});

  static List<_ConvertedTaskGroup> _groupUpdates(
    List<ProgrammingUpdateModel> converted,
  ) {
    final grouped = <String, List<ProgrammingUpdateModel>>{};
    for (final update in converted) {
      final taskId = update.convertedToTaskId?.trim() ?? '';
      final key = taskId.isNotEmpty ? taskId : '_orphan_${update.id ?? ''}';
      grouped.putIfAbsent(key, () => []).add(update);
    }

    final groups = grouped.entries
        .map(
          (e) => _ConvertedTaskGroup(
            taskId: e.key.startsWith('_orphan_') ? null : e.key,
            updates: e.value,
          ),
        )
        .toList();

    groups.sort((a, b) => b.latestActivity.compareTo(a.latestActivity));
    for (final group in groups) {
      group.updates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final converted = Get.find<HomeController>()
          .programmingUpdates
          .where((u) => u.isConverted)
          .toList();

      if (converted.isEmpty) {
        return Center(
          child: Text(
            'programming.updates.empty_converted'.tr,
            style: TextStyle(color: context.appTheme.mutedText),
          ),
        );
      }

      final groups = _groupUpdates(converted);

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _ConvertedTaskGroupCard(
            group: groups[index],
            onViewUpdate: (u) => showProgrammingUpdateDetails(context, update: u),
          );
        },
      );
    });
  }
}

class _ConvertedTaskGroup {
  final String? taskId;
  final List<ProgrammingUpdateModel> updates;

  const _ConvertedTaskGroup({required this.taskId, required this.updates});

  DateTime get latestActivity {
    DateTime best = DateTime.fromMillisecondsSinceEpoch(0);
    for (final u in updates) {
      final t = u.convertedAt ?? u.createdAt;
      if (t.isAfter(best)) best = t;
    }
    return best;
  }
}

class _ConvertedTaskGroupCard extends StatefulWidget {
  final _ConvertedTaskGroup group;
  final void Function(ProgrammingUpdateModel update) onViewUpdate;

  const _ConvertedTaskGroupCard({
    required this.group,
    required this.onViewUpdate,
  });

  @override
  State<_ConvertedTaskGroupCard> createState() =>
      _ConvertedTaskGroupCardState();
}

class _ConvertedTaskGroupCardState extends State<_ConvertedTaskGroupCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.group.updates.length <= 3;
  }

  String _taskTitle() {
    final taskId = widget.group.taskId;
    if (taskId == null || taskId.isEmpty) {
      final first = widget.group.updates.first.title.trim();
      return first.isNotEmpty
          ? first
          : 'programming.updates.unknown_task'.tr;
    }
    final task = Get.find<HomeController>()
        .tasks
        .firstWhereOrNull((t) => t.id == taskId);
    final title = task?.title.trim() ?? '';
    if (title.isNotEmpty) return title;
    return 'programming.updates.unknown_task'.tr;
  }

  String _updatesCountLabel() {
    final n = widget.group.updates.length;
    return n == 1
        ? 'programming.updates.single_update_in_task'.tr
        : 'programming.updates.updates_in_task'.trParams({'count': '$n'});
  }

  void _openTask() {
    final taskId = widget.group.taskId;
    if (taskId == null || taskId.isEmpty) return;
    final task = Get.find<HomeController>()
        .tasks
        .firstWhereOrNull((t) => t.id == taskId);
    if (task != null) {
      showProgrammingDialog(context, task: task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final latest = group.latestActivity;
    final convertedLabel = FunHelper.formatdate(latest) ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.primary.withValues(alpha: 0.06),
            child: InkWell(
              onTap: group.updates.length > 1
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.task_alt_outlined,
                        color: context.appTheme.accentText,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _taskTitle(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: context.appTheme.primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _updatesCountLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appTheme.mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (convertedLabel.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${'programming.updates.converted_at'.tr}: $convertedLabel',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.appTheme.mutedText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (group.updates.length > 1)
                      IconButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        icon: Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          color: context.appTheme.accentText,
                        ),
                      ),
                    if (group.taskId != null && group.taskId!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: OutlinedButton.icon(
                          onPressed: _openTask,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text('programming.updates.open_task'.tr),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.appTheme.accentText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded || group.updates.length == 1)
            ...group.updates.asMap().entries.map((entry) {
              final index = entry.key;
              final update = entry.value;
              final isLast = index == group.updates.length - 1;
              return _ConvertedUpdateRow(
                update: update,
                index: index + 1,
                showDivider: !isLast,
                onTap: () => widget.onViewUpdate(update),
              );
            }),
        ],
      ),
    );
  }
}

class _ConvertedUpdateRow extends StatelessWidget {
  final ProgrammingUpdateModel update;
  final int index;
  final bool showDivider;
  final VoidCallback onTap;

  const _ConvertedUpdateRow({
    required this.update,
    required this.index,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = update.title.trim().isNotEmpty
        ? update.title.trim()
        : 'programming.updates.update_n'.trParams({'n': '$index'});

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.appTheme.mutedText,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (update.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          update.description.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTheme.mutedText,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        FunHelper.formatdate(update.createdAt) ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTheme.mutedText,
                        ),
                      ),
                      if (update.files.isNotEmpty ||
                          update.voiceRecords.isNotEmpty ||
                          update.voiceRecordUrl.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (update.files.isNotEmpty)
                                Chip(
                                  label: Text(
                                    'programming.updates.attachments_count'
                                        .trParams({
                                      'count': '${update.files.length}',
                                    }),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              if (update.voiceRecords.isNotEmpty ||
                                  update.voiceRecordUrl.trim().isNotEmpty)
                                Chip(
                                  label: Text('tasks.form.voice_record'.tr),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}

class ProgrammingUpdatesList extends StatelessWidget {
  final List<ProgrammingUpdateModel> items;
  final bool selectable;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final void Function(ProgrammingUpdateModel)? onEdit;
  final void Function(ProgrammingUpdateModel)? onView;
  final Future<void> Function(ProgrammingUpdateModel)? onDelete;
  final String emptyMessage;
  final bool showTaskLink;

  const ProgrammingUpdatesList({
    super.key,
    required this.items,
    required this.selectable,
    required this.selectedIds,
    required this.onToggle,
    required this.onEdit,
    this.onView,
    required this.onDelete,
    required this.emptyMessage,
    this.showTaskLink = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: context.appTheme.mutedText),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item.id ?? '';
        final title = item.title.trim().isNotEmpty
            ? item.title.trim()
            : 'programming.updates.update_n'.trParams({'n': '${index + 1}'});

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectable && id.isNotEmpty)
                  Checkbox(
                    value: selectedIds.contains(id),
                    onChanged: (_) => onToggle(id),
                  ),
                Expanded(
                  child: InkWell(
                    onTap: () => onView?.call(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (item.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.description.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.appTheme.mutedText,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            FunHelper.formatdate(item.createdAt) ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.appTheme.mutedText,
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (item.files.isNotEmpty)
                                Chip(
                                  label: Text(
                                    'programming.updates.attachments_count'
                                        .trParams({'count': '${item.files.length}'}),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (item.voiceRecords.isNotEmpty ||
                                  item.voiceRecordUrl.trim().isNotEmpty)
                                Chip(
                                  label: Text('tasks.form.voice_record'.tr),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          if (showTaskLink &&
                              (item.convertedToTaskId ?? '').isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                final taskId = item.convertedToTaskId!;
                                final task = Get.find<HomeController>()
                                    .tasks
                                    .firstWhereOrNull((t) => t.id == taskId);
                                if (task != null) {
                                  showProgrammingDialog(context, task: task);
                                }
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: Text('programming.updates.open_task'.tr),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (onEdit != null || onView != null || onDelete != null)
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'view') onView?.call(item);
                      if (v == 'edit') onEdit?.call(item);
                      if (v == 'delete') await onDelete?.call(item);
                    },
                    itemBuilder: (_) => [
                      if (onView != null)
                        PopupMenuItem(
                          value: 'view',
                          child: Text('programming.updates.view_details'.tr),
                        ),
                      if (onEdit != null)
                        PopupMenuItem(value: 'edit', child: Text('edit'.tr)),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('delete'.tr),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
