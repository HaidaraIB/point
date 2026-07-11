import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/table_actions_menu_row.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/app_theme_extension.dart';

bool _isEmployeeRecentlyOnline(DateTime? at) {
  if (at == null) return false;
  return DateTime.now().difference(at.toLocal()) <= const Duration(minutes: 2);
}

String _employeePresenceLabel(DateTime? at) {
  if (_isEmployeeRecentlyOnline(at)) return 'employees.online_now'.tr;
  if (at == null) return 'employees.last_seen_unknown'.tr;
  final when = FunHelper.formatTimeAgo(at.toLocal());
  return 'employees.last_seen_at'.trParams({'time': when});
}

class EmployeesMobileScreen extends StatelessWidget {
  final List<EmployeeModel> employees;
  final VoidCallback onAdd;
  final ValueChanged<EmployeeModel> onEdit;
  final ValueChanged<EmployeeModel> onDelete;
  /// حذف الموظفين مسموح لـ admin فقط (قواعد Firestore).
  final bool canDelete;
  /// لا يُعرض حذف صف المستخدم الحالي (لا يمكن للمسؤول حذف نفسه).
  final String? selfEmployeeId;

  const EmployeesMobileScreen({
    super.key,
    required this.employees,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.canDelete = false,
    this.selfEmployeeId,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    return RefreshIndicator(
      onRefresh: () async {
        Get.find<HomeController>().fetchEmployees();
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'employees'.tr,
                  style: TextStyle(
                    color: appTheme.secondaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              MainButton(
                width: 126,
                height: 44,
                margin: EdgeInsets.zero,
                borderSize: 28,
                fontColor: Colors.white,
                backgroundColor: AppColors.primary,
                widget: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'addnewwmployee'.tr,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                onPressed: onAdd,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (employees.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Text(
                  'history.empty_data'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    color: appTheme.secondaryText,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: employees.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final emp = employees[index];
                final lastSeenAt = Get.find<HomeController>().employeeLastSeenAt(
                  emp.id,
                );
                final isSelf =
                    selfEmployeeId != null &&
                    selfEmployeeId!.isNotEmpty &&
                    (emp.id ?? '') == selfEmployeeId;
                return Container(
                  decoration: BoxDecoration(
                    color: appTheme.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: appTheme.border),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              emp.name ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: appTheme.primaryText,
                              ),
                            ),
                          ),
                          PopupMenuButton<int>(
                            tooltip: 'tasks.options_tooltip'.tr,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: appTheme.cardSurface,
                            elevation: 4,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 0,
                                child: tableActionsMenuRow(
                                  label: 'edit'.tr,
                                  icon: Icons.edit_outlined,
                                  iconColor: AppColors.success,
                                ),
                              ),
                              if (canDelete && !isSelf)
                                PopupMenuItem(
                                  value: 1,
                                  child: tableActionsMenuRow(
                                    label: 'delete'.tr,
                                    icon: Icons.delete_outline,
                                    iconColor: AppColors.destructive,
                                  ),
                                ),
                            ],
                            onSelected: (value) {
                              if (value == 0) {
                                onEdit(emp);
                              } else if (canDelete && value == 1) {
                                onDelete(emp);
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: appTheme.unselected,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.more_vert,
                                color: appTheme.primaryText,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        emp.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: appTheme.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isEmployeeRecentlyOnline(lastSeenAt)
                                  ? const Color(0xFF4ADE80).withValues(alpha: 0.15)
                                  : context.appTheme.unselected,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _employeePresenceLabel(lastSeenAt),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _isEmployeeRecentlyOnline(lastSeenAt)
                                    ? const Color(0xFF4ADE80)
                                    : appTheme.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Container(
                        alignment: Alignment.center,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.appTheme.panelTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          emp.role == 'employee'
                              ? '${emp.role.tr}\n(${emp.departments.map((d) => StorageKeys.semanticDepartmentLabelKey(d).tr).join(', ')})'
                              : emp.role.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: appTheme.accentText,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ),
    );
  }
}
