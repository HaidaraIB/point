part of 'package:point/View/Contents/ContentsTable.dart';

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
                      color: AppColors.fontColorGrey,
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
                      color: AppColors.fontColorGrey,
                    ),
                  ),
                ),
              );
            }
            return HorizontalScrollbarTable(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 14),
                child: SizedBox(
                  width: 2000,
                  child: DataTable(
                    dataRowMinHeight: 72,
                    dataRowMaxHeight: double.infinity,
                    // headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                    dataRowColor: WidgetStateProperty.all(Colors.white),
                    dividerThickness: 0.5,
                    columns: [
                      DataColumn(
                        columnWidth: const FixedColumnWidth(180),
                        headingRowAlignment: MainAxisAlignment.center,

                        label: Text(
                          "title".tr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.fontColorGrey,
                          ),
                        ),
                      ),
                      DataColumn(
                        columnWidth: const FixedColumnWidth(180),
                        headingRowAlignment: MainAxisAlignment.center,

                        label: Text(
                          "platform".tr,
                          style: TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                            color: AppColors.fontColorGrey,
                          ),
                        ),
                      ),
                      DataColumn(
                        columnWidth: const FixedColumnWidth(160),
                        headingRowAlignment: MainAxisAlignment.center,

                        label: Text(
                          "content_type".tr,
                          style: TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                            color: AppColors.fontColorGrey,
                          ),
                        ),
                      ),
                      DataColumn(
                        columnWidth: const FixedColumnWidth(180),
                        headingRowAlignment: MainAxisAlignment.center,

                        label: Text(
                          "content_provider".tr,
                          style: TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                            color: AppColors.fontColorGrey,
                          ),
                        ),
                      ),
                      if (showStatusCol)
                        DataColumn(
                          columnWidth: const FixedColumnWidth(210),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Text(
                            "status".tr,
                            style: TextStyle(
                              fontSize: 13,

                              fontWeight: FontWeight.bold,
                              color: AppColors.fontColorGrey,
                            ),
                          ),
                        ),
                      if (showPromotionCol)
                        DataColumn(
                          columnWidth: const FixedColumnWidth(210),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Text(
                            "promotion".tr,
                            style: TextStyle(
                              fontSize: 13,

                              fontWeight: FontWeight.bold,
                              color: AppColors.fontColorGrey,
                            ),
                          ),
                        ),
                      DataColumn(
                        columnWidth: const FixedColumnWidth(180),
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text(
                          'content.dialog.attachments'.tr,
                          style: TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                            color: AppColors.fontColorGrey,
                          ),
                        ),
                      ),
                      DataColumn(
                        columnWidth: const FixedColumnWidth(160),
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text(
                          "client_notes".tr,
                          style: TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                            color: AppColors.fontColorGrey,
                          ),
                        ),
                      ),
                      if (showPublishDateCol)
                        DataColumn(
                          columnWidth: const FixedColumnWidth(160),
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Text(
                            "publish_date".tr,
                            style: TextStyle(
                              fontSize: 13,

                              fontWeight: FontWeight.bold,
                              color: AppColors.fontColorGrey,
                            ),
                          ),
                        ),
                      DataColumn(
                        columnWidth: const FixedColumnWidth(180),
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text(
                          "client_revisions".tr,
                          style: TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                            color: AppColors.fontColorGrey,
                          ),
                        ),
                      ),
                      DataColumn(
                        columnWidth: const FixedColumnWidth(160),
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text(
                          "actions".tr,
                          style: TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                            color: AppColors.fontColorGrey,
                          ),
                        ),
                      ),
                    ],
                    rows:
                        contents.map((emp) {
                          return DataRow(
                            cells: [
                              DataCell(
                                TableCellCenter(
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: math.max(
                                        (Get.width - 280) / 9,
                                        120,
                                      ),
                                    ),
                                    child: Text(
                                      emp.title,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fontColorGrey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                TableCellCenter(
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: math.max(
                                        (Get.width - 280) / 9,
                                        120,
                                      ),
                                    ),
                                    child: Text(
                                      FunHelper.formatStoredPlatforms(
                                        emp.platform,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fontColorGrey,
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
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      FunHelper.trStored(
                                        emp.contentType,
                                        kind: StoredValueKind.contentType,
                                      ),
                                      style: TextStyle(
                                        color: Colors.purple,
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
                                      color: Colors.blueGrey.shade100,
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
                                        color: Colors.blueGrey,
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
                                        final statusChip = buildContentDropdownChip(
                                          label: FunHelper.trStored(
                                            emp.status,
                                            kind: StoredValueKind.taskStatus,
                                          ),
                                          textColor: getContentStatusColor(
                                            FunHelper.canonicalStoredStatus(
                                              emp.status,
                                            ),
                                          ),
                                          backgroundColor:
                                              getContentStatusBgColor(
                                                FunHelper.canonicalStoredStatus(
                                                  emp.status,
                                                ),
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
                                              items:
                                                  StorageKeys.statusList.map((
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
                                                  changedByName:
                                                      actorName.isEmpty
                                                          ? 'notify.unknown_actor'
                                                              .tr
                                                          : actorName,
                                                );
                                                if (value ==
                                                    StorageKeys
                                                        .status_published) {
                                                  final clientName =
                                                      controller.clients
                                                          .firstWhereOrNull(
                                                            (c) =>
                                                                c.id ==
                                                                emp.clientId,
                                                          )
                                                          ?.name ??
                                                      emp.clientId;
                                                  await NotificationService.notifyPromotionDeptNewPublishedContent(
                                                    clientName: clientName,
                                                    contentTitle: emp.title,
                                                  );
                                                }
                                                controller
                                                    .refreshFilteredContents();
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
                                        final promotionChip = buildContentDropdownChip(
                                          label:
                                              emp.promotion == null ||
                                                      emp.promotion!
                                                          .trim()
                                                          .isEmpty
                                                  ? '--'
                                                  : FunHelper.trStored(
                                                    emp.promotion,
                                                    kind:
                                                        StoredValueKind
                                                            .promotion,
                                                  ),
                                          textColor: getContentPromotionColor(
                                            FunHelper.canonicalStoredPromotion(
                                              emp.promotion,
                                            ),
                                          ),
                                          backgroundColor:
                                              getContentPromotionBgColor(
                                                FunHelper.canonicalStoredPromotion(
                                                  emp.promotion,
                                                ),
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
                                              items:
                                                  StorageKeys.promations.map((
                                                    stat,
                                                  ) {
                                                    return PopupMenuItem(
                                                      child: Text(stat.tr),
                                                      value: stat,
                                                    );
                                                  }).toList(),
                                            ).then((value) async {
                                              if (value != null &&
                                                  emp.id != null) {
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
                                                        : await controller
                                                            .updateContent(
                                                              emp.copyWith(
                                                                promotion:
                                                                    value,
                                                              ),
                                                            );
                                                if (!ok) return;
                                                if (value ==
                                                        'under_promotion' ||
                                                    value == 'end_promotion') {
                                                  final promotionLabel =
                                                      value == 'under_promotion'
                                                          ? 'under_promotion'.tr
                                                          : 'end_promotion'.tr;
                                                  await NotificationService.notifyAdminContentPromotionStatusChanged(
                                                    contentTitle: emp.title,
                                                    promotionLabelAr:
                                                        promotionLabel,
                                                  );
                                                }
                                                controller
                                                    .refreshFilteredContents();
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
                                      maxWidth: math.max(
                                        (Get.width - 280) / 9,
                                        120,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          for (var file in emp.files ?? [])
                                            InkWell(
                                              onTap: () async {
                                                if (getFileType(file) ==
                                                    'image') {
                                                  Get.dialog(
                                                    AlertDialog(
                                                      actions: [
                                                        MainButton(
                                                          icon: false,
                                                          title: 'app.close'.tr,
                                                          fontColor:
                                                              Colors.white,
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
                                                      content: Image.network(
                                                        file,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                await _openAttachmentUrl(file);
                                              },
                                              child:
                                                  _buildAttachmentPreviewTile(
                                                    file,
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
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: math.max(
                                        (Get.width - 280) / 9,
                                        120,
                                      ),
                                    ),
                                    child: Text(
                                      emp.clientNotes ?? '--',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fontColorGrey,
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
                                          120,
                                        ),
                                      ),
                                      child: Text(
                                        FunHelper.formatdate(emp.publishDate) ??
                                            '--',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.fontColorGrey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              DataCell(
                                TableCellCenter(
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: math.max(
                                        (Get.width - 280) / 9,
                                        120,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          for (var file
                                              in emp.clientEdits ?? [])
                                            InkWell(
                                              onTap: () async {
                                                if (getFileType(file) ==
                                                    'image') {
                                                  Get.dialog(
                                                    AlertDialog(
                                                      actions: [
                                                        MainButton(
                                                          icon: false,
                                                          title: 'app.close'.tr,
                                                          fontColor:
                                                              Colors.white,
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
                                                      content: Image.network(
                                                        file,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                await _openAttachmentUrl(file);
                                              },
                                              child:
                                                  _buildAttachmentPreviewTile(
                                                    file,
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
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: 88,
                                      height: 40,
                                      child: Builder(
                                        builder: (context) {
                                          final cur =
                                              controller.currentEmployee.value;
                                          final canEdit =
                                              ContentPermissions.canAddOrEditContent(
                                                cur,
                                              );
                                          final canDelete =
                                              ContentPermissions.canDeleteContent(
                                                cur,
                                              );
                                          if (!canEdit && !canDelete) {
                                            return const SizedBox.shrink();
                                          }
                                          return PopupMenuButton<int>(
                                            tooltip: 'tasks.options_tooltip'.tr,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            color: Colors.white,
                                            elevation: 4,
                                            itemBuilder: (context) {
                                              final items =
                                                  <PopupMenuEntry<int>>[];
                                              if (canEdit) {
                                                items.add(
                                                  PopupMenuItem(
                                                    value: 0,
                                                    height: 30,
                                                    child: Container(
                                                      height: 30,
                                                      margin: EdgeInsets.all(2),
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            vertical: 5,
                                                          ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              'edit'.tr,
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
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
                                                  ),
                                                );
                                              }
                                              if (canDelete) {
                                                items.add(
                                                  PopupMenuItem(
                                                    value: 1,
                                                    height: 30,
                                                    child: Container(
                                                      height: 30,
                                                      margin: EdgeInsets.all(2),
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            vertical: 5,
                                                          ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'delete'.tr,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12,
                                                            ),
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
                                                  ),
                                                );
                                              }
                                              return items;
                                            },
                                            onSelected: (value) {
                                              if (value == 0) {
                                                controller.uploadedFilesPaths
                                                    .assignAll(emp.files ?? []);
                                                showAddContentDialog(
                                                  context,
                                                  clientId:
                                                      controller
                                                          .clientController
                                                          .text,
                                                  model: emp,
                                                );
                                              } else if (value == 1) {
                                                FunHelper.showConfirmDailog(
                                                  context,
                                                  onTap: () async {
                                                    await controller
                                                        .deleteContent(emp.id!);
                                                  },
                                                );
                                              }
                                            },
                                            child: Icon(Icons.more_vert),
                                          );
                                        },
                                      ),
                                    ),
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

