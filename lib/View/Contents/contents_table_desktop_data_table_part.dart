part of 'package:point/View/Contents/ContentsTable.dart';

/// Client-notes / client-revisions pill buttons need enough width so Arabic labels stay on one line.
double _notesRevisionsPillMaxWidth() {
  return math.max((Get.width - 280) / 9, 260);
}

Widget _buildDesktopContentsDataTable(BuildContext context) {
  return GetBuilder<HomeController>(
    id: 'employeeWebContent',
    builder: (_) {
      return GetX<HomeController>(
        builder: (c) {
          final controller = c;
          final emp = controller.currentEmployee.value;
          final showStatusCol = ContentPermissions.showContentStatusUi(emp);
          final showPromotionCol = ContentPermissions.showContentPromotionUi(
            emp,
          );
          final showPublishDateCol =
              ContentPermissions.showContentPublishDateUi(emp);
          final contents = _contentsListForDesktopTable(context, c);
          if (c.clientController.text.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'history.pick_client_content'.tr,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.appTheme.secondaryText,
                  ),
                ),
              ),
            );
          }
          if (contents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'history.empty_data'.tr,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.appTheme.secondaryText,
                  ),
                ),
              ),
            );
          }
          return HorizontalScrollbarTable(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 14),
              child: SizedBox(
                width: 2600,
                child: DataTable(
                  dataRowMinHeight: 72,
                  dataRowMaxHeight: double.infinity,
                  // headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                  dataRowColor: context.tableDataRowColor,
                  headingRowColor: context.tableHeadingRowColor,
                  dividerThickness: 0.5,
                  columns: [
                    DataColumn(
                      columnWidth: const FixedColumnWidth(56),
                      headingRowAlignment: MainAxisAlignment.center,
                      label: Checkbox(
                        value:
                            contents.isNotEmpty &&
                            contents
                                .where((c) => c.id != null)
                                .every(
                                  (c) => controller.selectedContentIds.contains(
                                    c.id,
                                  ),
                                ),
                        onChanged: (_) {
                          controller.toggleSelectAllVisibleContents(contents);
                        },
                      ),
                    ),
                    DataColumn(
                      columnWidth: const FixedColumnWidth(200),
                      headingRowAlignment: MainAxisAlignment.center,

                      label: Text(
                        "title".tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: context.appTheme.secondaryText,
                        ),
                      ),
                    ),
                    DataColumn(
                      columnWidth: const FixedColumnWidth(188),
                      headingRowAlignment: MainAxisAlignment.center,

                      label: Text(
                        "platform".tr,
                        style: TextStyle(
                          fontSize: 13,

                          fontWeight: FontWeight.bold,
                          color: context.appTheme.secondaryText,
                        ),
                      ),
                    ),
                    DataColumn(
                      columnWidth: const FixedColumnWidth(168),
                      headingRowAlignment: MainAxisAlignment.center,

                      label: Text(
                        "content_type".tr,
                        style: TextStyle(
                          fontSize: 13,

                          fontWeight: FontWeight.bold,
                          color: context.appTheme.secondaryText,
                        ),
                      ),
                    ),
                    DataColumn(
                      columnWidth: const FixedColumnWidth(196),
                      headingRowAlignment: MainAxisAlignment.center,

                      label: Text(
                        "content_provider".tr,
                        style: TextStyle(
                          fontSize: 13,

                          fontWeight: FontWeight.bold,
                          color: context.appTheme.secondaryText,
                        ),
                      ),
                    ),
                    if (showStatusCol)
                      DataColumn(
                        columnWidth: const FixedColumnWidth(200),
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text(
                          "status".tr,
                          style: TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                            color: context.appTheme.secondaryText,
                          ),
                        ),
                      ),
                    if (showPromotionCol)
                      DataColumn(
                        columnWidth: const FixedColumnWidth(200),
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text(
                          "promotion".tr,
                          style: TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                            color: context.appTheme.secondaryText,
                          ),
                        ),
                      ),
                    DataColumn(
                      columnWidth: const FixedColumnWidth(188),
                      headingRowAlignment: MainAxisAlignment.center,
                      label: Text(
                        'content.dialog.attachments'.tr,
                        style: TextStyle(
                          fontSize: 13,

                          fontWeight: FontWeight.bold,
                          color: context.appTheme.secondaryText,
                        ),
                      ),
                    ),
                    DataColumn(
                      columnWidth: const FixedColumnWidth(172),
                      headingRowAlignment: MainAxisAlignment.center,
                      label: Text(
                        "client_notes".tr,
                        style: TextStyle(
                          fontSize: 13,

                          fontWeight: FontWeight.bold,
                          color: context.appTheme.secondaryText,
                        ),
                      ),
                    ),
                    if (showPublishDateCol)
                      DataColumn(
                        columnWidth: const FixedColumnWidth(168),
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text(
                          "publish_date".tr,
                          style: TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                            color: context.appTheme.secondaryText,
                          ),
                        ),
                      ),
                    DataColumn(
                      columnWidth: const FixedColumnWidth(196),
                      headingRowAlignment: MainAxisAlignment.center,
                      label: Text(
                        "client_revisions".tr,
                        style: TextStyle(
                          fontSize: 13,

                          fontWeight: FontWeight.bold,
                          color: context.appTheme.secondaryText,
                        ),
                      ),
                    ),
                    DataColumn(
                      columnWidth: const FixedColumnWidth(96),
                      headingRowAlignment: MainAxisAlignment.center,
                      label: Text(
                        "actions".tr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.appTheme.secondaryText,
                        ),
                      ),
                    ),
                  ],
                  rows: contents.map((emp) {
                    return DataRow(
                      cells: [
                        DataCell(
                          TableCellCenter(
                            child: Checkbox(
                              value:
                                  emp.id != null &&
                                  controller.selectedContentIds.contains(
                                    emp.id,
                                  ),
                              onChanged: emp.id == null
                                  ? null
                                  : (v) => controller.toggleContentSelection(
                                      emp.id!,
                                      selected: v,
                                    ),
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: math.max((Get.width - 280) / 9, 200),
                              ),
                              child: Text(
                                emp.title,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: context.appTheme.secondaryText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: math.max((Get.width - 280) / 9, 188),
                              ),
                              child: Text(
                                FunHelper.formatStoredPlatforms(emp.platform),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: context.appTheme.secondaryText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Container(
                              alignment: Alignment.center,
                              width: 110,
                              height: 32,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                // vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.statusChipBackground(
                                  Colors.purple,
                                  Colors.purple.shade50,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                FunHelper.trStored(
                                  emp.contentType,
                                  kind: StoredValueKind.contentType,
                                ),
                                style: TextStyle(
                                  color: context.statusChipForeground(
                                    Colors.purple.shade700,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Container(
                              alignment: Alignment.center,
                              width: 110,
                              height: 32,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                // vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.statusChipBackground(
                                  Colors.blueGrey.shade700,
                                  Colors.blueGrey.shade100,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                controller
                                        .getEmployeeById(emp.executor)
                                        ?.name ??
                                    '',
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.statusChipForeground(
                                    Colors.blueGrey.shade700,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (showStatusCol)
                          DataCell(
                            TableCellCenter(
                              child: Builder(
                                builder: (context) {
                                  final statusChip = buildTaskStatusDropdownChip(
                                    context: context,
                                    rawStatus: emp.status,
                                    label: FunHelper.trStored(
                                      emp.status,
                                      kind: StoredValueKind.taskStatus,
                                    ),
                                  );
                                  if (!ContentPermissions.canChangePostStatus(
                                    controller.currentEmployee.value,
                                  )) {
                                    return statusChip;
                                  }
                                  final actionKey = GlobalKey();
                                  return GestureDetector(
                                    key: actionKey,
                                    onTap: () {
                                      final RenderBox renderBox =
                                          actionKey.currentContext!
                                                  .findRenderObject()
                                              as RenderBox;

                                      final Offset offset = renderBox
                                          .localToGlobal(Offset.zero);
                                      final Size size = renderBox.size;

                                      showMenu(
                                        context: context,
                                        position: RelativeRect.fromLTRB(
                                          offset.dx,
                                          offset.dy + size.height,
                                          offset.dx + size.width,
                                          0,
                                        ),
                                        items: StorageKeys.statusList.map((
                                          stat,
                                        ) {
                                          return PopupMenuItem(
                                            child: Text(stat.tr),
                                            value: stat,
                                          );
                                        }).toList(),
                                      ).then((value) async {
                                        if (value != null) {
                                          final statusLabelAr =
                                              NotificationService.statusLabelAr(
                                                value,
                                              );
                                          await controller.updateContent(
                                            emp.copyWith(status: value),
                                          );
                                          final actorName =
                                              (controller
                                                          .currentEmployee
                                                          .value
                                                          ?.name ??
                                                      '')
                                                  .trim();
                                          await NotificationService.notifyAdminContentStatusChanged(
                                            contentTitle: emp.title,
                                            statusLabelAr: statusLabelAr,
                                            changedByName: actorName.isEmpty
                                                ? 'notify.unknown_actor'.tr
                                                : actorName,
                                            fcmDataExtras:
                                                notificationContentExtras(
                                              emp.id,
                                            ),
                                          );
                                          if (value ==
                                              StorageKeys.status_published) {
                                            final clientName =
                                                controller.clients
                                                    .firstWhereOrNull(
                                                      (c) =>
                                                          c.id == emp.clientId,
                                                    )
                                                    ?.name ??
                                                emp.clientId;
                                            await NotificationService.notifyPromotionDeptNewPublishedContent(
                                              clientName: clientName,
                                              contentTitle: emp.title,
                                              fcmDataExtras:
                                                  notificationContentExtras(
                                                emp.id,
                                              ),
                                            );
                                          }
                                          controller.refreshFilteredContents();
                                        }
                                      });
                                    },
                                    child: statusChip,
                                  );
                                },
                              ),
                            ),
                          ),
                        if (showPromotionCol)
                          DataCell(
                            TableCellCenter(
                              child: Builder(
                                builder: (context) {
                                  final promoKey = FunHelper.canonicalStoredPromotion(
                                    emp.promotion,
                                  );
                                  final promoAccent =
                                      getContentPromotionColor(promoKey);
                                  final promoFg =
                                      context.statusChipForeground(promoAccent);
                                  final promotionChip = buildContentDropdownChip(
                                    label:
                                        emp.promotion == null ||
                                            emp.promotion!.trim().isEmpty
                                        ? '--'
                                        : FunHelper.trStored(
                                            emp.promotion,
                                            kind: StoredValueKind.promotion,
                                          ),
                                    textColor: promoFg,
                                    backgroundColor: context.statusChipBackground(
                                      promoAccent,
                                      getContentPromotionBgColor(promoKey),
                                    ),
                                  );
                                  if (!ContentPermissions.canChangePromotionField(
                                    controller.currentEmployee.value,
                                  )) {
                                    return promotionChip;
                                  }
                                  final actionKey = GlobalKey();
                                  return GestureDetector(
                                    key: actionKey,
                                    onTap: () {
                                      final RenderBox renderBox =
                                          actionKey.currentContext!
                                                  .findRenderObject()
                                              as RenderBox;

                                      final Offset offset = renderBox
                                          .localToGlobal(Offset.zero);
                                      final Size size = renderBox.size;

                                      showMenu(
                                        context: context,
                                        position: RelativeRect.fromLTRB(
                                          offset.dx,
                                          offset.dy + size.height,
                                          offset.dx + size.width,
                                          0,
                                        ),
                                        items: StorageKeys.promations.map((
                                          stat,
                                        ) {
                                          return PopupMenuItem(
                                            child: Text(stat.tr),
                                            value: stat,
                                          );
                                        }).toList(),
                                      ).then((value) async {
                                        if (value != null && emp.id != null) {
                                          final ok =
                                              ContentPermissions.isPromotionEmployee(
                                                controller
                                                    .currentEmployee
                                                    .value,
                                              )
                                              ? await controller
                                                    .updateContentPromotionField(
                                                      emp.id!,
                                                      value,
                                                    )
                                              : await controller.updateContent(
                                                  emp.copyWith(
                                                    promotion: value,
                                                  ),
                                                );
                                          if (!ok) return;
                                          if (value == 'under_promotion' ||
                                              value == 'end_promotion') {
                                            final promotionLabel =
                                                value == 'under_promotion'
                                                ? 'under_promotion'.tr
                                                : 'end_promotion'.tr;
                                            await NotificationService.notifyAdminContentPromotionStatusChanged(
                                              contentTitle: emp.title,
                                              promotionLabelAr: promotionLabel,
                                              fcmDataExtras:
                                                  notificationContentExtras(
                                                emp.id,
                                              ),
                                            );
                                          }
                                          controller.refreshFilteredContents();
                                        }
                                      });
                                    },
                                    child: promotionChip,
                                  );
                                },
                              ),
                            ),
                          ),
                        DataCell(
                          TableCellCenter(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: math.max((Get.width - 280) / 9, 188),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final file in emp.attachmentUrls)
                                      InkWell(
                                        onTap: () async {
                                          if (getFileType(file) == 'image') {
                                            Get.dialog(
                                              AlertDialog(
                                                actions: [
                                                  MainButton(
                                                    icon: false,
                                                    title: 'app.close'.tr,
                                                    fontColor: Colors.white,
                                                    backgroundColor:
                                                        AppColors.primary,
                                                    width: 100,
                                                    borderSize: 5,
                                                    height: 30,
                                                    onPressed: () {
                                                      Get.back();
                                                    },
                                                  ),
                                                ],
                                                content: SafeNetworkImage(
                                                  file,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          await _openAttachmentUrl(file);
                                        },
                                        child: SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: AttachmentThumbnailTile(
                                            url: file,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: SizedBox(
                              width: _notesRevisionsPillMaxWidth(),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed:
                                    (emp.clientNotes ?? '').trim().isEmpty
                                    ? null
                                    : () => _showLongTextPopup(
                                        context,
                                        title: 'client_notes'.tr,
                                        value: emp.clientNotes ?? '',
                                      ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.sticky_note_2_outlined,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'content.open_client_notes'.tr,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (showPublishDateCol)
                          DataCell(
                            TableCellCenter(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: math.max(
                                    (Get.width - 280) / 9,
                                    168,
                                  ),
                                ),
                                child: Text(
                                  FunHelper.formatdate(emp.publishDate) ?? '--',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: context.appTheme.secondaryText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        DataCell(
                          TableCellCenter(
                            child: SizedBox(
                              width: _notesRevisionsPillMaxWidth(),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: (emp.clientEdits ?? []).isEmpty
                                    ? null
                                    : () => _showClientRevisionsPopup(
                                        context,
                                        files: (emp.clientEdits ?? [])
                                            .whereType<String>()
                                            .toList(),
                                      ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.edit_note_outlined,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${'client_revisions'.tr} (${(emp.clientEdits ?? []).length})',
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Builder(
                              builder: (context) {
                                final cur = controller.currentEmployee.value;
                                final canEdit =
                                    ContentPermissions.canAddOrEditContent(cur);
                                final canDelete =
                                    ContentPermissions.canDeleteContent(cur);
                                final canPostStatus =
                                    ContentPermissions.canChangePostStatus(cur);
                                if (!canEdit && !canDelete && !canPostStatus) {
                                  return const SizedBox.shrink();
                                }
                                return PopupMenuButton<int>(
                                  tooltip: 'tasks.options_tooltip'.tr,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  color: context.appTheme.cardSurface,
                                  elevation: 4,
                                  itemBuilder: (context) {
                                    final items = <PopupMenuEntry<int>>[];
                                    final menuTextStyle = TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: context.appTheme.primaryText,
                                    );
                                    if (canEdit) {
                                      items.add(
                                        PopupMenuItem(
                                          value: 0,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'edit'.tr,
                                                style: menuTextStyle,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(width: 4),
                                              Icon(
                                                Icons.edit,
                                                color: Colors.green,
                                                size: 18,
                                              ),
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
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'delete'.tr,
                                                style: menuTextStyle,
                                              ),
                                              SizedBox(width: 4),
                                              Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    if (canPostStatus) {
                                      items.add(
                                        PopupMenuItem(
                                          value: 2,
                                          child: Row(
                                            children: [
                                              Text(
                                                'content.publish_now'.tr,
                                                style: menuTextStyle,
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.publish,
                                                size: 18,
                                                color: context.appTheme.primaryText,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                      items.add(
                                        PopupMenuItem(
                                          value: 3,
                                          child: Row(
                                            children: [
                                              Text(
                                                'content.schedule'.tr,
                                                style: menuTextStyle,
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.schedule,
                                                size: 18,
                                                color: context.appTheme.primaryText,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return items;
                                  },
                                  onSelected: (value) {
                                    if (value == 0) {
                                      controller.uploadedFilesPaths.assignAll(
                                        emp.attachmentUrls,
                                      );
                                      showAddContentDialog(
                                        context,
                                        clientId:
                                            controller.clientController.text,
                                        model: emp,
                                      );
                                    } else if (value == 1) {
                                      FunHelper.showConfirmDailog(
                                        context,
                                        onTap: () async {
                                          await controller.deleteContent(
                                            emp.id!,
                                          );
                                        },
                                      );
                                    } else if (value == 2) {
                                      final contentType =
                                          emp.contentType.toLowerCase();
                                      final dedicated = (contentType
                                                  .contains('reel')
                                              ? emp.reelAttachments
                                              : (contentType.contains('story')
                                                  ? emp.storyAttachments
                                                  : emp.postAttachments)) ??
                                          const <dynamic>[];
                                      final draft = controller
                                          .buildMetaDraftFromContent(
                                            emp,
                                            schedule: false,
                                          );
                                      if (draft != null) {
                                        showAddPublishDialog(
                                          initialDraft: draft,
                                          initialScheduleMode: 'now',
                                          forceSingleMediaSelection:
                                              dedicated.length > 1,
                                          queueOnNowSave: true,
                                        );
                                      }
                                    } else if (value == 3) {
                                      final contentType =
                                          emp.contentType.toLowerCase();
                                      final dedicated = (contentType
                                                  .contains('reel')
                                              ? emp.reelAttachments
                                              : (contentType.contains('story')
                                                  ? emp.storyAttachments
                                                  : emp.postAttachments)) ??
                                          const <dynamic>[];
                                      final draft = controller
                                          .buildScheduledMetaDraftFromContent(
                                            emp,
                                          );
                                      if (draft != null) {
                                        showAddPublishDialog(
                                          initialDraft: draft,
                                          initialScheduleMode: 'schedule',
                                          forceSingleMediaSelection:
                                              dedicated.length > 1,
                                        );
                                      }
                                    }
                                  },
                                  child: Icon(Icons.more_vert),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

void _showLongTextPopup(
  BuildContext context, {
  required String title,
  required String value,
}) {
  Get.dialog(
    AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(child: Text(value.trim())),
      ),
      actions: [TextButton(onPressed: Get.back, child: Text('app.close'.tr))],
    ),
  );
}

void _showClientRevisionsPopup(
  BuildContext context, {
  required List<String> files,
}) {
  Get.dialog(
    AlertDialog(
      title: Text('client_revisions'.tr),
      content: SizedBox(
        width: 560,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final file in files)
              InkWell(
                onTap: () => _openAttachmentUrl(file),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: AttachmentThumbnailTile(url: file),
                ),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: Get.back, child: Text('app.close'.tr))],
    ),
  );
}
