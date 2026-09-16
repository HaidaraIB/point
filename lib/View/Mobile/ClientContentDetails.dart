import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/ThemeController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/notification_navigation/notification_destination.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/app_theme.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Mobile/EditRequestSheet.dart';
import 'package:point/View/Mobile/RefuseRequestSheet.dart';
import 'package:point/View/Mobile/Shared/PdfViewr.dart';
import 'package:point/Utils/media_url_opener.dart' show getFileType;
import 'package:point/View/Mobile/Shared/VideoCart.dart'
    show ImagePreviewPage, UnknownFilePage, VideoPlayerPage;
import 'package:point/View/Shared/app_version_label.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/safe_network_image.dart';
import 'package:point/View/Shared/task_status_visuals.dart';

/// Opens client content details as a dialog on web, or a full screen on mobile.
Future<void> openClientContentDetails(
  BuildContext context,
  ContentModel model,
) async {
  if (kIsWeb) {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Clientcontentdetails.maxContentWidth,
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
              ),
              child: Clientcontentdetails(model: model, asDialog: true),
            ),
          ),
    );
    return;
  }
  await Get.to(() => Clientcontentdetails(model: model));
}

class Clientcontentdetails extends StatelessWidget {
  final ContentModel? model;
  final bool asDialog;

  const Clientcontentdetails({
    super.key,
    required this.model,
    this.asDialog = false,
  });

  static const double maxContentWidth = 920;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ClientController>(
      builder: (controller) {
        return Obx(() {
          final themeController = Get.find<ThemeController>();
          final _ = themeController.themeMode.value;
          final appTheme = themeController.extension;
          final themeData =
              themeController.effectiveBrightness == Brightness.dark
                  ? AppTheme.dark()
                  : AppTheme.light();

          final id = model?.id;
          final live =
              id != null
                  ? controller.contents.firstWhereOrNull((c) => c.id == id)
                  : null;
          final m = live ?? model!;
          final canReview = m.status == StorageKeys.status_under_revision;
          final isWide = asDialog || !Responsive.isMobile(context);

          final wideBody = _WideClientContentBody(
            model: m,
            appTheme: appTheme,
            canReview: canReview,
            isLoading: controller.isLoading.value,
            embedded: asDialog,
            onApprove: () => _confirmApprove(context, controller, m),
            onEdit: () => _openEditRequest(context, m),
            onReject: () => _openRefuseRequest(context, m),
          );

          if (asDialog) {
            return Theme(
              data: themeData,
              child: Material(
                color: appTheme.cardSurface,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height =
                        constraints.maxHeight.isFinite
                            ? constraints.maxHeight
                            : MediaQuery.sizeOf(context).height * 0.88;
                    return SizedBox(
                      height: height,
                      child: Column(
                        children: [
                          _ClientContentDialogHeader(appTheme: appTheme),
                          Expanded(
                            child: _WideClientContentBody(
                              model: m,
                              appTheme: appTheme,
                              canReview: canReview,
                              isLoading: controller.isLoading.value,
                              embedded: true,
                              fillHeight: true,
                              showActions: false,
                              onApprove:
                                  () => _confirmApprove(context, controller, m),
                              onEdit: () => _openEditRequest(context, m),
                              onReject: () => _openRefuseRequest(context, m),
                            ),
                          ),
                          _ClientContentActionBar(
                            appTheme: appTheme,
                            canReview: canReview,
                            isLoading: controller.isLoading.value,
                            layout: _ActionBarLayout.footer,
                            onApprove:
                                () => _confirmApprove(context, controller, m),
                            onEdit: () => _openEditRequest(context, m),
                            onReject: () => _openRefuseRequest(context, m),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          }

          return Theme(
            data: themeData,
            child: Scaffold(
              backgroundColor: appTheme.pageBackground,
              appBar: AppBar(
                backgroundColor: appTheme.cardSurface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'content.details_title'.tr,
                  style: TextStyle(
                    color: appTheme.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                centerTitle: true,
              ),
              body: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: maxContentWidth,
                        ),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            isWide ? 24 : 16,
                            isWide ? 20 : 8,
                            isWide ? 24 : 16,
                            24,
                          ),
                          child:
                              isWide
                                  ? wideBody
                                  : _NarrowClientContentBody(
                                    model: m,
                                    appTheme: appTheme,
                                  ),
                        ),
                      ),
                    ),
                  ),
                  if (!isWide)
                    _ClientContentActionBar(
                      appTheme: appTheme,
                      canReview: canReview,
                      isLoading: controller.isLoading.value,
                      layout: _ActionBarLayout.stacked,
                      onApprove:
                          () => _confirmApprove(context, controller, m),
                      onEdit: () => _openEditRequest(context, m),
                      onReject: () => _openRefuseRequest(context, m),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _confirmApprove(
    BuildContext context,
    ClientController controller,
    ContentModel m,
  ) async {
    await FunHelper.showConfirmDailog(
      context,
      title: 'client.confirm_approve_title'.tr,
      message: 'client.confirm_approve_message'.tr,
      confirmText: 'tasks.accept'.tr,
      confirmColor: Colors.green,
      onTap: () async {
        final ok = await controller.updateContent(
          m.copyWith(status: StorageKeys.status_ready_to_publish),
        );
        if (!ok) {
          FunHelper.showSnackbar(
            'feedback.error_title'.tr,
            'errors.network_failed'.tr,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
        final clientName =
            controller.currentClient.value?.name ?? m.clientId;
        await NotificationService.notifyPublishDeptClientApproved(
          clientName: clientName,
          contentTitle: m.title,
          fcmDataExtras: notificationContentExtras(m.id),
        );
        _popSelf(context);
        FunHelper.showSnackbar(
          'success'.tr,
          'client.accept_success'.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      },
    );
  }

  void _openEditRequest(BuildContext context, ContentModel m) {
    _showClientSheet(
      context: context,
      child: EditRequestSheet(model: m, asDialog: _useDialogPresentation(context)),
    );
  }

  void _openRefuseRequest(BuildContext context, ContentModel m) {
    _showClientSheet(
      context: context,
      child: RefuseRequestSheet(model: m, asDialog: _useDialogPresentation(context)),
    );
  }

  void _popSelf(BuildContext context) {
    if (asDialog) {
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    Get.back();
  }

  bool _useDialogPresentation(BuildContext context) =>
      asDialog || !Responsive.isMobile(context);

  void _showClientSheet({
    required BuildContext context,
    required Widget child,
  }) {
    final asDialog = _useDialogPresentation(context);
    if (asDialog) {
      showDialog<void>(
        context: context,
        builder:
            (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
                ),
                child: child,
              ),
            ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => child,
    );
  }
}

class _ClientContentDialogHeader extends StatelessWidget {
  const _ClientContentDialogHeader({required this.appTheme});

  final AppThemeExtension appTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Text(
              'content.details_title'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: appTheme.primaryText,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: appTheme.primaryText),
          ),
        ],
      ),
    );
  }
}

class _WideClientContentBody extends StatelessWidget {
  const _WideClientContentBody({
    required this.model,
    required this.appTheme,
    required this.canReview,
    required this.isLoading,
    this.embedded = false,
    this.fillHeight = false,
    this.showActions = true,
    required this.onApprove,
    required this.onEdit,
    required this.onReject,
  });

  final ContentModel model;
  final AppThemeExtension appTheme;
  final bool canReview;
  final bool isLoading;
  final bool embedded;
  final bool fillHeight;
  final bool showActions;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final detailsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ClientContentStatusChip(
          status: model.status,
          appTheme: appTheme,
        ),
        const SizedBox(height: 20),
        _DetailBlock(
          label: 'title'.tr,
          value: model.title,
          appTheme: appTheme,
        ),
        if ((model.notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _DetailBlock(
            label: 'notes'.tr,
            value: model.notes!.trim(),
            appTheme: appTheme,
          ),
        ],
        if (model.publishDate != null) ...[
          const SizedBox(height: 14),
          _DetailBlock(
            label: 'publish_date'.tr,
            value: FunHelper.formatdate(model.publishDate) ?? '',
            appTheme: appTheme,
          ),
        ],
        if (showActions && !fillHeight) ...[
          const Spacer(),
          const SizedBox(height: 24),
          _ClientContentActionBar(
            appTheme: appTheme,
            canReview: canReview,
            isLoading: isLoading,
            layout: _ActionBarLayout.inline,
            onApprove: onApprove,
            onEdit: onEdit,
            onReject: onReject,
          ),
        ],
      ],
    );

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 9,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                fillHeight
                    ? SingleChildScrollView(child: detailsColumn)
                    : detailsColumn,
          ),
        ),
        VerticalDivider(width: 1, color: appTheme.border),
        Expanded(
          flex: 11,
          child: _ClientContentMediaCard(
            model: model,
            appTheme: appTheme,
            previewHeight: fillHeight ? null : 360,
          ),
        ),
      ],
    );

    final content = fillHeight ? body : IntrinsicHeight(child: body);

    if (embedded) return content;

    return Container(
      decoration: BoxDecoration(
        color: appTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class _NarrowClientContentBody extends StatelessWidget {
  const _NarrowClientContentBody({
    required this.model,
    required this.appTheme,
  });

  final ContentModel model;
  final AppThemeExtension appTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ClientContentMediaCard(
          model: model,
          appTheme: appTheme,
          previewHeight: 220,
        ),
        const SizedBox(height: 16),
        _ClientContentStatusChip(status: model.status, appTheme: appTheme),
        const SizedBox(height: 20),
        _DetailBlock(label: 'title'.tr, value: model.title, appTheme: appTheme),
        if ((model.notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _DetailBlock(
            label: 'notes'.tr,
            value: model.notes!.trim(),
            appTheme: appTheme,
          ),
        ],
        if (model.publishDate != null) ...[
          const SizedBox(height: 16),
          _DetailBlock(
            label: 'publish_date'.tr,
            value: FunHelper.formatdate(model.publishDate) ?? '',
            appTheme: appTheme,
          ),
        ],
        AppVersionLabel(
          padding: const EdgeInsets.only(top: 32),
          textStyle: TextStyle(
            fontSize: 12,
            height: 1.25,
            color: appTheme.mutedText,
          ),
        ),
      ],
    );
  }
}

class _ClientContentMediaCard extends StatefulWidget {
  const _ClientContentMediaCard({
    required this.model,
    required this.appTheme,
    this.previewHeight,
  });

  final ContentModel model;
  final AppThemeExtension appTheme;
  final double? previewHeight;

  @override
  State<_ClientContentMediaCard> createState() => _ClientContentMediaCardState();
}

class _ClientContentMediaCardState extends State<_ClientContentMediaCard> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final files = widget.model.attachmentUrls;
    final appTheme = widget.appTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedHeight = widget.previewHeight;
        final hasBoundedHeight =
            fixedHeight != null ||
            (constraints.hasBoundedHeight && constraints.maxHeight.isFinite);
        final previewHeight =
            fixedHeight ??
            (hasBoundedHeight ? constraints.maxHeight : 360.0);
        final dotsHeight = files.length > 1 ? 28.0 : 12.0;
        final pageHeight = (previewHeight - dotsHeight).clamp(120.0, previewHeight);

        if (files.isEmpty) {
          return Container(
            height: hasBoundedHeight ? previewHeight : null,
            constraints:
                hasBoundedHeight
                    ? null
                    : const BoxConstraints(minHeight: 220),
            color: appTheme.inputFill,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.perm_media_outlined,
                  size: 40,
                  color: appTheme.mutedText,
                ),
                const SizedBox(height: 8),
                Text(
                  'content.dialog.no_attachments'.tr,
                  style: TextStyle(color: appTheme.mutedText),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: pageHeight,
              child: PageView.builder(
                itemCount: files.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: _ClientAttachmentPreview(
                      url: files[index],
                      appTheme: appTheme,
                    ),
                  );
                },
              ),
            ),
            if (files.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(files.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          active ? appTheme.accentText : appTheme.mutedText,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _ClientAttachmentPreview extends StatelessWidget {
  const _ClientAttachmentPreview({
    required this.url,
    required this.appTheme,
  });

  final String url;
  final AppThemeExtension appTheme;

  @override
  Widget build(BuildContext context) {
    final type = getFileType(url);
    return Material(
      color: appTheme.inputFill,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAttachment(url, type),
        child: switch (type) {
          'image' => Center(
            child: SafeNetworkImage(
              url,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          'video' => Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 56,
              color: appTheme.accentText,
            ),
          ),
          'pdf' => Center(
            child: Icon(
              Icons.picture_as_pdf_rounded,
              size: 52,
              color: Colors.red.shade400,
            ),
          ),
          _ => Center(
            child: Icon(
              Icons.insert_drive_file_outlined,
              size: 48,
              color: appTheme.secondaryText,
            ),
          ),
        },
      ),
    );
  }

  void _openAttachment(String url, String type) {
    switch (type) {
      case 'image':
        Get.to(() => ImagePreviewPage(url: url));
      case 'video':
        Get.to(() => VideoPlayerPage(url: url));
      case 'pdf':
        Get.to(() => PdfViewerPage(url: url));
      default:
        Get.to(() => UnknownFilePage(url: url));
    }
  }
}

class _ClientContentStatusChip extends StatelessWidget {
  const _ClientContentStatusChip({
    required this.status,
    required this.appTheme,
  });

  final String status;
  final AppThemeExtension appTheme;

  @override
  Widget build(BuildContext context) {
    final key = FunHelper.canonicalStoredStatus(status);
    final accent = TaskStatusVisuals.iconTintFor(status, context: context);
    final bg = context.statusChipBackground(accent, _statusBg(key));
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TaskStatusVisuals.statusChip(
        rawStatus: status,
        fg: accent,
        bg: bg,
        fontSize: 12,
        iconSize: 14,
      ),
    );
  }

  Color _statusBg(String key) {
    switch (key) {
      case StorageKeys.status_under_revision:
        return Colors.blue.shade50;
      case StorageKeys.status_ready_to_publish:
        return Colors.teal.shade50;
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

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.label,
    required this.value,
    required this.appTheme,
  });

  final String label;
  final String value;
  final AppThemeExtension appTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appTheme.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: appTheme.accentText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: appTheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ActionBarLayout { stacked, inline, footer }

class _ClientContentActionBar extends StatelessWidget {
  const _ClientContentActionBar({
    required this.appTheme,
    required this.canReview,
    required this.isLoading,
    required this.layout,
    required this.onApprove,
    required this.onEdit,
    required this.onReject,
  });

  final AppThemeExtension appTheme;
  final bool canReview;
  final bool isLoading;
  final _ActionBarLayout layout;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final inlineButtons = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (canReview) ...[
          _approveButton(compact: true),
          const SizedBox(width: 10),
        ],
        _editButton(compact: true),
        if (canReview) ...[
          const SizedBox(width: 10),
          _rejectButton(compact: true),
        ],
      ],
    );

    if (layout == _ActionBarLayout.inline) {
      return inlineButtons;
    }

    if (layout == _ActionBarLayout.footer) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: appTheme.border)),
        ),
        child: inlineButtons,
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      decoration: BoxDecoration(
        color: appTheme.cardSurface,
        border: Border(top: BorderSide(color: appTheme.border)),
        boxShadow: [
          BoxShadow(
            color: appTheme.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canReview) ...[
            SizedBox(width: double.infinity, height: 48, child: _approveButton()),
            const SizedBox(height: 10),
          ],
          SizedBox(width: double.infinity, height: 48, child: _editButton()),
          if (canReview) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 48, child: _rejectButton()),
          ],
        ],
      ),
    );
  }

  Widget _approveButton({bool compact = false}) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onApprove,
      icon:
          isLoading
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : const Icon(Icons.check_rounded, size: 20),
      label: Text('tasks.accept'.tr),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _editButton({bool compact = false}) {
    return OutlinedButton.icon(
      onPressed: onEdit,
      icon: Icon(Icons.edit_outlined, size: 18, color: appTheme.accentText),
      label: Text('edit'.tr, style: TextStyle(color: appTheme.accentText)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: appTheme.accentBorder),
        padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _rejectButton({bool compact = false}) {
    return OutlinedButton.icon(
      onPressed: onReject,
      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
      label: Text('tasks.reject'.tr, style: const TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
