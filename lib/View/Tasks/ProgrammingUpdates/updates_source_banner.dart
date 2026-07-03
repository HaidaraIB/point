import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/ProgrammingUpdateModel.dart';
import 'package:point/Utils/AppColors.dart';

/// Banner shown when creating a programming task from pending updates.
class UpdatesSourceBanner extends StatefulWidget {
  final List<ProgrammingUpdateModel> sourceUpdates;

  const UpdatesSourceBanner({super.key, required this.sourceUpdates});

  @override
  State<UpdatesSourceBanner> createState() => _UpdatesSourceBannerState();
}

class _UpdatesSourceBannerState extends State<UpdatesSourceBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.sourceUpdates.length;
    if (n == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(Icons.merge_type, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'programming.updates.from_updates_banner'
                        .trParams({'count': '$n'}),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryfontColor,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < widget.sourceUpdates.length; i++)
              _SourceUpdateCard(
                index: i + 1,
                update: widget.sourceUpdates[i],
              ),
          ],
        ],
      ),
    );
  }
}

class _SourceUpdateCard extends StatelessWidget {
  final int index;
  final ProgrammingUpdateModel update;

  const _SourceUpdateCard({required this.index, required this.update});

  @override
  Widget build(BuildContext context) {
    final title = update.title.trim().isNotEmpty
        ? update.title.trim()
        : 'programming.updates.update_n'.trParams({'n': '$index'});
    final desc = update.description.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              desc,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (update.files.isNotEmpty)
                Chip(
                  label: Text(
                    'programming.updates.attachments_count'
                        .trParams({'count': '${update.files.length}'}),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              if (update.voiceRecordUrl.trim().isNotEmpty)
                Chip(
                  label: Text('tasks.form.voice_record'.tr),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
