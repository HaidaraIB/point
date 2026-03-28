import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/table_actions_menu_row.dart';

class EmployeesMobileScreen extends StatelessWidget {
  final List<EmployeeModel> employees;
  final VoidCallback onAdd;
  final ValueChanged<EmployeeModel> onEdit;
  final ValueChanged<EmployeeModel> onDelete;

  const EmployeesMobileScreen({
    super.key,
    required this.employees,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                    color: AppColors.fontColorGrey,
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
                          style: const TextStyle(
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
                    color: AppColors.fontColorGrey,
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
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
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
                                color: AppColors.fontColorGrey,
                              ),
                            ),
                          ),
                          PopupMenuButton<int>(
                            tooltip: 'tasks.options_tooltip'.tr,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: Colors.white,
                            elevation: 4,
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 0,
                                    child: tableActionsMenuRow(
                                      label: 'edit'.tr,
                                      icon: Icons.edit_outlined,
                                      iconColor: AppColors.success,
                                    ),
                                  ),
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
                              } else if (value == 1) {
                                onDelete(emp);
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.more_vert,
                                color: AppColors.primaryfontColor,
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
                          color: AppColors.fontColorGrey,
                          fontWeight: FontWeight.w600,
                        ),
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
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          emp.role == 'employee'
                              ? '${emp.role.tr}\n(${StorageKeys.semanticDepartmentLabelKey(emp.department).tr})'
                              : emp.role.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.purple,
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
    );
  }
}
