import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsEmployeeContractModel.dart';
import 'package:point/Models/Os/os_payroll_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Payroll/os_contract_form_dialog.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_list_filters.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/app_data_table.dart';

class OsContractsTab extends StatefulWidget {
  const OsContractsTab({super.key});

  @override
  State<OsContractsTab> createState() => _OsContractsTabState();
}

class _OsContractsTabState extends State<OsContractsTab> {
  final _search = TextEditingController();
  var _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<OsEmployeeContractModel> _filtered(List<OsEmployeeContractModel> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((c) {
      if (_status != 'ALL' && c.status != _status) return false;
      if (q.isEmpty) return true;
      return c.employeeName.toLowerCase().contains(q) ||
          c.type.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _delete(
    BuildContext context,
    OsPayrollController payroll,
    String id,
  ) async {
    final confirmed = await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: AppLocaleKeys.osContractsDeleteConfirm.tr,
      onTap: () => payroll.deleteContract(id),
    );
    if (confirmed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OsSnackbar.success(
          AppLocaleKeys.osContractsTitle.tr,
          AppLocaleKeys.osContractsDeleted.tr,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final payroll = Get.find<OsPayrollController>();

    return Obx(() {
      final all = payroll.contracts.toList();
      final items = _filtered(all);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsListFilterBar(
            chips: OsFilterChips(
              value: _status,
              onChanged: (v) => setState(() => _status = v),
              options: [
                OsFilterChipOption(
                  value: 'ALL',
                  label: AppLocaleKeys.osCommonFilterAll.tr,
                ),
                OsFilterChipOption(
                  value: OsEmployeeContractStatus.active,
                  label: AppLocaleKeys.osContractsStatusActive.tr,
                ),
                OsFilterChipOption(
                  value: OsEmployeeContractStatus.expired,
                  label: AppLocaleKeys.osContractsStatusExpired.tr,
                ),
              ],
            ),
            search: OsSearchField(
              controller: _search,
              hint: AppLocaleKeys.osContractsSearch.tr,
              onChanged: (_) => setState(() {}),
            ),
            actions: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => showOsContractFormDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocaleKeys.osContractsAdd.tr),
              ),
            ],
            matchCount: all.isEmpty ? null : items.length,
          ),
          Expanded(
            child: items.isEmpty
                ? OsEmptyState(
                    message: all.isEmpty
                        ? AppLocaleKeys.osContractsEmpty.tr
                        : AppLocaleKeys.osContractsEmptyFilter.tr,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: AppDataTable(
                      minWidth: 900,
                      columns: [
                        appDataColumn(
                          context,
                          AppLocaleKeys.osContractsColEmployee.tr,
                        ),
                        appDataColumn(
                          context,
                          AppLocaleKeys.osContractsColType.tr,
                        ),
                        appDataColumn(
                          context,
                          AppLocaleKeys.osContractsColEnd.tr,
                        ),
                        appDataColumn(
                          context,
                          AppLocaleKeys.osContractsColStatus.tr,
                        ),
                        appDataColumn(
                          context,
                          AppLocaleKeys.osContractsColActions.tr,
                          width: 88,
                        ),
                      ],
                      rows: [
                        for (final c in items)
                          DataRow(
                            cells: [
                              appDataCell(
                                Text(
                                  c.employeeName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ),
                              appDataCell(
                                Text(
                                  c.type,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ),
                              appDataCell(
                                Text(
                                  c.endDate,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ),
                              appDataCell(
                                _statusChip(
                                  theme,
                                  c.status == OsEmployeeContractStatus.active,
                                ),
                              ),
                              appDataCell(
                                IconButton(
                                  tooltip: AppLocaleKeys.osCommonDelete.tr,
                                  onPressed: c.id == null
                                      ? null
                                      : () => _delete(
                                            context,
                                            payroll,
                                            c.id!,
                                          ),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: theme.mutedText,
                                    size: 20,
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
      );
    });
  }

  Widget _statusChip(AppThemeExtension theme, bool active) {
    final color = active ? AppColors.success : theme.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        active
            ? AppLocaleKeys.osContractsStatusActive.tr
            : AppLocaleKeys.osContractsStatusExpired.tr,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
