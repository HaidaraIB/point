import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/ContentPermissions.dart';
import 'package:point/View/Contents/Mobile/ContentFormMobilePage.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:url_launcher/url_launcher.dart';

/// تفاصيل المحتوى على الجوال: نفس صلاحيات الويب ([ContentPermissions] + قواعد Firestore).
class ContentDetailsMobilePage extends StatefulWidget {
  const ContentDetailsMobilePage({super.key, required this.task});

  final ContentModel task;

  @override
  State<ContentDetailsMobilePage> createState() =>
      _ContentDetailsMobilePageState();
}

class _ContentDetailsMobilePageState extends State<ContentDetailsMobilePage> {
  late ContentModel _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pullLatest());
  }

  void _pullLatest() {
    final hc = Get.find<HomeController>();
    final id = _task.id;
    if (id == null) return;
    final fresh = hc.contents.firstWhereOrNull((c) => c.id == id);
    if (fresh != null && mounted) setState(() => _task = fresh);
  }

  Future<void> _applyStatus(String value) async {
    final controller = Get.find<HomeController>();
    final emp = _task;
    if (emp.id == null) return;
    final statusLabelAr = NotificationService.statusLabelAr(value);
    final ok = await controller.updateContent(emp.copyWith(status: value));
    if (!mounted) return;
    if (!ok) return;
    final actorName =
        (controller.currentEmployee.value?.name ?? '').trim();
    await NotificationService.notifyAdminContentStatusChanged(
      contentTitle: emp.title,
      statusLabelAr: statusLabelAr,
      changedByName: actorName.isEmpty
          ? 'notify.unknown_actor'.tr
          : actorName,
    );
    if (value == StorageKeys.status_published) {
      final clientName =
          controller.clients
              .firstWhereOrNull((c) => c.id == emp.clientId)
              ?.name ??
          emp.clientId;
      await NotificationService.notifyPromotionDeptNewPublishedContent(
        clientName: clientName,
        contentTitle: emp.title,
      );
    }
    controller.refreshFilteredContents();
    _pullLatest();
  }

  Future<void> _applyPromotion(String value) async {
    final controller = Get.find<HomeController>();
    final emp = _task;
    if (emp.id == null) return;
    final ok =
        ContentPermissions.isPromotionEmployee(controller.currentEmployee.value)
            ? await controller.updateContentPromotionField(emp.id!, value)
            : await controller.updateContent(emp.copyWith(promotion: value));
    if (!mounted) return;
    if (!ok) return;
    if (value == 'under_promotion' || value == 'end_promotion') {
      final promotionLabel =
          value == 'under_promotion' ? 'under_promotion'.tr : 'end_promotion'.tr;
      await NotificationService.notifyAdminContentPromotionStatusChanged(
        contentTitle: emp.title,
        promotionLabelAr: promotionLabel,
      );
    }
    controller.refreshFilteredContents();
    _pullLatest();
  }

  void _openEdit(HomeController hc, EmployeeModel? emp) {
    if (!ContentPermissions.canAddOrEditContent(emp)) return;
    hc.uploadedFilesPaths.assignAll(_task.files ?? []);
    Get.off(
      () => ContentFormMobilePage(
        clientId: _task.clientId,
        model: _task,
      ),
    );
  }

  Future<void> _confirmDelete(HomeController hc) async {
    final id = _task.id;
    if (id == null) return;
    await FunHelper.showConfirmDailog(
      context,
      onTap: () async {
        final ok = await hc.deleteContent(id);
        if (!mounted) return;
        if (ok) {
          // [FunHelper.showConfirmDailog] يغلق الحوار بعد onTap؛ نُخرج المستخدم من صفحة التفاصيل في الإطار التالي.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Get.back();
          });
        }
      },
    );
  }

  void _showStatusSheet(BuildContext context, EmployeeModel? emp) {
    if (!ContentPermissions.canChangePostStatus(emp)) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    AppLocaleKeys.status.tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(height: 1),
                ...StorageKeys.statusList.map(
                  (s) => ListTile(
                    title: Text(s.tr),
                    selected: s == _task.status,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _applyStatus(s);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPromotionSheet(BuildContext context, EmployeeModel? emp) {
    if (!ContentPermissions.canChangePromotionField(emp)) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  AppLocaleKeys.promotion.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(height: 1),
              ...StorageKeys.promations.map(
                (p) => ListTile(
                  title: Text(p.tr),
                  selected: p == (_task.promotion ?? '').trim() ||
                      (p == 'no_promotion' &&
                          (_task.promotion == null ||
                              _task.promotion!.trim().isEmpty)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _applyPromotion(p);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hc = Get.find<HomeController>();
    final emp = hc.currentEmployee.value;

    final canEdit = ContentPermissions.canAddOrEditContent(emp);
    final canDelete = ContentPermissions.canDeleteContent(emp);
    final canStatus = ContentPermissions.canChangePostStatus(emp);
    final canPromotion = ContentPermissions.canChangePromotionField(emp);
    final showStatusUi = ContentPermissions.showContentStatusUi(emp);
    final showPromotionUi = ContentPermissions.showContentPromotionUi(emp);
    final showPublishDateUi = ContentPermissions.showContentPublishDateUi(emp);
    final showActionsBar = canEdit || canDelete;

    final clientName =
        hc.clients
            .firstWhereOrNull((client) => client.id == _task.clientId)
            ?.name ??
        '-';
    final promotionValue =
        (_task.promotion == null || _task.promotion!.trim().isEmpty)
            ? AppLocaleKeys.contentDialogNoPromotion.tr
            : FunHelper.trStored(
              _task.promotion,
              kind: StoredValueKind.promotion,
            );
    final publishDate =
        _task.publishDate == null
            ? AppLocaleKeys.contentDialogNoDate.tr
            : FunHelper.formatdate(_task.publishDate).toString();
    final platformValue = _platformText(_task.platform);
    final bool isNotesEmpty = (_task.clientNotes?.trim().isEmpty ?? true);
    final notes = isNotesEmpty
            ? AppLocaleKeys.contentDialogNoNotes.tr
            : _task.clientNotes!.trim();

    final bool isMoreNotesEmpty = (_task.notes?.trim().isEmpty ?? true);
    final moreNotes = isMoreNotesEmpty
            ? AppLocaleKeys.contentDialogNoNotes.tr
            : _task.notes!.trim();

    final statusDisplay = FunHelper.trStored(
      _task.status,
      kind: StoredValueKind.taskStatus,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.3,
        title: Text(
          _task.title.isNotEmpty ? _task.title : 'content.details_title'.tr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (canEdit || canDelete)
            PopupMenuButton<int>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'tasks.options_tooltip'.tr,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) {
                final items = <PopupMenuEntry<int>>[];
                if (canEdit) {
                  items.add(
                    PopupMenuItem(
                      value: 0,
                      child: Row(
                        children: [
                          Expanded(child: Text('edit'.tr)),
                          const Icon(Icons.edit, color: Colors.green, size: 20),
                        ],
                      ),
                    ),
                  );
                }
                if (canDelete) {
                  items.add(
                    PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          Expanded(child: Text('delete'.tr)),
                          const Icon(Icons.delete, color: Colors.red, size: 20),
                        ],
                      ),
                    ),
                  );
                }
                return items;
              },
              onSelected: (v) {
                if (v == 0) _openEdit(hc, emp);
                if (v == 1) _confirmDelete(hc);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _tile(
                    context,
                    title: AppLocaleKeys.contentDialogClient.tr,
                    value: clientName,
                    icon: Icons.person_outline,
                  ),
                  _tile(
                    context,
                    title: AppLocaleKeys.contentType.tr,
                    value: FunHelper.trStored(
                      _task.contentType,
                      kind: StoredValueKind.contentType,
                    ),
                    icon: Icons.category_outlined,
                  ),
                  _tile(
                    context,
                    title: AppLocaleKeys.platform.tr,
                    value: platformValue,
                    icon: Icons.public,
                  ),
                  if (showStatusUi) ...[
                    if (canStatus)
                      _interactiveTile(
                        context,
                        title: AppLocaleKeys.status.tr,
                        value: statusDisplay,
                        icon: Icons.flag_outlined,
                        hint: AppLocaleKeys.contentDialogTapToChange.tr,
                        onTap: () => _showStatusSheet(context, emp),
                      )
                    else
                      _tile(
                        context,
                        title: AppLocaleKeys.status.tr,
                        value: statusDisplay,
                        icon: Icons.flag_outlined,
                      ),
                  ],
                  if (showPromotionUi) ...[
                    if (canPromotion)
                      _interactiveTile(
                        context,
                        title: AppLocaleKeys.promotion.tr,
                        value: promotionValue,
                        icon: Icons.campaign_outlined,
                        hint: AppLocaleKeys.contentDialogTapToChange.tr,
                        onTap: () => _showPromotionSheet(context, emp),
                      )
                    else
                      _tile(
                        context,
                        title: AppLocaleKeys.promotion.tr,
                        value: promotionValue,
                        icon: Icons.campaign_outlined,
                      ),
                  ],
                  _tile(
                    context,
                    title: AppLocaleKeys.clientNotes.tr,
                    value: notes,
                    icon: Icons.note_alt_outlined,
                    centerValue: isNotesEmpty,
                  ),
                  if (_clientRevisionAttachmentUrls().isNotEmpty)
                    _clientRevisionsAttachmentsCard(context),
                  _tile(
                    context,
                    title: AppLocaleKeys.notes.tr,
                    value: moreNotes,
                    icon: Icons.sticky_note_2_outlined,
                    centerValue: isMoreNotesEmpty,
                  ),
                  if (showPublishDateUi)
                    _tile(
                      context,
                      title: AppLocaleKeys.publishDate.tr,
                      value: publishDate,
                      icon: Icons.calendar_month_outlined,
                    ),
                  _attachmentsCard(context),
                ],
              ),
            ),
          ),
          if (showActionsBar)
            _bottomActionBar(context, hc, emp, canEdit, canDelete),
        ],
      ),
    );
  }

  Widget _bottomActionBar(
    BuildContext context,
    HomeController hc,
    EmployeeModel? emp,
    bool canEdit,
    bool canDelete,
  ) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      elevation: 8,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
        child: Row(
          children: [
            if (canEdit)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5C5589),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _openEdit(hc, emp),
                  icon: const Icon(Icons.edit_outlined, size: 22),
                  label: Text(
                    'edit'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            if (canEdit && canDelete) const SizedBox(width: 10),
            if (canDelete)
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _confirmDelete(hc),
                  icon: const Icon(Icons.delete_outline, size: 22),
                  label: Text(
                    'delete'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _interactiveTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required String hint,
    required VoidCallback onTap,
  }) {
    final isRtl =
        Directionality.of(context) == TextDirection.rtl ||
        Get.locale?.languageCode == 'ar';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7E0F0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFEDE2FF),
                  child: Icon(icon, size: 16, color: const Color(0xFF7E57C2)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                hint,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    bool centerValue = false,
  }) {
    final isAr = Get.locale?.languageCode == 'ar';
    final isRtl = Directionality.of(context) == TextDirection.rtl || isAr;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E0F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFEDE2FF),
                child: Icon(icon, size: 16, color: const Color(0xFF7E57C2)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: centerValue ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: centerValue
                      ? TextAlign.center
                      : (isRtl ? TextAlign.right : TextAlign.left),
                  style: TextStyle(
                    fontSize: centerValue ? 16 : 20,
                    fontWeight: centerValue ? FontWeight.w500 : FontWeight.w700,
                    color: centerValue ? Colors.grey.shade600 : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// صور/ملفات طلب التعديل (`clientEdits`) — نفس البيانات المعروضة في عمود «تعديلات العميل» بالجدول.
  List<String> _clientRevisionAttachmentUrls() {
    return (_task.clientEdits ?? [])
        .map((e) => e.toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  Widget _clientRevisionsAttachmentsCard(BuildContext context) {
    final isRtl =
        Directionality.of(context) == TextDirection.rtl ||
        Get.locale?.languageCode == 'ar';
    final files = _clientRevisionAttachmentUrls();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Column(
        crossAxisAlignment:
            isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_outlined, color: Colors.amber.shade900, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'client_revisions'.tr,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: files.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 84,
            ),
            itemBuilder: (context, index) {
              final rawUrl = files[index];
              return TaskDetailsDialogHelpers.attachmentThumbnail(
                rawUrl,
                onOpen: () => _openAttachment(rawUrl),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _attachmentsCard(BuildContext context) {
    final isRtl =
        Directionality.of(context) == TextDirection.rtl ||
        Get.locale?.languageCode == 'ar';
    final files =
        (_task.files ?? [])
            .whereType<String>()
            .where((e) => e.trim().isNotEmpty)
            .toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E0F0)),
      ),
      child: Column(
        crossAxisAlignment:
            isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleKeys.contentDialogAttachments.tr,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFEDE2FF),
                child: Icon(
                  Icons.attach_file_outlined,
                  size: 16,
                  color: Color(0xFF7E57C2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (files.isEmpty)
            Center(
              child: Text(
                AppLocaleKeys.contentDialogNoAttachments.tr,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: files.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 84,
              ),
              itemBuilder: (context, index) {
                final rawUrl = files[index];
                return TaskDetailsDialogHelpers.attachmentThumbnail(
                  rawUrl,
                  onOpen: () => _openAttachment(rawUrl),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.contentDialogOpenLinkFailed.tr,
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.contentDialogOpenLinkFailed.tr,
      );
    }
  }

  String _platformText(List<dynamic> platform) {
    if (platform.isEmpty) return '-';
    return platform.map((e) => e.toString().tr).join(' - ');
  }
}
