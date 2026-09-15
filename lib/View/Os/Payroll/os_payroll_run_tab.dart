import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/firestore/firestore_os_payroll_api.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Payroll/os_payroll_adjust_dialog.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_list_filters.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/app_data_table.dart';
import 'package:point/View/Shared/safe_network_image.dart';

class OsPayrollRunTab extends StatefulWidget {
  const OsPayrollRunTab({super.key});

  @override
  State<OsPayrollRunTab> createState() => _OsPayrollRunTabState();
}

class _OsPayrollRunTabState extends State<OsPayrollRunTab> {
  final _search = TextEditingController();
  var _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _branchLabel(String? branchId) {
    if (branchId == null || branchId.isEmpty) {
      return AppLocaleKeys.osCommonDash.tr;
    }
    if (Get.isRegistered<OsFinanceController>()) {
      final name = Get.find<OsFinanceController>().branchName(branchId);
      if (name.isNotEmpty) return name;
    }
    return branchId;
  }

  DateTime _periodDate(String period) {
    final now = DateTime.now();
    final parts = period.split('-');
    return DateTime(
      int.tryParse(parts.first) ?? now.year,
      int.tryParse(parts.length > 1 ? parts[1] : '') ?? now.month,
    );
  }

  String _periodLabel(String period) {
    try {
      final code = Get.locale?.languageCode ?? 'ar';
      return DateFormat.yMMMM(code).format(_periodDate(period));
    } catch (_) {
      return period;
    }
  }

  double _unpaidAmount({
    required Map<String, double> drafts,
    required String empId,
    required double? slipValue,
  }) {
    if (drafts.containsKey(empId)) return drafts[empId]!;
    return slipValue ?? 0;
  }

  Future<void> _pickPeriod(
    BuildContext context,
    OsPayrollController payroll,
    String period,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodDate(period),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: AppLocaleKeys.osPayrollPeriod.tr,
    );
    if (picked == null) return;
    payroll.selectedPeriod.value = FirestoreOsPayrollApi.currentPeriod(picked);
    await payroll.ensureCurrentRun();
  }

  Future<String?> _pickAccount(BuildContext context) async {
    if (!Get.isRegistered<OsFinanceController>()) {
      Get.put(OsFinanceController(), permanent: false);
    }
    final finance = Get.find<OsFinanceController>();
    final accounts = finance.bankAccounts.toList();
    if (accounts.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osPayrollTitle.tr,
        AppLocaleKeys.osPayrollErrorNoAccount.tr,
      );
      return null;
    }

    String? selected = accounts.first.id;
    final theme = context.appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Dialog(
              backgroundColor: theme.cardSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppLocaleKeys.osPayrollSelectAccount.tr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selected,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: theme.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(
                                  '${a.name} (${OsFinanceFormat.money(a.balance)})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setLocal(() => selected = v),
                      ),
                      const SizedBox(height: 20),
                      OsFormDialogActions(
                        saveLabel: AppLocaleKeys.osPayrollDisburse.tr,
                        onSave: () => Navigator.pop(ctx, true),
                        onCancel: () => Navigator.pop(ctx, false),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (confirmed != true) return null;
    return selected;
  }

  Future<void> _deleteCurrentRun(
    BuildContext context,
    OsPayrollController payroll,
    String period,
  ) async {
    final run = payroll.runForPeriod(period);
    final runId = run?.id;
    if (runId == null || runId.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osPayrollTitle.tr,
        AppLocaleKeys.osPayrollRunMissing.tr,
      );
      return;
    }
    final confirmed = await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: AppLocaleKeys.osPayrollRunDeleteConfirm.tr,
      onTap: () async {
        try {
          final ok = await payroll.deletePayrollRun(runId);
          if (!ok) {
            OsSnackbar.error(
              AppLocaleKeys.osPayrollTitle.tr,
              AppLocaleKeys.osCommonSaveFailed.tr,
            );
            throw Exception('delete failed');
          }
        } on OsPayrollException catch (e) {
          OsSnackbar.error(AppLocaleKeys.osPayrollTitle.tr, e.messageKey.tr);
          rethrow;
        }
      },
    );
    if (confirmed == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OsSnackbar.success(
          AppLocaleKeys.osPayrollTitle.tr,
          AppLocaleKeys.osPayrollRunDeleted.tr,
        );
      });
    }
  }

  Future<void> _pay(
    BuildContext context,
    OsPayrollController payroll,
    EmployeeModel emp,
  ) async {
    final accountId = await _pickAccount(context);
    if (accountId == null) return;

    try {
      final empId = emp.id ?? '';
      var slip = payroll.payslipForEmployee(payroll.selectedPeriod.value, empId);
      if (slip == null) {
        final generated = await payroll.generatePayslip(emp);
        if (!generated) {
          OsSnackbar.error(
            AppLocaleKeys.osPayrollTitle.tr,
            AppLocaleKeys.osCommonSaveFailed.tr,
          );
          return;
        }
        slip = payroll.payslipForEmployee(payroll.selectedPeriod.value, empId);
      }
      if (slip == null) {
        OsSnackbar.error(
          AppLocaleKeys.osPayrollTitle.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
        return;
      }
      final ok = await payroll.disbursePayslip(
        payslip: slip,
        bankAccountId: accountId,
      );
      if (ok) {
        OsSnackbar.success(
          AppLocaleKeys.osPayrollTitle.tr,
          AppLocaleKeys.osPayrollPaidSuccess.tr,
        );
      }
    } on OsPayrollException catch (e) {
      OsSnackbar.error(AppLocaleKeys.osPayrollTitle.tr, e.messageKey.tr);
    } catch (_) {
      OsSnackbar.error(AppLocaleKeys.osPayrollTitle.tr, 'error'.tr);
    }
  }

  String _payFilterKey(OsPayrollController payroll, String period, EmployeeModel emp) {
    final empId = emp.id ?? '';
    final basic = emp.salary ?? 0;
    if (basic <= 0) return 'NO_SALARY';
    final slip = payroll.payslipForEmployee(period, empId);
    if (slip?.isPaid == true) return 'PAID';
    return 'PENDING';
  }

  List<EmployeeModel> _filtered(
    OsPayrollController payroll,
    String period,
    List<EmployeeModel> all,
  ) {
    final q = _search.text.trim().toLowerCase();
    return all.where((emp) {
      final key = _payFilterKey(payroll, period, emp);
      if (_status != 'ALL' && key != _status) return false;
      if (q.isEmpty) return true;
      final name = (emp.name ?? '').toLowerCase();
      final role = (emp.jobTitle ?? '').toLowerCase();
      final branch = _branchLabel(emp.branchId).toLowerCase();
      return name.contains(q) || role.contains(q) || branch.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final payroll = Get.find<OsPayrollController>();

    return Obx(() {
      final period = payroll.selectedPeriod.value;
      final emps = payroll.employees
          .where((e) => (e.role).toLowerCase() != 'admin')
          .toList();
      final filtered = _filtered(payroll, period, emps);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsListFilterBar(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  style: OsButtonStyles.secondaryCompact(theme),
                  onPressed: () => _pickPeriod(context, payroll, period),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(
                    '${AppLocaleKeys.osPayrollPeriod.tr}: ${_periodLabel(period)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                if (payroll.runForPeriod(period)?.id != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _deleteCurrentRun(context, payroll, period),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF43F5E),
                      side: const BorderSide(color: Color(0xFFF43F5E)),
                      minimumSize: OsButtonStyles.compactMinSize,
                      padding: OsButtonStyles.compactPadding,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(AppLocaleKeys.osPayrollRunDelete.tr),
                  ),
              ],
            ),
            chips: OsFilterChips(
              value: _status,
              onChanged: (v) => setState(() => _status = v),
              options: [
                OsFilterChipOption(
                  value: 'ALL',
                  label: AppLocaleKeys.osCommonFilterAll.tr,
                ),
                OsFilterChipOption(
                  value: 'PENDING',
                  label: AppLocaleKeys.osPayrollFilterPending.tr,
                ),
                OsFilterChipOption(
                  value: 'PAID',
                  label: AppLocaleKeys.osPayrollFilterPaid.tr,
                ),
                OsFilterChipOption(
                  value: 'NO_SALARY',
                  label: AppLocaleKeys.osPayrollFilterNoSalary.tr,
                ),
              ],
            ),
            search: OsSearchField(
              controller: _search,
              hint: AppLocaleKeys.osPayrollSearch.tr,
              onChanged: (_) => setState(() {}),
            ),
            matchCount: emps.isEmpty ? null : filtered.length,
          ),
          if (emps.isEmpty)
            Expanded(
              child: OsEmptyState(
                message: AppLocaleKeys.osPayrollEmptyEmployees.tr,
              ),
            )
          else if (filtered.isEmpty)
            Expanded(
              child: OsEmptyState(
                message: AppLocaleKeys.osPayrollEmptyFilter.tr,
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AppDataTable(
                  minWidth: 1100,
                  dataRowMinHeight: 72,
                  dataRowMaxHeight: 88,
                  columns: [
                    appDataColumn(
                      context,
                      AppLocaleKeys.osPayrollColEmployee.tr,
                    ),
                    appDataColumn(
                      context,
                      AppLocaleKeys.osPayrollColBasic.tr,
                    ),
                    appDataColumn(
                      context,
                      AppLocaleKeys.osPayrollColAllowances.tr,
                    ),
                    appDataColumn(
                      context,
                      AppLocaleKeys.osPayrollColDeductions.tr,
                    ),
                    appDataColumn(
                      context,
                      AppLocaleKeys.osPayrollColNet.tr,
                    ),
                    appDataColumn(
                      context,
                      AppLocaleKeys.osPayrollColStatus.tr,
                      width: 260,
                    ),
                  ],
                  rows: [
                    for (final emp in filtered)
                      _row(context, theme, payroll, period, emp),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  DataRow _row(
    BuildContext context,
    AppThemeExtension theme,
    OsPayrollController payroll,
    String period,
    EmployeeModel emp,
  ) {
    final empId = emp.id ?? '';
    final OsPayslipModel? slip =
        payroll.payslipForEmployee(period, empId);
    final basic = emp.salary ?? 0;
    final isPaid = slip?.isPaid == true;
    final allowances = isPaid
        ? (slip?.allowances ?? 0)
        : _unpaidAmount(
            drafts: payroll.draftAllowances,
            empId: empId,
            slipValue: slip?.allowances,
          );
    final deductions = isPaid
        ? (slip?.deductions ?? 0)
        : _unpaidAmount(
            drafts: payroll.draftDeductions,
            empId: empId,
            slipValue: slip?.deductions,
          );
    final social = isPaid
        ? (slip?.socialSecurity ?? 0)
        : _unpaidAmount(
            drafts: payroll.draftSocialSecurity,
            empId: empId,
            slipValue: slip?.socialSecurity,
          );
    final advance = slip?.advanceDeduction ?? payroll.suggestedAdvanceFor(empId);
    final net = slip?.isPaid == true
        ? (slip?.netPay ?? 0)
        : FirestoreOsPayrollApi.computeNetPay(
            basicSalary: basic,
            allowances: allowances,
            deductions: deductions,
            socialSecurity: social,
            advanceDeduction: advance,
          );
    final canEdit = !isPaid && basic > 0;
    final role = emp.jobTitle?.trim().isNotEmpty == true
        ? emp.jobTitle!
        : AppLocaleKeys.osCommonDash.tr;
    final name = (emp.name ?? '').trim();

    return DataRow(
      cells: [
        appDataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.panelTint,
                  child: (emp.image ?? '').isNotEmpty
                      ? ClipOval(
                          child: SafeNetworkImage(
                            emp.image!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          name.isEmpty ? '?' : name.substring(0, 1),
                          style: TextStyle(
                            color: theme.accentText,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.secondaryText,
                      ),
                    ),
                    Text(
                      '$role • ${_branchLabel(emp.branchId)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        appDataCell(
          Text(
            OsFinanceFormat.money(basic),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.secondaryText,
            ),
          ),
        ),
        appDataCell(
          Text(
            OsFinanceFormat.money(allowances),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.secondaryText,
            ),
          ),
        ),
        appDataCell(
          Text(
            OsFinanceFormat.money(deductions),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.secondaryText,
            ),
          ),
        ),
        appDataCell(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                OsFinanceFormat.money(net),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: theme.accentText,
                ),
              ),
              if (advance > 0)
                Text(
                  '${AppLocaleKeys.osPayrollColAdvance.tr}: ${OsFinanceFormat.money(advance)}',
                  style: TextStyle(fontSize: 10, color: theme.mutedText),
                ),
            ],
          ),
        ),
        appDataCell(
          basic <= 0
              ? Text(
                  AppLocaleKeys.osPayrollNoSalary.tr,
                  style: const TextStyle(
                    color: AppColors.caution,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : isPaid
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppLocaleKeys.osPayrollDisbursedPosted.tr,
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.end,
                      children: [
                        if (canEdit)
                          FilledButton(
                            style: OsButtonStyles.secondaryCompact(theme),
                            onPressed: () =>
                                showOsPayrollAdjustDialog(context, emp),
                            child: Text(AppLocaleKeys.osPayrollAdjustEdit.tr),
                          ),
                        FilledButton(
                          style: OsButtonStyles.primaryCompact(),
                          onPressed: payroll.isLoading.value
                              ? null
                              : () => _pay(context, payroll, emp),
                          child: Text(AppLocaleKeys.osPayrollDisburse.tr),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}
