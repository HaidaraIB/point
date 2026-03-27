import 'dart:developer';
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
import 'package:point/View/History/HistoryMobile.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart' show getFileType;
import 'package:point/View/Shared/ContentStatusPromotionDropdownChip.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/HorizontalScroll.dart';
import 'package:point/View/Shared/TableCellCenter.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/t.dart';
import 'package:url_launcher/url_launcher.dart';

class History extends StatelessWidget {
  List<String> extractMonthsAndYears(List<ContentModel> contents) {
    // فلترة العناصر اللي ليها publishDate
    final dates =
        contents
            .where((c) => c.publishDate != null)
            .map((c) => c.publishDate!)
            .toList();

    if (dates.isEmpty) return [];

    // اول تاريخ نشر
    final first = dates.reduce((a, b) => a.isBefore(b) ? a : b);

    // اخر تاريخ نشر
    final last = dates.reduce((a, b) => a.isAfter(b) ? a : b);

    // تجميع الشهور بين أول وآخر تاريخ
    final List<String> result = [];

    DateTime current = DateTime(first.year, first.month);

    while (current.isBefore(DateTime(last.year, last.month + 1))) {
      final formatted =
          "${current.year}-${current.month.toString().padLeft(2, '0')}";
      result.add(formatted);

      // move to next month
      current = DateTime(current.year, current.month + 1);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      selectedTab: 7,
      sideMenu:
          Get.find<HomeController>().currentemployee.value?.role != 'employee'
              ? true
              : false,

      body: GetBuilder<HomeController>(
        builder: (controller) {
          final months = extractMonthsAndYears(controller.contents);

          return Responsive(
            mobile: buildMobileHistory(context, controller, months),
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
                              'settings'.tr,
                              style: TextStyle(
                                color: AppColors.fontColorGrey,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                          ],
                        ),

                        Obx(
                          () => SizedBox(
                            width: (Get.width * 0.7 / 2) - 20,
                            child: DynamicDropdown(
                              items:
                                  controller.clients
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
                                      : controller.clients.firstWhere(
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
                                  controller.searchedContents.assignAll(
                                    List.from(
                                      controller.contents.where(
                                        (a) => a.clientId == (value).id,
                                      ),
                                    ),
                                  );
                                  controller.selectedDate.value = '';

                                  controller.clientController.text =
                                      (value).id ?? '';
                                  controller.update();
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
                          ),
                        ),
                        if (controller.clientController.text.isNotEmpty)
                          Obx(
                            () => SizedBox(
                              width: (Get.width * 0.7 / 2) - 20,
                              child: DynamicDropdown(
                                items:
                                    months
                                        .map(
                                          (v) => DropdownMenuItem(
                                            value: v,
                                            child: Text('${v}'),
                                          ),
                                        )
                                        .toList(),
                                value:
                                    controller.selectedDate.value.isEmpty
                                        ? null
                                        : controller.selectedDate.value,
                                label: 'common.select_date'.tr,
                                borderRadius: 5,
                                borderColor: Colors.grey.shade300,
                                height: 42,
                                fillColor: Colors.white,
                                onChanged: (value) {
                                  if (value != null) {
                                    final date = value;

                                    final parts = date.split('-');
                                    final year = int.parse(parts[0]);
                                    final month = int.parse(parts[1]);

                                    print(year); // 2024
                                    print(month); // 1

                                    controller.searchedContents.assignAll(
                                      List.from(
                                        controller.contents.where(
                                          (a) =>
                                              (a.clientId ==
                                                      controller
                                                          .clientController
                                                          .text &&
                                                  (a.publishDate?.month ==
                                                          month &&
                                                      a.publishDate?.year ==
                                                          year)),
                                        ),
                                      ),
                                    );

                                    // controller.clientController.text =
                                    //     (value as ClientModel).id ?? '';
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
                            ),
                          ),
                        SizedBox(height: 10),
                        HorizontalScrollbarTable(
                          child: SizedBox(
                            width: 2000,
                            child: Obx(
                              () => DataTable(
                                dataRowMinHeight: 60,
                                dataRowMaxHeight: 60,
                                dataRowColor: WidgetStateProperty.all(
                                  Colors.white,
                                ),
                                dividerThickness: 0.5,
                                columns: [
                                  DataColumn(
                                    columnWidth: const FixedColumnWidth(180),
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
                                    columnWidth: const FixedColumnWidth(180),
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
                                    columnWidth: const FixedColumnWidth(160),
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
                                    columnWidth: const FixedColumnWidth(180),
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
                                    columnWidth: const FixedColumnWidth(210),
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
                                    columnWidth: const FixedColumnWidth(210),
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
                                    columnWidth: const FixedColumnWidth(180),
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
                                    columnWidth: const FixedColumnWidth(160),
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
                                    columnWidth: const FixedColumnWidth(160),
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
                                    columnWidth: const FixedColumnWidth(180),
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
                                    columnWidth: const FixedColumnWidth(160),
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
                                    controller.searchedContents.map((emp) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            TableCellCenter(
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  maxWidth:
                                                      (Get.width - 280) / 9,
                                                ),
                                                child: Text(
                                                  emp.title,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.fontColorGrey,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TableCellCenter(
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  maxWidth:
                                                      (Get.width - 280) / 9,
                                                ),
                                                child: Text(
                                                  emp.platform.toString(),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.fontColorGrey,
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
                                                  color: Colors.purple.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  emp.contentType.tr,
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      // vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.blueGrey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  controller
                                                          .getEmployeeById(
                                                            emp.executor,
                                                          )
                                                          ?.name ??
                                                      '',
                                                  textAlign: TextAlign.center,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.blueGrey,
                                                    fontWeight: FontWeight.bold,
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
                                                  final actionKey = GlobalKey();
                                                  return GestureDetector(
                                                    key: actionKey,
                                                    onTap: () {
                                                      final RenderBox
                                                      renderBox =
                                                          actionKey
                                                                  .currentContext!
                                                                  .findRenderObject()
                                                              as RenderBox;

                                                      final Offset offset =
                                                          renderBox
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
                                                                .map((stat) {
                                                                  return PopupMenuItem(
                                                                    child: Text(
                                                                      stat.tr,
                                                                    ),
                                                                    value: stat,
                                                                  );
                                                                })
                                                                .toList(),
                                                      ).then((value) async {
                                                        if (value != null) {
                                                          await controller
                                                              .updateContent(
                                                                emp.copyWith(
                                                                  status: value,
                                                                ),
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
                                                          controller.searchedContents.assignAll(
                                                            List.from(
                                                              controller.contents.where(
                                                                (a) =>
                                                                    a.clientId ==
                                                                    controller
                                                                        .clientController
                                                                        .text,
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      });
                                                    },
                                                    child: buildContentDropdownChip(
                                                      label: emp.status.tr,
                                                      textColor:
                                                          getContentStatusColor(
                                                            emp.status,
                                                          ),
                                                      backgroundColor:
                                                          getContentStatusBgColor(
                                                            emp.status,
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
                                                  final actionKey = GlobalKey();
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
                                                          !StorageKeys.matchesDepartment(
                                                            controller
                                                                .currentemployee
                                                                .value
                                                                ?.department,
                                                            StorageKeys
                                                                .departmentPromotion,
                                                          )) {
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

                                                      final Offset offset =
                                                          renderBox
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
                                                                .map((stat) {
                                                                  return PopupMenuItem(
                                                                    child: Text(
                                                                      stat.tr,
                                                                    ),
                                                                    value: stat,
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
                                                          controller.searchedContents.assignAll(
                                                            List.from(
                                                              controller.contents.where(
                                                                (a) =>
                                                                    a.clientId ==
                                                                    controller
                                                                        .clientController
                                                                        .text,
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      });
                                                    },
                                                    child: buildContentDropdownChip(
                                                      label:
                                                          emp.promotion?.tr ??
                                                          '--',
                                                      textColor:
                                                          getContentPromotionColor(
                                                            emp.promotion,
                                                          ),
                                                      backgroundColor:
                                                          getContentPromotionBgColor(
                                                            emp.promotion,
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
                                                  maxWidth:
                                                      (Get.width - 280) / 9,
                                                ),
                                                child: Column(
                                                  children: [
                                                    for (var file
                                                        in emp.files ?? [])
                                                      InkWell(
                                                        onTap: () async {
                                                          if (getFileType(
                                                                file.toString(),
                                                              ) ==
                                                              'image') {
                                                            Get.dialog(
                                                              AlertDialog(
                                                                actions: [
                                                                  MainButton(
                                                                    icon: false,
                                                                    title:
                                                                        'app.close'
                                                                            .tr,
                                                                    fontColor:
                                                                        Colors
                                                                            .white,
                                                                    backgroundColor:
                                                                        AppColors
                                                                            .primary,
                                                                    width: 100,
                                                                    borderSize:
                                                                        5,
                                                                    height: 30,
                                                                    onPressed: () {
                                                                      Get.back();
                                                                    },
                                                                  ),
                                                                ],
                                                                content:
                                                                    Image.network(
                                                                      file,
                                                                      fit:
                                                                          BoxFit
                                                                              .contain,
                                                                    ),
                                                              ),
                                                            );
                                                            return;
                                                          }
                                                          if (await canLaunchUrl(
                                                            Uri.parse(file),
                                                          )) {
                                                            await launchUrl(
                                                              Uri.parse(file),
                                                              mode:
                                                                  LaunchMode
                                                                      .externalApplication,
                                                            );
                                                          } else {
                                                            FunHelper.showSnackbar(
                                                              'error'.tr,
                                                              'errors.cannot_open_link_param'
                                                                  .trParams({
                                                                    'url': file,
                                                                  }),
                                                            );
                                                            return;
                                                          }
                                                        },
                                                        child: Text(
                                                          file ?? '--',
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,

                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                            color: Colors.blue,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TableCellCenter(
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  maxWidth:
                                                      (Get.width - 280) / 9,
                                                ),
                                                child: Text(
                                                  emp.clientNotes ?? '--',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.fontColorGrey,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TableCellCenter(
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  maxWidth:
                                                      (Get.width - 280) / 9,
                                                ),
                                                child: Text(
                                                  FunHelper.formatdate(
                                                        emp.publishDate,
                                                      ) ??
                                                      '--',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.fontColorGrey,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TableCellCenter(
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  maxWidth:
                                                      (Get.width - 280) / 9,
                                                ),
                                                child: Column(
                                                  children: [
                                                    for (var file
                                                        in emp.clientEdits ??
                                                            [])
                                                      InkWell(
                                                        onTap: () async {
                                                          if (getFileType(
                                                                file.toString(),
                                                              ) ==
                                                              'image') {
                                                            Get.dialog(
                                                              AlertDialog(
                                                                actions: [
                                                                  MainButton(
                                                                    icon: false,
                                                                    title:
                                                                        'app.close'
                                                                            .tr,
                                                                    fontColor:
                                                                        Colors
                                                                            .white,
                                                                    backgroundColor:
                                                                        AppColors
                                                                            .primary,
                                                                    width: 100,
                                                                    borderSize:
                                                                        5,
                                                                    height: 30,
                                                                    onPressed: () {
                                                                      Get.back();
                                                                    },
                                                                  ),
                                                                ],
                                                                content:
                                                                    Image.network(
                                                                      file,
                                                                      fit:
                                                                          BoxFit
                                                                              .contain,
                                                                    ),
                                                              ),
                                                            );
                                                            return;
                                                          }
                                                          if (await canLaunchUrl(
                                                            Uri.parse(file),
                                                          )) {
                                                            await launchUrl(
                                                              Uri.parse(file),
                                                              mode:
                                                                  LaunchMode
                                                                      .externalApplication,
                                                            );
                                                          } else {
                                                            FunHelper.showSnackbar(
                                                              'error'.tr,
                                                              'errors.cannot_open_link_param'
                                                                  .trParams({
                                                                    'url': file,
                                                                  }),
                                                            );
                                                            return;
                                                          }
                                                        },
                                                        child: Text(
                                                          file ?? '--',
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,

                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                            color: Colors.blue,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TableCellCenter(
                                              child: SizedBox(
                                                child: PopupMenuButton<int>(
                                                  padding: EdgeInsets.zero,
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
                                                                  vertical: 5,
                                                                ),
                                                            child: Row(
                                                              children: [
                                                                Text(
                                                                  'edit'.tr,
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  width: 5,
                                                                ),
                                                                Icon(
                                                                  Icons.edit,
                                                                  color:
                                                                      Colors
                                                                          .green,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        if (controller
                                                                    .currentemployee
                                                                    .value
                                                                    ?.role ==
                                                                'supervisor' ||
                                                            controller
                                                                    .currentemployee
                                                                    .value
                                                                    ?.role ==
                                                                'admin' ||
                                                            controller
                                                                    .currentemployee
                                                                    .value
                                                                    ?.role ==
                                                                'accountholder')
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
                                                                    vertical: 5,
                                                                  ),

                                                              child: Row(
                                                                children: [
                                                                  Text(
                                                                    'delete'.tr,
                                                                    style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 5,
                                                                  ),
                                                                  Icon(
                                                                    Icons
                                                                        .delete,
                                                                    color:
                                                                        Colors
                                                                            .red,
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
                                                            emp.files ?? [],
                                                          );
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
                                                              .deleteContent(
                                                                emp.id!,
                                                              );
                                                        },
                                                      );
                                                    }
                                                  },
                                                  child: Icon(Icons.more_vert),
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

                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return ' ';
                                  }
                                  return null;
                                },

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
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return ' ';
                                      return null;
                                    },
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

                                    validator: (v) {
                                      if (v == null) {
                                        return ' ';
                                      }
                                      return null;
                                    },
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

                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return ' ';
                                      }
                                      return null;
                                    },
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

                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return ' ';
                                        }
                                        return null;
                                      },
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

                                          controller: filecontroller,
                                          suffixIcon: Container(
                                            width: 80,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              color: Colors.grey.shade200,
                                            ),
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
                                            validator: (v) {
                                              if (controller
                                                  .uploadedFilesPaths
                                                  .isEmpty) {
                                                return ' ';
                                              }
                                              return null;
                                            },
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
                                        child: Obx(
                                          () => Column(
                                            children: [
                                              for (var filePath
                                                  in controller
                                                      .uploadedFilesPaths)
                                                Row(
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        controller
                                                            .uploadedFilesPaths
                                                            .remove(filePath);
                                                      },
                                                      child: Icon(
                                                        Icons.cancel,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                    SizedBox(width: 5),
                                                    InkWell(
                                                      onTap: () async {
                                                        if (await canLaunchUrl(
                                                          Uri.parse(filePath),
                                                        )) {
                                                          await launchUrl(
                                                            Uri.parse(filePath),
                                                            mode:
                                                                LaunchMode
                                                                    .externalApplication,
                                                          );
                                                        } else {
                                                          FunHelper.showSnackbar(
                                                            'error'.tr,
                                                            'errors.cannot_open_link_param'
                                                                .trParams({
                                                                  'url':
                                                                      filePath,
                                                                }),
                                                          );
                                                        }
                                                      },
                                                      child: Text(
                                                        FunHelper.getFileNameFromUrl(
                                                          filePath,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.blue,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
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
                                                  controller.searchedContents.assignAll(
                                                    List.from(
                                                      controller.contents.where(
                                                        (a) =>
                                                            a.clientId ==
                                                            controller
                                                                .clientController
                                                                .text,
                                                      ),
                                                    ),
                                                  );
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
                                                  controller.searchedContents.assignAll(
                                                    List.from(
                                                      controller.contents.where(
                                                        (a) =>
                                                            a.clientId ==
                                                            controller
                                                                .clientController
                                                                .text,
                                                      ),
                                                    ),
                                                  );
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
