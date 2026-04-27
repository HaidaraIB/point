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
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Contents/ContentDialogDetails.dart';
import 'package:point/View/Contents/Mobile/ContentFormMobilePage.dart';
import 'package:point/View/Contents/Shared/content_attachment_source_input.dart';
import 'package:point/View/Contents/Shared/content_library_attachment_picker.dart';
import 'package:point/View/EmployeeDashboard/EmployeeContentDashboard.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart';
import 'package:point/View/Publish/publish_add_dialog.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/app_date_time_picker.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/ContentStatusPromotionDropdownChip.dart';
import 'package:point/View/Shared/HorizontalScroll.dart';
import 'package:point/View/Shared/TableCellCenter.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/t.dart';

part 'contents_table_employee_web_part.dart';
part 'contents_table_desktop_data_table_part.dart';
part 'contents_table_mobile_part.dart';
part 'contents_table_add_content_dialog_part.dart';

void _confirmBulkDeleteContent(BuildContext context, HomeController controller) {
  final n = controller.selectedContentIds.length;
  if (n == 0) return;
  FunHelper.showConfirmDailog(
    context,
    title: 'content.bulk_delete_confirm_title'.tr,
    message: 'content.bulk_delete_confirm_message'.trParams({'count': '$n'}),
    confirmText: 'delete'.tr,
    confirmColor: Colors.red,
    onTap: () async {
      await controller.deleteSelectedContents();
    },
  );
}

/// Light outlined bulk action (same family as table status chips).
Widget _bulkActionChipButton({
  required String label,
  required Color accentColor,
  required IconData icon,
  required VoidCallback onPressed,
  bool expandWidth = false,
}) {
  final style = OutlinedButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    backgroundColor: accentColor.withValues(alpha: 0.08),
    foregroundColor: accentColor,
    side: BorderSide(color: accentColor.withValues(alpha: 0.28)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: expandWidth ? const Size.fromHeight(40) : const Size(0, 38),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
  final child = OutlinedButton.icon(
    style: style,
    icon: Icon(icon, size: 17),
    label: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
    ),
    onPressed: onPressed,
  );
  if (expandWidth) {
    return SizedBox(width: double.infinity, child: child);
  }
  return child;
}

/// Shared desktop bulk bar: Approve, Publish, Schedule — [ContentPermissions.canChangePostStatus];
/// Delete — [ContentPermissions.canDeleteContent].
Widget _bulkContentActionsControls(
  BuildContext context,
  HomeController controller, {
  required bool expandInParentRow,
}) {
  return Obx(() {
    final selectedCount = controller.selectedContentIds.length;
    if (selectedCount == 0) return const SizedBox.shrink();
    final emp = controller.currentEmployee.value;
    final canStatus = ContentPermissions.canChangePostStatus(emp);
    final canDel = ContentPermissions.canDeleteContent(emp);
    if (!canStatus && !canDel) return const SizedBox.shrink();
    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canStatus) ...[
            _bulkActionChipButton(
              label: '${'tasks.accept'.tr} ($selectedCount)',
              accentColor: AppColors.success,
              icon: Icons.check_circle_outline_rounded,
              onPressed: () async {
                await controller.approveSelectedContents();
              },
            ),
          ],
          if (canStatus && canDel) const SizedBox(width: 6),
          if (canDel)
            _bulkActionChipButton(
              label: '${'delete'.tr} ($selectedCount)',
              accentColor: AppColors.destructive,
              icon: Icons.delete_outline_rounded,
              onPressed: () {
                _confirmBulkDeleteContent(context, controller);
              },
            ),
        ],
      ),
    );
    if (expandInParentRow) {
      return Expanded(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: row,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: row,
      ),
    );
  });
}

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
                            if (controller.currentEmployee.value != null &&
                                (controller.currentEmployee.value!
                                        .hasDepartment(
                                          StorageKeys.departmentPromotion,
                                        ) ||
                                    controller.currentEmployee.value!
                                        .hasDepartment(
                                          StorageKeys.departmentPublishing,
                                        )))
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
                        _bulkContentActionsControls(
                          context,
                          controller,
                          expandInParentRow: false,
                        ),
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
