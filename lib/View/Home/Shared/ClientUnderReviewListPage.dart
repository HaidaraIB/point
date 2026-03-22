import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Contents/ContentDialogDetails.dart';
import 'package:point/View/Shared/responsive.dart';

/// Opens a compact dialog listing all [StorageKeys.status_under_revision] items for [clientId].
void showClientUnderReviewListDialog(
  BuildContext context, {
  required String clientId,
  required String clientName,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return ClientUnderReviewListDialog(
        anchorContext: context,
        clientId: clientId,
        clientName: clientName,
      );
    },
  );
}

class ClientUnderReviewListDialog extends StatelessWidget {
  final BuildContext anchorContext;
  final String clientId;
  final String clientName;

  const ClientUnderReviewListDialog({
    super.key,
    required this.anchorContext,
    required this.clientId,
    required this.clientName,
  });

  static List<ContentModel> _itemsForClient(HomeController c, String id) {
    final list =
        c.contents
            .where(
              (x) =>
                  x.clientId == id && x.status == StorageKeys.status_under_revision,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static String _subtitleLine(ContentModel task) {
    final type = FunHelper.trStored(
      task.contentType,
      kind: StoredValueKind.contentType,
    );
    final platforms = FunHelper.formatStoredPlatforms(task.platform);
    if (platforms.isEmpty) return type;
    return '$type · $platforms';
  }

  @override
  Widget build(BuildContext context) {
    final viewSize = MediaQuery.sizeOf(anchorContext);
    final isMobile = Responsive.isMobile(anchorContext);
    final dialogWidth = (viewSize.width * 0.92).clamp(300.0, 480.0);
    final dialogHeight = (viewSize.height * 0.72).clamp(280.0, 580.0);
    final horizontalPadding = isMobile ? 14.0 : 16.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 24 : 40,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: GetBuilder<HomeController>(
          builder: (controller) {
            final items = _itemsForClient(controller, clientId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              clientName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              AppLocaleKeys.homeReviewListSubtitle.tr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child:
                      items.isEmpty
                          ? Center(
                            child: Padding(
                              padding: EdgeInsetsDirectional.symmetric(
                                horizontal: horizontalPadding * 1.5,
                              ),
                              child: Text(
                                AppLocaleKeys.homeReviewListEmpty.tr,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                          : Scrollbar(
                            thumbVisibility: true,
                            child: ListView.separated(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                horizontalPadding,
                                12,
                                horizontalPadding,
                                16,
                              ),
                              itemCount: items.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final task = items[index];
                                return Material(
                                  color: colorScheme.surfaceContainerLowest,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      controller.uploadedFilesPaths.assignAll(
                                        task.files ?? [],
                                      );
                                      showContentDialogDetails(
                                        anchorContext,
                                        task: task,
                                      );
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: isMobile ? 14 : 11,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  task.title,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _subtitleLine(task),
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            colorScheme
                                                                .onSurfaceVariant,
                                                      ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: isMobile ? 44 : 36,
                                            height: isMobile ? 44 : 36,
                                            child: Icon(
                                              Icons.chevron_left,
                                              color:
                                                  colorScheme.onSurfaceVariant,
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
