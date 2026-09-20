import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/firestore/firestore_os_payroll_api.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Payroll/os_payslip_print.dart';
import 'package:point/View/Os/Payroll/os_payslip_print_text.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsPayslipsTab extends StatefulWidget {
  const OsPayslipsTab({super.key, this.compact = false});

  final bool compact;

  @override
  State<OsPayslipsTab> createState() => _OsPayslipsTabState();
}

class _OsPayslipsTabState extends State<OsPayslipsTab> {
  String? _employeeId;
  var _copied = false;

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

  List<EmployeeModel> _employees(OsPayrollController payroll) {
    return payroll.employees
        .where((e) => (e.id ?? '').isNotEmpty && e.role.toLowerCase() != 'admin')
        .toList();
  }

  void _ensureEmployeeSelection(List<EmployeeModel> emps) {
    final ids = emps.map((e) => e.id!).toList();
    if (ids.isEmpty) {
      if (_employeeId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _employeeId = null);
        });
      }
      return;
    }
    if (_employeeId == null || !ids.contains(_employeeId)) {
      final next = ids.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _employeeId = next);
      });
    }
  }

  Future<void> _copy(OsPayslipModel slip) async {
    await copyOsPayslip(slip);
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _deletePayslip(OsPayslipModel slip) async {
    final id = slip.id?.trim();
    if (id == null || id.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osPayslipsTitle.tr,
        AppLocaleKeys.osPayslipsDeleteNotSaved.tr,
      );
      return;
    }
    final payroll = Get.find<OsPayrollController>();
    final message = slip.isPaid
        ? AppLocaleKeys.osPayslipsDeletePostedConfirm.tr
        : AppLocaleKeys.osPayslipsDeleteConfirm.tr;
    final confirmed = await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: message,
      onTap: () async {
        try {
          final ok = await payroll.deletePayslip(id);
          if (!ok) {
            OsSnackbar.error(
              AppLocaleKeys.osPayslipsTitle.tr,
              AppLocaleKeys.osCommonDeleteFailed.tr,
            );
            throw Exception('delete failed');
          }
        } on OsPayrollException catch (e) {
          OsSnackbar.error(AppLocaleKeys.osPayslipsTitle.tr, e.messageKey.tr);
          rethrow;
        } on OsFinanceException catch (e) {
          OsSnackbar.error(AppLocaleKeys.osPayslipsTitle.tr, e.messageKey.tr);
          rethrow;
        }
      },
    );
    if (confirmed == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OsSnackbar.success(
          AppLocaleKeys.osPayslipsTitle.tr,
          AppLocaleKeys.osPayslipsDeleted.tr,
        );
      });
    }
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
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final payroll = Get.find<OsPayrollController>();

    return Obx(() {
      final period = payroll.selectedPeriod.value;
      final emps = _employees(payroll);
      _ensureEmployeeSelection(emps);
      EmployeeModel? emp;
      for (final e in emps) {
        if (e.id == _employeeId) {
          emp = e;
          break;
        }
      }
      emp ??= emps.isEmpty ? null : emps.first;
      final slip = emp == null ? null : payroll.previewPayslip(emp);

      if (widget.compact) {
        return _buildCompact(
          context,
          theme,
          payroll,
          period,
          emps,
          emp,
          slip,
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsTabToolbar(
            leading: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                if (emps.isNotEmpty)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: emps.any((e) => e.id == _employeeId)
                          ? _employeeId
                          : emp?.id,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: theme.cardSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: emps
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(
                                e.name ?? e.id ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _employeeId = v;
                        _copied = false;
                      }),
                    ),
                  ),
              ],
            ),
            actions: [
              if (slip != null) ...[
                FilledButton.icon(
                  style: OsButtonStyles.primaryCompact(),
                  onPressed: () => printOsPayslip(slip),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: Text(AppLocaleKeys.osPayslipsPrint.tr),
                ),
                FilledButton.icon(
                  style: OsButtonStyles.secondaryCompact(
                    theme,
                    active: _copied,
                  ).copyWith(
                    foregroundColor: WidgetStatePropertyAll(
                      _copied ? AppColors.success : theme.primaryText,
                    ),
                    backgroundColor: WidgetStatePropertyAll(
                      _copied
                          ? AppColors.success.withValues(alpha: 0.12)
                          : theme.elevatedSurface,
                    ),
                    side: WidgetStatePropertyAll(
                      BorderSide(
                        color: _copied ? AppColors.success : theme.border,
                      ),
                    ),
                  ),
                  onPressed: () => _copy(slip),
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _copied
                        ? AppLocaleKeys.osPayslipsCopiedBtn.tr
                        : AppLocaleKeys.osPayslipsCopy.tr,
                  ),
                ),
                if ((slip.id ?? '').trim().isNotEmpty &&
                    OsPermissions.canDeleteCurrentOsRecords)
                  OutlinedButton.icon(
                    onPressed: () => _deletePayslip(slip),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF43F5E),
                      side: const BorderSide(color: Color(0xFFF43F5E)),
                      minimumSize: OsButtonStyles.compactMinSize,
                      padding: OsButtonStyles.compactPadding,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(AppLocaleKeys.osCommonDelete.tr),
                  ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.panelTint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.accentBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.accentText,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleKeys.osPayslipsPrintWarningTitle.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: theme.accentText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocaleKeys.osPayslipsPrintWarningBody.tr,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: slip == null
                ? OsEmptyState(message: AppLocaleKeys.osPayslipsEmpty.tr)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _PayslipPreview(
                        slip: slip,
                        branchLabel: _branchLabel(slip.branchId),
                      ),
                    ),
                  ),
          ),
        ],
      );
    });
  }

  Widget _buildCompact(
    BuildContext context,
    AppThemeExtension theme,
    OsPayrollController payroll,
    String period,
    List<EmployeeModel> emps,
    EmployeeModel? emp,
    OsPayslipModel? slip,
  ) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: OsButtonStyles.secondaryCompact(theme),
                    onPressed: () => _pickPeriod(context, payroll, period),
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(
                      '${AppLocaleKeys.osPayrollPeriod.tr}: ${_periodLabel(period)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (emps.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: emps.any((e) => e.id == _employeeId)
                        ? _employeeId
                        : emp?.id,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: theme.cardSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: emps
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              e.name ?? e.id ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _employeeId = v;
                      _copied = false;
                    }),
                  ),
                ],
                if (slip != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: OsButtonStyles.primaryCompact(),
                        onPressed: () => printOsPayslip(slip),
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: Text(AppLocaleKeys.osPayslipsPrint.tr),
                      ),
                      FilledButton.icon(
                        style: OsButtonStyles.secondaryCompact(
                          theme,
                          active: _copied,
                        ).copyWith(
                          foregroundColor: WidgetStatePropertyAll(
                            _copied ? AppColors.success : theme.primaryText,
                          ),
                          backgroundColor: WidgetStatePropertyAll(
                            _copied
                                ? AppColors.success.withValues(alpha: 0.12)
                                : theme.elevatedSurface,
                          ),
                          side: WidgetStatePropertyAll(
                            BorderSide(
                              color: _copied ? AppColors.success : theme.border,
                            ),
                          ),
                        ),
                        onPressed: () => _copy(slip),
                        icon: Icon(
                          _copied ? Icons.check : Icons.copy_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _copied
                              ? AppLocaleKeys.osPayslipsCopiedBtn.tr
                              : AppLocaleKeys.osPayslipsCopy.tr,
                        ),
                      ),
                      if ((slip.id ?? '').trim().isNotEmpty &&
                          OsPermissions.canDeleteCurrentOsRecords)
                        OutlinedButton.icon(
                          onPressed: () => _deletePayslip(slip),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF43F5E),
                            side: const BorderSide(color: Color(0xFFF43F5E)),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(AppLocaleKeys.osCommonDelete.tr),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.panelTint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.accentBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.accentText, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleKeys.osPayslipsPrintWarningTitle.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: theme.accentText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocaleKeys.osPayslipsPrintWarningBody.tr,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (slip == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: OsEmptyState(message: AppLocaleKeys.osPayslipsEmpty.tr),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              12,
              0,
              12,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverToBoxAdapter(
              child: _PayslipPreview(
                slip: slip,
                branchLabel: _branchLabel(slip.branchId),
                compact: true,
              ),
            ),
          ),
      ],
    );
  }
}

class _PayslipPreview extends StatelessWidget {
  const _PayslipPreview({
    required this.slip,
    required this.branchLabel,
    this.compact = false,
  });

  final OsPayslipModel slip;
  final String branchLabel;
  final bool compact;

  String _nationalIdFor(OsPayslipModel slip) {
    if (!Get.isRegistered<OsPayrollController>()) return '';
    final payroll = Get.find<OsPayrollController>();
    for (final e in payroll.employees) {
      if (e.id == slip.employeeId) {
        return e.nationalIdNumber?.trim() ?? '';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final ref = osPayslipRef(slip);
    final hire = slip.hireDate == null
        ? AppLocaleKeys.osCommonDash.tr
        : FirestoreOsFinanceApi.formatDate(slip.hireDate!);
    final status = slip.isPaid
        ? AppLocaleKeys.osPayslipsStatusPaid.tr
        : AppLocaleKeys.osPayslipsStatusPending.tr;

    return Container(
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 720),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(compact ? 16 : 24),
        border: Border.all(color: theme.border),
      ),
      padding: EdgeInsets.all(compact ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleKeys.osPayslipsAgency.tr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: theme.primaryText,
                      ),
                    ),
                    Text(
                      AppLocaleKeys.osPayslipsDept.tr,
                      style: TextStyle(fontSize: 11, color: theme.mutedText),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${AppLocaleKeys.osPayslipsDate.tr}: ${slip.period}',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.mutedText,
                    ),
                  ),
                  Text(
                    '${AppLocaleKeys.osPayslipsRef.tr}: $ref',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.mutedText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.inputFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _info(
                        theme,
                        AppLocaleKeys.osPayslipsEmployee.tr,
                        slip.employeeName,
                      ),
                    ),
                    Expanded(
                      child: _info(
                        theme,
                        AppLocaleKeys.osPayslipsJobTitle.tr,
                        slip.jobTitle?.trim().isNotEmpty == true
                            ? slip.jobTitle!
                            : AppLocaleKeys.osCommonDash.tr,
                      ),
                    ),
                  ],
                ),
                if (_nationalIdFor(slip).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _info(
                    theme,
                    AppLocaleKeys.employeesNationalIdNumber.tr,
                    _nationalIdFor(slip),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _info(
                        theme,
                        AppLocaleKeys.osPayslipsBranch.tr,
                        branchLabel,
                      ),
                    ),
                    Expanded(
                      child: _info(
                        theme,
                        AppLocaleKeys.osPayslipsHireDate.tr,
                        hire,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 520;
              final earnings = _amountCol(
                theme,
                title: AppLocaleKeys.osPayslipsEarnings.tr,
                titleColor: AppColors.success,
                rows: [
                  (
                    AppLocaleKeys.osPayslipsBasic.tr,
                    OsFinanceFormat.money(slip.basicSalary)
                  ),
                  (
                    AppLocaleKeys.osPayslipsAllowances.tr,
                    OsFinanceFormat.money(slip.allowances)
                  ),
                ],
                totalLabel: AppLocaleKeys.osPayslipsTotalEarnings.tr,
                totalValue: OsFinanceFormat.money(slip.totalEarnings),
              );
              final deductions = _amountCol(
                theme,
                title: AppLocaleKeys.osPayslipsDeductions.tr,
                titleColor: AppColors.destructive,
                rows: [
                  (
                    AppLocaleKeys.osPayslipsPenalties.tr,
                    OsFinanceFormat.money(slip.deductions)
                  ),
                  (
                    AppLocaleKeys.osPayslipsSocial.tr,
                    OsFinanceFormat.money(slip.socialSecurity)
                  ),
                  (
                    AppLocaleKeys.osPayslipsAdvance.tr,
                    OsFinanceFormat.money(slip.advanceDeduction)
                  ),
                ],
                totalLabel: AppLocaleKeys.osPayslipsTotalDeductions.tr,
                totalValue: OsFinanceFormat.money(slip.totalDeductions),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: earnings),
                    const SizedBox(width: 24),
                    Expanded(child: deductions),
                  ],
                );
              }
              return Column(
                children: [
                  earnings,
                  const SizedBox(height: 16),
                  deductions,
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.panelTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.accentBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocaleKeys.osPayslipsNetTransferred.tr,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: theme.accentText,
                        ),
                      ),
                      Text(
                        '${OsFinanceFormat.money(slip.netPay)} ${AppLocaleKeys.osPayslipsNetSuffix.tr}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: theme.accentText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.accentText.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: theme.accentText,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(AppThemeExtension theme, String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          k,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: theme.mutedText,
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: theme.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _amountCol(
    AppThemeExtension theme, {
    required String title,
    required Color titleColor,
    required List<(String, String)> rows,
    required String totalLabel,
    required String totalValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: titleColor.withValues(alpha: 0.25))),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    r.$1,
                    style: TextStyle(fontSize: 12, color: theme.secondaryText),
                  ),
                ),
                Text(
                  r.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryText,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  totalLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ),
              Text(
                totalValue,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
