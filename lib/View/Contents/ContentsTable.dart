import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Contents/ContentDialogDetails.dart';
import 'package:point/View/Contents/Mobile/ContentFormMobilePage.dart';
import 'package:point/View/EmployeeDashboard/EmployeeContentDashboard.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart';

import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/ContentStatusPromotionDropdownChip.dart';
import 'package:point/View/Shared/HorizantalScroll.dart';
import 'package:point/View/Shared/TableCellCenter.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/t.dart';
import 'package:url_launcher/url_launcher.dart';

class ContentsTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().currentemployee.value;
    if (emp?.role == 'employee') {
      return const EmployeeContentDashboard();
    }
    return ResponsiveScaffold(
      selectedTab: 3,
      sideMenu:
          Get.find<HomeController>().currentemployee.value?.role != 'employee'
              ? true
              : false,

      body: GetBuilder<HomeController>(
        builder: (controller) {
          return Responsive(
            mobile: _buildMobileContent(context, controller),
            desktop: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width:
                        Responsive.isDesktop(context)
                            ? Get.width - 270
                            : Get.width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: 50),

                        Row(
                          children: [
                            Text(
                              'managecontent'.tr,
                              style: TextStyle(
                                color: AppColors.fontColorGrey,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            MainButton(
                              width: 180,
                              height: 45,
                              borderSize: 35,
                              fontColor: Colors.white,
                              backgroundColor: AppColors.primary,
                              widget: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'addnewcontent'.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                              onPressed: () {
                                if (controller.clientController.text.isEmpty) {
                                  FunHelper.showSnackbar(
                                    'error'.tr,
                                    'content.form.select_client_first'.tr,
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                  return;
                                }
                                controller.uploadedFilesPaths.clear();
                                showAddContentDialog(
                                  context,
                                  clientId: controller.clientController.text,
                                );
                              },
                            ),
                            SizedBox(width: 10),
                            if (controller.currentemployee.value?.department ==
                                    'cat1' ||
                                controller.currentemployee.value?.department ==
                                    'cat6')
                              MainButton(
                                width: 180,
                                height: 45,
                                borderSize: 35,
                                fontColor: Colors.white,
                                backgroundColor: AppColors.primary,
                                widget: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'tasks'.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(width: 5),
                                    Icon(
                                      Icons.navigate_next,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                                onPressed: () {
                                  Get.toNamed('/employeeDashboard');
                                },
                              ),
                          ],
                        ),
                        Obx(() {
                          // Must read observable so Obx can track and rebuild
                          final clients = controller.clients;
                          return SizedBox(
                            width: (Get.width * 0.7 / 2) - 20,
                            child: DynamicDropdown(
                              items:
                                  clients
                                      .map(
                                        (v) => DropdownMenuItem(
                                          value: v,
                                          child: Text('${v.name}'),
                                        ),
                                      )
                                      .toList(),
                              value:
                                  controller.clientController.text.isEmpty
                                      ? null
                                      : clients.firstWhere(
                                        (a) =>
                                            a.id ==
                                            controller.clientController.text,
                                      ),
                              label: 'chooseclient'.tr,
                              borderRadius: 5,
                              borderColor: Colors.grey.shade300,
                              height: 42,
                              fillColor: Colors.white,
                              onChanged: (value) {
                                if (value != null) {
                                  controller.clientController.text =
                                      (value).id ?? '';
                                  controller.refreshFilteredContents();
                                }
                                log(
                                  "Selected client ID: ${controller.clientController.text}",
                                );
                              },
                              validator: (v) {
                                if (v == null) return ' ';
                                return null;
                              },
                            ),
                          );
                        }),

                        SizedBox(height: 10),
                        GetX<HomeController>(
                          builder: (c) {
                            final contents = c.searchedContents.toList();
                            if (c.clientController.text.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 32,
                                  ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 32,
                                  ),
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
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  bottom: 14,
                                ),
                                child: SizedBox(
                                  width: 2000,
                                  child: DataTable(
                                    dataRowMinHeight: 72,
                                    dataRowMaxHeight: double.infinity,
                                    // headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                                    dataRowColor: WidgetStateProperty.all(
                                      Colors.white,
                                    ),
                                    dividerThickness: 0.5,
                                    columns: [
                                      DataColumn(
                                        columnWidth: const FixedColumnWidth(
                                          180,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,

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
                                        columnWidth: const FixedColumnWidth(
                                          180,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,

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
                                        columnWidth: const FixedColumnWidth(
                                          160,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,

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
                                        columnWidth: const FixedColumnWidth(
                                          180,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,

                                        label: Text(
                                          "content_provider".tr,
                                          style: TextStyle(
                                            fontSize: 13,

                                            fontWeight: FontWeight.bold,
                                            color: AppColors.fontColorGrey,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        columnWidth: const FixedColumnWidth(
                                          210,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,
                                        label: Text(
                                          "status".tr,
                                          style: TextStyle(
                                            fontSize: 13,

                                            fontWeight: FontWeight.bold,
                                            color: AppColors.fontColorGrey,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        columnWidth: const FixedColumnWidth(
                                          210,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,
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
                                        columnWidth: const FixedColumnWidth(
                                          180,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,
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
                                        columnWidth: const FixedColumnWidth(
                                          160,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,
                                        label: Text(
                                          "client_notes".tr,
                                          style: TextStyle(
                                            fontSize: 13,

                                            fontWeight: FontWeight.bold,
                                            color: AppColors.fontColorGrey,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        columnWidth: const FixedColumnWidth(
                                          160,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,
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
                                        columnWidth: const FixedColumnWidth(
                                          180,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,
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
                                        columnWidth: const FixedColumnWidth(
                                          160,
                                        ),
                                        headingRowAlignment:
                                            MainAxisAlignment.center,
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
                                                      textAlign:
                                                          TextAlign.center,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 2,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors
                                                                .fontColorGrey,
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors
                                                                .fontColorGrey,
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
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          // vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.purple.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      FunHelper.trStored(
                                                        emp.contentType,
                                                        kind:
                                                            StoredValueKind
                                                                .contentType,
                                                      ),
                                                      style: TextStyle(
                                                        color: Colors.purple,
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          // vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors
                                                              .blueGrey
                                                              .shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      controller
                                                              .getEmployeeById(
                                                                emp.executor,
                                                              )
                                                              ?.name ??
                                                          '',
                                                      textAlign:
                                                          TextAlign.center,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: Colors.blueGrey,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                TableCellCenter(
                                                  child: Builder(
                                                    builder: (context) {
                                                      final actionKey =
                                                          GlobalKey();
                                                      return GestureDetector(
                                                        key: actionKey,
                                                        onTap: () {
                                                          final RenderBox
                                                          renderBox =
                                                              actionKey
                                                                      .currentContext!
                                                                      .findRenderObject()
                                                                  as RenderBox;

                                                          final Offset
                                                          offset = renderBox
                                                              .localToGlobal(
                                                                Offset.zero,
                                                              );
                                                          final Size size =
                                                              renderBox.size;

                                                          showMenu(
                                                            context: context,
                                                            position:
                                                                RelativeRect.fromLTRB(
                                                                  offset.dx,
                                                                  offset.dy +
                                                                      size.height,
                                                                  offset.dx +
                                                                      size.width,
                                                                  0,
                                                                ),
                                                            items:
                                                                StorageKeys
                                                                    .statusList
                                                                    .map((
                                                                      stat,
                                                                    ) {
                                                                      return PopupMenuItem(
                                                                        child: Text(
                                                                          stat.tr,
                                                                        ),
                                                                        value:
                                                                            stat,
                                                                      );
                                                                    })
                                                                    .toList(),
                                                          ).then((value) async {
                                                            if (value != null) {
                                                              final statusLabelAr =
                                                                  NotificationService.statusLabelAr(
                                                                    value,
                                                                  );
                                                              await controller
                                                                  .updateContent(
                                                                    emp.copyWith(
                                                                      status:
                                                                          value,
                                                                    ),
                                                                  );
                                                              final actorName =
                                                                  (controller
                                                                              .currentemployee
                                                                              .value
                                                                              ?.name ??
                                                                          '')
                                                                      .trim();
                                                              await NotificationService.notifyAdminContentStatusChanged(
                                                                contentTitle:
                                                                    emp.title,
                                                                statusLabelAr:
                                                                    statusLabelAr,
                                                                changedByName:
                                                                    actorName
                                                                            .isEmpty
                                                                        ? 'notify.unknown_actor'
                                                                            .tr
                                                                        : actorName,
                                                              );
                                                              if (value ==
                                                                  StorageKeys
                                                                      .status_published) {
                                                                final clientName =
                                                                    controller
                                                                        .clients
                                                                        .firstWhereOrNull(
                                                                          (c) =>
                                                                              c.id ==
                                                                              emp.clientId,
                                                                        )
                                                                        ?.name ??
                                                                    emp.clientId;
                                                                await NotificationService.notifyPromotionDeptNewPublishedContent(
                                                                  clientName:
                                                                      clientName,
                                                                  contentTitle:
                                                                      emp.title,
                                                                );
                                                              }
                                                              controller
                                                                  .refreshFilteredContents();
                                                            }
                                                          });
                                                        },
                                                        child: buildContentDropdownChip(
                                                          label: FunHelper.trStored(
                                                            emp.status,
                                                            kind:
                                                                StoredValueKind
                                                                    .taskStatus,
                                                          ),
                                                          textColor:
                                                              getContentStatusColor(
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
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                TableCellCenter(
                                                  child: Builder(
                                                    builder: (context) {
                                                      final actionKey =
                                                          GlobalKey();
                                                      return GestureDetector(
                                                        key: actionKey,
                                                        onTap: () {
                                                          if (controller
                                                                      .currentemployee
                                                                      .value
                                                                      ?.role !=
                                                                  'admin' &&
                                                              controller
                                                                      .currentemployee
                                                                      .value
                                                                      ?.role !=
                                                                  'accountholder' &&
                                                              controller
                                                                      .currentemployee
                                                                      .value
                                                                      ?.role !=
                                                                  'supervisor' &&
                                                              controller
                                                                      .currentemployee
                                                                      .value
                                                                      ?.department !=
                                                                  'cat1') {
                                                            FunHelper.showSnackbar(
                                                              'error'.tr,
                                                              'errors.no_promotion_permission'
                                                                  .tr,
                                                              snackPosition:
                                                                  SnackPosition
                                                                      .BOTTOM,
                                                              backgroundColor:
                                                                  Colors.red,
                                                              colorText:
                                                                  Colors.white,
                                                            );
                                                            return;
                                                          }
                                                          final RenderBox
                                                          renderBox =
                                                              actionKey
                                                                      .currentContext!
                                                                      .findRenderObject()
                                                                  as RenderBox;

                                                          final Offset
                                                          offset = renderBox
                                                              .localToGlobal(
                                                                Offset.zero,
                                                              );
                                                          final Size size =
                                                              renderBox.size;

                                                          showMenu(
                                                            context: context,
                                                            position:
                                                                RelativeRect.fromLTRB(
                                                                  offset.dx,
                                                                  offset.dy +
                                                                      size.height,
                                                                  offset.dx +
                                                                      size.width,
                                                                  0,
                                                                ),
                                                            items:
                                                                StorageKeys
                                                                    .promations
                                                                    .map((
                                                                      stat,
                                                                    ) {
                                                                      return PopupMenuItem(
                                                                        child: Text(
                                                                          stat.tr,
                                                                        ),
                                                                        value:
                                                                            stat,
                                                                      );
                                                                    })
                                                                    .toList(),
                                                          ).then((value) async {
                                                            if (value != null) {
                                                              await controller
                                                                  .updateContent(
                                                                    emp.copyWith(
                                                                      promotion:
                                                                          value,
                                                                    ),
                                                                  );
                                                              if (value ==
                                                                      'under_promotion' ||
                                                                  value ==
                                                                      'end_promotion') {
                                                                final promotionLabel =
                                                                    value ==
                                                                            'under_promotion'
                                                                        ? 'under_promotion'
                                                                            .tr
                                                                        : 'end_promotion'
                                                                            .tr;
                                                                await NotificationService.notifyAdminContentPromotionStatusChanged(
                                                                  contentTitle:
                                                                      emp.title,
                                                                  promotionLabelAr:
                                                                      promotionLabel,
                                                                );
                                                              }
                                                              controller
                                                                  .refreshFilteredContents();
                                                            }
                                                          });
                                                        },
                                                        child: buildContentDropdownChip(
                                                          label:
                                                              emp.promotion ==
                                                                          null ||
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
                                                          textColor:
                                                              getContentPromotionColor(
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
                                                        ),
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
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 6,
                                                          ),
                                                      child: Wrap(
                                                        spacing: 10,
                                                        runSpacing: 10,
                                                        children: [
                                                          for (var file
                                                              in emp.files ??
                                                                  [])
                                                            InkWell(
                                                              onTap: () async {
                                                                if (getFileType(
                                                                      file,
                                                                    ) ==
                                                                    'image') {
                                                                  Get.dialog(
                                                                    AlertDialog(
                                                                      actions: [
                                                                        MainButton(
                                                                          icon:
                                                                              false,
                                                                          title:
                                                                              'app.close'.tr,
                                                                          fontColor:
                                                                              Colors.white,
                                                                          backgroundColor:
                                                                              AppColors.primary,
                                                                          width:
                                                                              100,
                                                                          borderSize:
                                                                              5,
                                                                          height:
                                                                              30,
                                                                          onPressed: () {
                                                                            Get.back();
                                                                          },
                                                                        ),
                                                                      ],
                                                                      content: Image.network(
                                                                        file,
                                                                        fit:
                                                                            BoxFit.contain,
                                                                      ),
                                                                    ),
                                                                  );
                                                                  return;
                                                                }
                                                                await _openAttachmentUrl(
                                                                  file,
                                                                );
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors
                                                                .fontColorGrey,
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
                                                      FunHelper.formatdate(
                                                            emp.publishDate,
                                                          ) ??
                                                          '--',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors
                                                                .fontColorGrey,
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
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 6,
                                                          ),
                                                      child: Wrap(
                                                        spacing: 10,
                                                        runSpacing: 10,
                                                        children: [
                                                          for (var file
                                                              in emp.clientEdits ??
                                                                  [])
                                                            InkWell(
                                                              onTap: () async {
                                                                if (getFileType(
                                                                      file,
                                                                    ) ==
                                                                    'image') {
                                                                  Get.dialog(
                                                                    AlertDialog(
                                                                      actions: [
                                                                        MainButton(
                                                                          icon:
                                                                              false,
                                                                          title:
                                                                              'app.close'.tr,
                                                                          fontColor:
                                                                              Colors.white,
                                                                          backgroundColor:
                                                                              AppColors.primary,
                                                                          width:
                                                                              100,
                                                                          borderSize:
                                                                              5,
                                                                          height:
                                                                              30,
                                                                          onPressed: () {
                                                                            Get.back();
                                                                          },
                                                                        ),
                                                                      ],
                                                                      content: Image.network(
                                                                        file,
                                                                        fit:
                                                                            BoxFit.contain,
                                                                      ),
                                                                    ),
                                                                  );
                                                                  return;
                                                                }
                                                                await _openAttachmentUrl(
                                                                  file,
                                                                );
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
                                                      child: PopupMenuButton<
                                                        int
                                                      >(
                                                        tooltip:
                                                            'tasks.options_tooltip'
                                                                .tr,
                                                        padding:
                                                            EdgeInsets.zero,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        color: Colors.white,
                                                        elevation: 4,
                                                        itemBuilder:
                                                            (context) => [
                                                              PopupMenuItem(
                                                                value: 0,
                                                                height: 30,

                                                                child: Container(
                                                                  height: 30,
                                                                  margin:
                                                                      EdgeInsets.all(
                                                                        2,
                                                                      ),
                                                                  padding:
                                                                      EdgeInsets.symmetric(
                                                                        vertical:
                                                                            5,
                                                                      ),
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Flexible(
                                                                        child: Text(
                                                                          'edit'
                                                                              .tr,
                                                                          style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                12,
                                                                          ),
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        width:
                                                                            4,
                                                                      ),
                                                                      Icon(
                                                                        Icons
                                                                            .edit,
                                                                        color:
                                                                            Colors.green,
                                                                        size:
                                                                            18,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              if ([
                                                                'supervisor',
                                                                'admin',
                                                                'accountholder',
                                                              ].contains(
                                                                (controller
                                                                            .currentemployee
                                                                            .value
                                                                            ?.role ??
                                                                        '')
                                                                    .trim()
                                                                    .toLowerCase(),
                                                              ))
                                                                PopupMenuItem(
                                                                  value: 1,

                                                                  height: 30,

                                                                  child: Container(
                                                                    height: 30,
                                                                    margin:
                                                                        EdgeInsets.all(
                                                                          2,
                                                                        ),
                                                                    padding:
                                                                        EdgeInsets.symmetric(
                                                                          vertical:
                                                                              5,
                                                                        ),

                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Text(
                                                                          'delete'
                                                                              .tr,
                                                                          style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                12,
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              4,
                                                                        ),
                                                                        Icon(
                                                                          Icons
                                                                              .delete,
                                                                          color:
                                                                              Colors.red,
                                                                          size:
                                                                              18,
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                        onSelected: (value) {
                                                          if (value == 0) {
                                                            controller
                                                                .uploadedFilesPaths
                                                                .assignAll(
                                                                  emp.files ??
                                                                      [],
                                                                );
                                                            showAddContentDialog(
                                                              context,
                                                              clientId:
                                                                  controller
                                                                      .clientController
                                                                      .text,
                                                              model: emp,
                                                            );
                                                          } else if (value ==
                                                              1) {
                                                            FunHelper.showConfirmDailog(
                                                              context,
                                                              onTap: () async {
                                                                await controller
                                                                    .deleteContent(
                                                                      emp.id!,
                                                                    );
                                                              },
                                                            );
                                                          }
                                                        },
                                                        child: Icon(
                                                          Icons.more_vert,
                                                        ),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildMobileContent(
    BuildContext context,
    HomeController controller,
  ) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(10),
        width: Get.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'managecontent'.tr,
                    style: TextStyle(
                      color: AppColors.fontColorGrey,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                MainButton(
                  width: 160,
                  height: 45,
                  borderSize: 35,
                  fontColor: Colors.white,
                  backgroundColor: AppColors.primary,
                  widget: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'addnewcontent'.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  onPressed: () {
                    if (controller.clientController.text.isEmpty) {
                      FunHelper.showSnackbar(
                        'error'.tr,
                        'content.form.select_client_first'.tr,
                        snackPosition: SnackPosition.TOP,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                      return;
                    }
                    controller.uploadedFilesPaths.clear();
                    Get.to(
                      () => ContentFormMobilePage(
                        clientId: controller.clientController.text,
                        model: null,
                      ),
                    );
                  },
                ),
                if (controller.currentemployee.value?.department == 'cat1' ||
                    controller.currentemployee.value?.department == 'cat6') ...[
                  const SizedBox(width: 8),
                  MainButton(
                    width: 140,
                    height: 45,
                    borderSize: 35,
                    fontColor: Colors.white,
                    backgroundColor: AppColors.primary,
                    widget: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'tasks'.tr,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.navigate_next,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                    onPressed: () => Get.toNamed('/employeeDashboard'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Obx(() {
              // Must read observable so Obx can track and rebuild
              final clients = controller.clients;
              return SizedBox(
                width: double.infinity,
                child: DynamicDropdown(
                  items:
                      clients
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text('${v.name}'),
                            ),
                          )
                          .toList(),
                  value:
                      controller.clientController.text.isEmpty
                          ? null
                          : clients.firstWhere(
                            (a) => a.id == controller.clientController.text,
                          ),
                  label: 'chooseclient'.tr,
                  borderRadius: 5,
                  borderColor: Colors.grey.shade300,
                  height: 42,
                  fillColor: Colors.white,
                  onChanged: (value) {
                    if (value != null) {
                      controller.clientController.text = (value).id ?? '';
                      controller.refreshFilteredContents();
                    }
                  },
                  validator: (v) => v == null ? ' ' : null,
                ),
              );
            }),
            const SizedBox(height: 16),
            GetX<HomeController>(
              builder: (c) {
                final contents = c.searchedContents.toList();
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
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: contents.length,
                  itemBuilder: (_, i) {
                    final content = contents[i];
                    return ContentStatusCard(
                      index: i,
                      model: content,
                      onTap:
                          () =>
                              showContentDialogDetails(context, task: content),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildAttachmentPreviewTile(String url) {
  final bool isImage = getFileType(url) == 'image';
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child:
        isImage
            ? Image.network(
              url,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => _attachmentPlaceholderThumbnail(
                    Icons.broken_image_outlined,
                  ),
            )
            : _attachmentPlaceholderThumbnail(Icons.link_outlined),
  );
}

Widget _attachmentPlaceholderThumbnail(IconData icon) {
  return Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: Colors.blueGrey.shade100,
      border: Border.all(color: Colors.blueGrey.shade200),
    ),
    child: Icon(icon, size: 22, color: Colors.blueGrey.shade700),
  );
}

Widget _buildFormAttachmentThumbnail(String url) {
  final isImage = getFileType(url) == 'image';
  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade100,
      ),
      child:
          isImage
              ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => _attachmentPlaceholderThumbnail(
                      Icons.broken_image_outlined,
                    ),
              )
              : _attachmentPlaceholderThumbnail(Icons.link_outlined),
    ),
  );
}

Uri _normalizeAttachmentUri(String rawUrl) {
  final trimmed = rawUrl.trim();
  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme) {
    return parsed;
  }
  return Uri.parse('https://$trimmed');
}

Future<void> _openAttachmentUrl(String rawUrl) async {
  try {
    final uri = _normalizeAttachmentUri(rawUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {
    // Ignore errors and show user-friendly feedback instead of throwing.
  }

  FunHelper.showSnackbar(
    'validation.title'.tr,
    'errors.cannot_open_link'.tr,
    snackPosition: SnackPosition.TOP,
    backgroundColor: Colors.orange,
    colorText: Colors.white,
  );
}

void showAddContentDialog(
  BuildContext context, {
  ContentModel? model,
  required String clientId,
  bool? view,
}) {
  final titleController = TextEditingController(text: model?.title);
  RxList platforms = (model?.platform ?? []).obs;

  final contentTypeController = TextEditingController(text: model?.contentType);
  final executorController = TextEditingController(text: model?.executor);
  final notesController = TextEditingController(text: model?.clientNotes);
  final filecontroller = TextEditingController();

  final publishDatectr = TextEditingController(
    text: FunHelper.formatdate(model?.publishDate),
  );
  DateTime? publishDate = model?.publishDate;
  // String selectedRole = model?.role ?? "media_buyer";
  // List<String> roles = ["media_buyer", "designer", "developer", "manager"];
  var _key = GlobalKey<FormState>();
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GetBuilder<HomeController>(
          builder: (controller) {
            return Form(
              key: _key,
              child: SizedBox(
                width: Get.width * 0.7,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        margin: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Color(0xFF5C5589),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SvgPicture.asset('assets/svgs/icon_check_circle.svg'),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'addcontent'.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'addcontenthint'.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            SizedBox(
                              width: (Get.width * 0.7) - 30,
                              child: InputText(
                                labelText: 'title'.tr,
                                hintText: 'entertitle'.tr,
                                height: 42,
                                fillColor: Colors.white,
                                controller: titleController,

                                validator: (_) => null,

                                borderRadius: 5,
                                borderColor: Colors.grey.shade300,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: (Get.width * 0.7 / 2) - 30,
                                  child: InputText(
                                    onTap: () async {
                                      final picked = await customDatePicker(
                                        context,
                                      );
                                      if (picked != null) {
                                        publishDate = picked;
                                        publishDatectr.text = DateFormat(
                                          'dd MM yyyy - hh:mm a',
                                        ).format(picked.toLocal());
                                      }
                                    },
                                    labelText: 'publish_date'.tr,
                                    hintText: '1/10/2025'.tr,
                                    height: 42,
                                    fillColor: Colors.white,
                                    textInputType: TextInputType.datetime,
                                    controller: publishDatectr,
                                    readOnly: true,
                                    validator: (_) => null,
                                    suffixIcon: Icon(
                                      CupertinoIcons.calendar,
                                      color: Colors.grey,
                                    ),
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                  ),
                                ),

                                SizedBox(
                                  width: (Get.width * 0.7 / 2) - 30,

                                  child: DynamicDropdown(
                                    items:
                                        controller.employees
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(
                                                  '${v.name} (${v.role})',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        executorController.text.isEmpty
                                            ? null
                                            : controller.employees.firstWhere(
                                              (a) =>
                                                  a.id ==
                                                  executorController.text,
                                            ),
                                    label: 'content_provider'.tr,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
                                    onChanged: (value) {
                                      if (value != null) {
                                        executorController.text =
                                            (value).id ?? '';
                                      }
                                    },

                                    validator: (_) => null,
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: (Get.width * 0.7 / 2) - 30,

                                  child: DynamicDropdown(
                                    items:
                                        StorageKeys.contentsTypeList
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(v.tr),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        contentTypeController.text.isEmpty
                                            ? null
                                            : contentTypeController.text,
                                    label: 'choosecontenttype'.tr,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
                                    onChanged: (value) {
                                      if (value != null) {
                                        contentTypeController.text = value;
                                      }
                                    },

                                    validator: (_) => null,
                                  ),
                                ),
                                Obx(
                                  () => SizedBox(
                                    width: (Get.width * 0.7 / 2) - 30,

                                    child: DynamicDropdownMultiSelect(
                                      items:
                                          StorageKeys.platformList
                                              .map((v) => v.tr)
                                              .toList(),
                                      selectedValues: List.from(platforms),
                                      label: 'platform'.tr,
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                      height: 42,
                                      fillColor: Colors.white,

                                      validator: (_) => null,
                                      onChanged: (value) {
                                        platforms.assignAll(value);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: (Get.width * 0.7 / 2) - 30,
                                  child: InputText(
                                    labelText: 'notes'.tr,
                                    hintText: 'enternotes'.tr,
                                    height: 100,
                                    fillColor: Colors.white,
                                    controller: notesController,
                                    expanded: true,

                                    // validator: (v) {
                                    //   if (v == null || v.isEmpty) {
                                    //     return ' ';
                                    //   }
                                    //   return null;
                                    // },
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                  ),
                                ),
                                Obx(
                                  () => Column(
                                    children: [
                                      SizedBox(
                                        width: (Get.width * 0.7 / 2) - 30,

                                        child: InputText(
                                          labelText:
                                              'content.form.insert_link'.tr,
                                          hintText: 'googledrivelink .com'.tr,
                                          height: 40,
                                          fillColor: Colors.white,
                                          validator: (_) => null,
                                          controller: filecontroller,
                                          suffixIcon: Container(
                                            width: 80,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              color: Colors.grey.shade200,
                                            ),
                                            // padding: EdgeInsets.only(left: 10),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Copy',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(width: 5),
                                                Icon(
                                                  Icons.copy_rounded,
                                                  weight: 1,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            ),
                                          ),
                                          borderRadius: 5,
                                          borderColor: Colors.grey.shade300,
                                        ),
                                      ),
                                      SizedBox(
                                        width: (Get.width * 0.7 / 2) - 30,
                                        child: GestureDetector(
                                          onTap: () async {
                                            final files =
                                                await controller
                                                    .pickMultiFiles();
                                            for (var file in files) {
                                              controller.uploadFiles(
                                                filePathOrBytes: file.bytes!,
                                                fileName: file.name,
                                              );
                                            }
                                          },
                                          child: InputText(
                                            labelText: 'dragfile'.tr,
                                            hintText: ''.tr,
                                            validator: (_) => null,
                                            enable: false,
                                            height: 100,
                                            fillColor: Colors.white,
                                            // controller: notesController,
                                            expanded: true,

                                            body: Container(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Container(
                                                    margin:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                    child: Text(
                                                      'dragfile'.tr,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  MainButton(
                                                    width: 100,
                                                    borderSize: 5,
                                                    height: 30,
                                                    fontSize: 12,
                                                    load:
                                                        controller
                                                            .isUploading
                                                            .value,
                                                    title: 'uploadfile'.tr,
                                                    backgroundColor:
                                                        Colors.white,
                                                    fontColor:
                                                        AppColors
                                                            .primaryfontColor,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            borderRadius: 5,
                                            borderColor: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),

                                      SizedBox(
                                        width: (Get.width * 0.7 / 2) - 30,
                                        child: Obx(() {
                                          final files =
                                              controller.uploadedFilesPaths
                                                  .toList();
                                          if (files.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: files.length,
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 2,
                                                  crossAxisSpacing: 10,
                                                  mainAxisSpacing: 10,
                                                  childAspectRatio: 1,
                                                ),
                                            itemBuilder: (context, index) {
                                              final filePath = files[index];
                                              return InkWell(
                                                onTap: () async {
                                                  await _openAttachmentUrl(
                                                    filePath,
                                                  );
                                                },
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child:
                                                          _buildFormAttachmentThumbnail(
                                                            filePath,
                                                          ),
                                                    ),
                                                    Positioned(
                                                      top: 6,
                                                      right: 6,
                                                      child: InkWell(
                                                        onTap: () {
                                                          controller
                                                              .uploadedFilesPaths
                                                              .remove(filePath);
                                                        },
                                                        child: Container(
                                                          width: 24,
                                                          height: 24,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                Colors.black54,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          child: const Icon(
                                                            Icons.close,
                                                            color: Colors.white,
                                                            size: 15,
                                                          ),
                                                        ),
                                                      ),
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
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Actions
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (view != true)
                              Obx(
                                () => SizedBox(
                                  width: Get.width * 0.4 - 260,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF5C5589),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 48,
                                        vertical: 20,
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (_key.currentState!.validate()) {
                                        if (model == null) {
                                          await controller
                                              .addContent(
                                                ContentModel(
                                                  title: titleController.text,
                                                  files: [
                                                    ...controller
                                                        .uploadedFilesPaths,
                                                    ...filecontroller
                                                            .text
                                                            .isEmpty
                                                        ? []
                                                        : [
                                                          filecontroller.text
                                                              .trim(),
                                                        ], // الملفات الجديدة
                                                  ],
                                                  platform: platforms,
                                                  publishDate: publishDate,

                                                  contentType:
                                                      contentTypeController
                                                          .text,
                                                  executor:
                                                      executorController.text,
                                                  clientId: clientId,
                                                  status:
                                                      StorageKeys
                                                          .status_under_revision,
                                                  promotion: 'no_promotion',
                                                  // publishDate: publishDate,
                                                  createdAt: DateTime.now(),
                                                  notes: notesController.text,
                                                ),
                                              )
                                              .then((v) async {
                                                if (v) {
                                                  controller
                                                      .refreshFilteredContents();
                                                  Get.back();

                                                  await NotificationService.notifyClientContentPendingApproval(
                                                    clientId: clientId,
                                                    contentTypeLabel:
                                                        'content.notify.design_video_new'
                                                            .tr,
                                                  );
                                                  final clientName =
                                                      controller.clients
                                                          .firstWhereOrNull(
                                                            (c) =>
                                                                c.id ==
                                                                clientId,
                                                          )
                                                          ?.name ??
                                                      clientId;
                                                  await NotificationService.notifyManagersContentSubmittedByClient(
                                                    clientName: clientName,
                                                    contentTitle:
                                                        titleController.text,
                                                  );
                                                }
                                              });
                                        } else {
                                          controller
                                              .updateContent(
                                                model.copyWith(
                                                  title: titleController.text,

                                                  files: [
                                                    // الملفات القديمة (لو موجودة)
                                                    ...controller
                                                        .uploadedFilesPaths,
                                                    ...filecontroller
                                                            .text
                                                            .isEmpty
                                                        ? []
                                                        : [
                                                          filecontroller.text
                                                              .trim(),
                                                        ], // الملفات الجديدة
                                                  ],
                                                  platform: platforms,
                                                  publishDate: publishDate,
                                                  contentType:
                                                      contentTypeController
                                                          .text,
                                                  executor:
                                                      executorController.text,
                                                  clientId: clientId,
                                                  status:
                                                      StorageKeys
                                                          .status_under_revision,

                                                  notes: notesController.text,
                                                ),
                                              )
                                              .then((v) async {
                                                if (v) {
                                                  controller
                                                      .refreshFilteredContents();
                                                  Get.back();

                                                  await NotificationService.notifyClientContentUpdatedForApproval(
                                                    clientId: clientId,
                                                    contentTitle:
                                                        titleController.text,
                                                  );
                                                }
                                              });
                                        }
                                      }
                                    },
                                    child:
                                        controller.isLoading.value
                                            ? Center(
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                              ),
                                            )
                                            : Text(
                                              'common.save'.tr,
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                            SizedBox(width: 20),
                            SizedBox(
                              width: 160,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 20,
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text('common.cancel'.tr),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

// Future<DateTime?> customDatePicker(BuildContext context) async {
//   DateTime selectedDate = DateTime.now();

//   await showDialog(
//     context: context,
//     builder: (context) {
//       return AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         // title: const Text("اختر التاريخ"),
//         content: SizedBox(
//           height: 400,
//           width: 350,
//           child: CalendarDatePicker(
//             initialDate: DateTime.now(),
//             firstDate: DateTime(2000),
//             lastDate: DateTime(2100),
//             onDateChanged: (date) {
//               selectedDate = date;
//             },
//           ),
//         ),
//         actions: [
//           SizedBox(
//             width: 160,
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Color(0xFF5C5589),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(24),
//                 ),
//                 padding: EdgeInsets.symmetric(horizontal: 48, vertical: 20),
//               ),
//               onPressed: () {
//                 Navigator.pop(context, selectedDate);
//               },
//               child: Text("تأكيد", style: TextStyle(color: Colors.white)),
//             ),
//           ),
//           SizedBox(
//             width: 160,
//             child: OutlinedButton(
//               style: OutlinedButton.styleFrom(
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(24),
//                 ),
//                 padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
//               ),
//               onPressed: () => Navigator.pop(context),
//               child: Text('common.cancel'.tr),
//             ),
//           ),
//         ],
//       );
//     },
//   ).then((pickedDate) {
//     if (pickedDate != null) {
//       log("✅ Selected: $pickedDate");
//     } else {
//       log("❌ Cancelled");
//     }
//   });
//   return null;
// }
