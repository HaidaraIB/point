import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Contents/Mobile/ContentDetailsMobilePage.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:url_launcher/url_launcher.dart';

void showContentDialogDetails(
  BuildContext context, {
  required ContentModel task,
}) {
  if (Responsive.isMobile(context)) {
    Get.to(() => ContentDetailsMobilePage(task: task));
    return;
  }
  showDialog(
    context: context,
    builder: (context) {
      return ContentDialogDetails(task: task);
    },
  );
}

class ContentDialogDetails extends StatefulWidget {
  final ContentModel task;
  const ContentDialogDetails({super.key, required this.task});

  @override
  State<ContentDialogDetails> createState() => _ContentDialogDetailsState();
}

class _ContentDialogDetailsState extends State<ContentDialogDetails> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewSize = MediaQuery.sizeOf(context);
    final dialogWidth = (viewSize.width * 0.78).clamp(320.0, 920.0);
    final maxDialogHeight = (viewSize.height * 0.9).clamp(420.0, 900.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 42, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colorScheme.surface,
      child: Container(
        clipBehavior: Clip.antiAlias,
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.surfaceContainerLowest, colorScheme.surface],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 9,
            radius: const Radius.circular(10),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton.filledTonal(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildHeader(context, dialogWidth),
                    const SizedBox(height: 12),
                    _buildSectionShell(
                      context: context,
                      title: AppLocaleKeys.contentDialogMetaSection.tr,
                      icon: Icons.info_outline,
                      child: _buildMetaSection(context, dialogWidth),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionShell(
                      context: context,
                      title: AppLocaleKeys.contentDialogNotesAttachmentsSection.tr,
                      icon: Icons.attach_file_outlined,
                      child: _buildNotesAndAttachmentsSection(
                        context,
                        dialogWidth,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double dialogWidth) {
    final colorScheme = Theme.of(context).colorScheme;
    final executorName =
        Get.find<HomeController>().employees
            .firstWhereOrNull((emp) => emp.id == widget.task.executor)
            ?.name ??
        AppLocaleKeys.contentDialogUnknown.tr;
    final subtitle =
        '${AppLocaleKeys.contentType.tr}: ${FunHelper.trStored(widget.task.contentType, kind: StoredValueKind.contentType)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: BoxConstraints(
              maxWidth: dialogWidth < 520 ? dialogWidth - 120 : 250,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(
                    '${StorageKeys.supabaseStorageBaseUrl}/Avatar.png',
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocaleKeys.contentDialogExecutor.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        executorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaSection(BuildContext context, double dialogWidth) {
    final colorScheme = Theme.of(context).colorScheme;
    final clientName =
        Get.find<HomeController>().clients
            .firstWhereOrNull((client) => client.id == widget.task.clientId)
            ?.name ??
        '-';
    final publishDate =
        widget.task.publishDate == null
            ? AppLocaleKeys.contentDialogNoDate.tr
            : FunHelper.formatdate(widget.task.publishDate).toString();
    final promotionValue =
        (widget.task.promotion == null || widget.task.promotion!.trim().isEmpty)
            ? AppLocaleKeys.contentDialogNoPromotion.tr
            : FunHelper.trStored(
                widget.task.promotion,
                kind: StoredValueKind.promotion,
              );
    final platformValue = _formatPlatformValue(widget.task.platform);

    final bool compact = dialogWidth < 760;
    final tileWidth = compact ? (dialogWidth - 96).clamp(220.0, 360.0) : 235.0;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildMetaTile(
          label: AppLocaleKeys.contentDialogClient.tr,
          value: clientName,
          icon: Icons.person_outline,
          width: tileWidth,
          colorScheme: colorScheme,
        ),
        _buildMetaTile(
          label: AppLocaleKeys.contentType.tr,
          value: FunHelper.trStored(
            widget.task.contentType,
            kind: StoredValueKind.contentType,
          ),
          icon: Icons.category_outlined,
          width: tileWidth,
          colorScheme: colorScheme,
        ),
        _buildMetaTile(
          label: AppLocaleKeys.platform.tr,
          value: platformValue,
          icon: Icons.public_outlined,
          width: tileWidth,
          colorScheme: colorScheme,
        ),
        _buildMetaTile(
          label: AppLocaleKeys.status.tr,
          value: FunHelper.trStored(
            widget.task.status,
            kind: StoredValueKind.taskStatus,
          ),
          icon: Icons.flag_outlined,
          width: tileWidth,
          colorScheme: colorScheme,
        ),
        _buildMetaTile(
          label: AppLocaleKeys.promotion.tr,
          value: promotionValue,
          icon: Icons.campaign_outlined,
          width: tileWidth,
          colorScheme: colorScheme,
        ),
        _buildMetaTile(
          label: AppLocaleKeys.clientNotes.tr,
          value:
              widget.task.clientNotes?.trim().isNotEmpty == true
                  ? widget.task.clientNotes!
                  : '-',
          icon: Icons.sticky_note_2_outlined,
          width: tileWidth,
          colorScheme: colorScheme,
        ),
        _buildMetaTile(
          label: AppLocaleKeys.publishDate.tr,
          value: publishDate,
          icon: Icons.calendar_today_outlined,
          width: tileWidth,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildNotesAndAttachmentsSection(
    BuildContext context,
    double dialogWidth,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final bool stacked = dialogWidth < 760;
    final contentWidth =
        stacked
            ? (dialogWidth - 92).clamp(240.0, 780.0)
            : ((dialogWidth - 92) / 2).clamp(260.0, 740.0);
    final attachments = widget.task.files ?? <dynamic>[];

    final notesCard = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocaleKeys.notes.tr, style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          width: contentWidth,
          constraints: const BoxConstraints(minHeight: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Text(
            widget.task.notes?.trim().isNotEmpty == true
                ? widget.task.notes!
                : AppLocaleKeys.contentDialogNoNotes.tr,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final attachmentsCard = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocaleKeys.contentDialogAttachments.tr, style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          width: contentWidth,
          constraints: const BoxConstraints(minHeight: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child:
              attachments.isEmpty
                  ? Center(
                    child: Text(
                      AppLocaleKeys.contentDialogNoAttachments.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                  : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: attachments.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          contentWidth < 340 ? 1 : (contentWidth < 560 ? 2 : 3),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 84,
                    ),
                    itemBuilder: (context, index) {
                      final rawUrl = attachments[index].toString();
                      return TaskDetailsDialogHelpers.attachmentThumbnail(
                        rawUrl,
                        onOpen: () => _launchAttachment(rawUrl),
                      );
                    },
                  ),
        ),
      ],
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          notesCard,
          const SizedBox(height: 16),
          attachmentsCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [notesCard, attachmentsCard],
    );
  }

  Widget _buildSectionShell({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildMetaTile({
    required String label,
    required String value,
    required IconData icon,
    required double width,
    required ColorScheme colorScheme,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(icon, size: 15, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPlatformValue(List<dynamic> platformValues) {
    if (platformValues.isEmpty) return '-';
    final s = FunHelper.formatStoredPlatforms(platformValues);
    return s.isEmpty ? '-' : s;
  }

  Uri _normalizeUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return parsed;
    return Uri.parse('https://$trimmed');
  }

  Future<void> _launchAttachment(String rawUrl) async {
    try {
      final uri = _normalizeUri(rawUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // Fall through to snackbar.
    }

    FunHelper.showSnackbar(
      AppLocaleKeys.errorTitle.tr,
      AppLocaleKeys.contentDialogOpenLinkFailed.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
  }
}
