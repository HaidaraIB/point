import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Shared/attachment_thumbnail_tile.dart';
import 'package:point/View/Shared/task_status_visuals.dart';
import 'package:point/Utils/app_theme_extension.dart';

class ClientContentGridCard extends StatefulWidget {
  const ClientContentGridCard({
    super.key,
    required this.model,
    required this.onTap,
  });

  final ContentModel model;
  final VoidCallback onTap;

  @override
  State<ClientContentGridCard> createState() => _ClientContentGridCardState();
}

class _ClientContentGridCardState extends State<ClientContentGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final model = widget.model;
    final firstFile = model.primaryAttachmentUrl;
    final statusKey = FunHelper.canonicalStoredStatus(model.status);
    final statusAccent = TaskStatusVisuals.iconTintFor(
      model.status,
      context: context,
    );
    final statusBg = context.statusChipBackground(
      statusAccent,
      _statusBackground(statusKey, appTheme),
    );
    final needsReview = statusKey == StorageKeys.status_under_revision;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: appTheme.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                _hovered
                    ? appTheme.accentBorder.withValues(alpha: 0.7)
                    : appTheme.border,
          ),
          boxShadow:
              _hovered
                  ? [
                    BoxShadow(
                      color: appTheme.shadowColor.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                  : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: appTheme.inputFill),
                      if (firstFile != null && firstFile.isNotEmpty)
                        AttachmentThumbnailTile(
                          url: firstFile,
                          borderRadius: 0,
                        )
                      else
                        Center(
                          child: Icon(
                            Icons.perm_media_outlined,
                            size: 40,
                            color: appTheme.mutedText,
                          ),
                        ),
                      if (needsReview)
                        PositionedDirectional(
                          top: 10,
                          end: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'client.content.needs_review'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        model.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: appTheme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        FunHelper.trStored(
                          model.contentType,
                          kind: StoredValueKind.contentType,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: appTheme.secondaryText,
                        ),
                      ),
                      if (model.publishDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          FunHelper.formatdate(model.publishDate) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: appTheme.mutedText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Flexible(
                            child: TaskStatusVisuals.statusChip(
                              rawStatus: model.status,
                              fg: statusAccent,
                              bg: statusBg,
                              fontSize: 11,
                              iconSize: 13,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: appTheme.mutedText,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusBackground(String key, AppThemeExtension appTheme) {
    switch (key) {
      case StorageKeys.status_under_revision:
        return Colors.blue.shade50;
      case StorageKeys.status_approved:
        return Colors.green.shade50;
      case StorageKeys.status_rejected:
        return Colors.red.shade50;
      case StorageKeys.status_edit_requested:
        return Colors.deepOrange.shade50;
      default:
        return appTheme.panelTint;
    }
  }
}
