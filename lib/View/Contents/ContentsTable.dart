import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/Utils/ContentPermissions.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Contents/ContentDialogDetails.dart';
import 'package:point/View/Contents/Mobile/ContentFormMobilePage.dart';
import 'package:point/View/EmployeeDashboard/EmployeeContentDashboard.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/ContentStatusPromotionDropdownChip.dart';
import 'package:point/View/Shared/HorizontalScroll.dart';
import 'package:point/View/Shared/TableCellCenter.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/t.dart';
import 'package:url_launcher/url_launcher.dart';

part 'contents_table_employee_web_part.dart';
part 'contents_table_desktop_data_table_part.dart';
part 'contents_table_mobile_part.dart';
part 'contents_table_add_content_dialog_part.dart';

class ContentsTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().currentEmployee.value;
    if (_useEmployeeContentDashboard(emp)) {
      return const EmployeeContentDashboard();
    }
    final employeeWebDesktopShell =
        kIsWeb &&
        _isWebPublishingOrPromotionEmployee(emp) &&
        !Responsive.isMobile(context);
    if (employeeWebDesktopShell) {
      return const _EmployeeWebDesktopContentShell();
    }
    return ResponsiveScaffold(
      selectedTab: 3,
      sideMenu:
          emp?.role != 'employee' || _isWebPublishingOrPromotionEmployee(emp),

      body: GetBuilder<HomeController>(
        builder: (controller) {
          final webPubPromo =
              kIsWeb &&
              _isWebPublishingOrPromotionEmployee(
                controller.currentEmployee.value,
              );
          return Responsive(
            mobileBreakpoint: webPubPromo ? 600 : 850,
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
                            Obx(() {
                              if (!ContentPermissions.canAddOrEditContent(
                                controller.currentEmployee.value,
                              )) {
                                return const SizedBox.shrink();
                              }
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MainButton(
                                    width: 180,
                                    height: 45,
                                    borderSize: 35,
                                    fontColor: Colors.white,
                                    backgroundColor: AppColors.primary,
                                    widget: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                      if (controller
                                          .clientController
                                          .text
                                          .isEmpty) {
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
                                        clientId:
                                            controller.clientController.text,
                                      );
                                    },
                                  ),
                                  SizedBox(width: 10),
                                ],
                              );
                            }),
                            if (StorageKeys.matchesDepartment(
                                  controller.currentEmployee.value?.department,
                                  StorageKeys.departmentPromotion,
                                ) ||
                                StorageKeys.matchesDepartment(
                                  controller.currentEmployee.value?.department,
                                  StorageKeys.departmentPublishing,
                                ))
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
                        _buildClientPickerRow(
                          controller,
                          fullWidth: false,
                          clearFiltersWhenClientChanges: false,
                        ),
                        SizedBox(height: 10),
                        _buildDesktopContentsDataTable(context),
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
