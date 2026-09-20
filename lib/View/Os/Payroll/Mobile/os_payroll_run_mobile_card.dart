import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Services/firestore/firestore_os_payroll_api.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Shared/safe_network_image.dart';

class OsPayrollRunLineSnapshot {
  OsPayrollRunLineSnapshot({
    required this.employee,
    required this.name,
    required this.roleLine,
    required this.basic,
    required this.allowances,
    required this.deductions,
    required this.advance,
    required this.net,
    required this.isPaid,
    required this.canEdit,
    required this.noSalary,
  });

  final EmployeeModel employee;
  final String name;
  final String roleLine;
  final double basic;
  final double allowances;
  final double deductions;
  final double advance;
  final double net;
  final bool isPaid;
  final bool canEdit;
  final bool noSalary;

  static double _unpaidAmount({
    required Map<String, double> drafts,
    required String empId,
    required double? slipValue,
  }) {
    if (drafts.containsKey(empId)) return drafts[empId]!;
    return slipValue ?? 0;
  }

  static OsPayrollRunLineSnapshot from({
    required EmployeeModel emp,
    required OsPayrollController payroll,
    required String period,
    required String Function(String?) branchLabel,
  }) {
    final empId = emp.id ?? '';
    final OsPayslipModel? slip = payroll.payslipForEmployee(period, empId);
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
    final advance =
        slip?.advanceDeduction ?? payroll.suggestedAdvanceFor(empId);
    final net = isPaid
        ? (slip?.netPay ?? 0)
        : FirestoreOsPayrollApi.computeNetPay(
            basicSalary: basic,
            allowances: allowances,
            deductions: deductions,
            socialSecurity: social,
            advanceDeduction: advance,
          );
    final role = emp.jobTitle?.trim().isNotEmpty == true
        ? emp.jobTitle!
        : AppLocaleKeys.osCommonDash.tr;
    final name = (emp.name ?? '').trim();

    return OsPayrollRunLineSnapshot(
      employee: emp,
      name: name,
      roleLine: '$role • ${branchLabel(emp.branchId)}',
      basic: basic,
      allowances: allowances,
      deductions: deductions,
      advance: advance,
      net: net,
      isPaid: isPaid,
      canEdit: !isPaid && basic > 0,
      noSalary: basic <= 0,
    );
  }
}

class OsPayrollRunMobileCard extends StatelessWidget {
  const OsPayrollRunMobileCard({
    super.key,
    required this.snapshot,
    required this.loading,
    required this.onAdjust,
    required this.onDisburse,
  });

  final OsPayrollRunLineSnapshot snapshot;
  final bool loading;
  final VoidCallback? onAdjust;
  final VoidCallback? onDisburse;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final emp = snapshot.employee;
    final name = snapshot.name;

    return Material(
      color: theme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircleAvatar(
                    backgroundColor: theme.panelTint,
                    child: (emp.image ?? '').isNotEmpty
                        ? ClipOval(
                            child: SafeNetworkImage(
                              emp.image!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            name.isEmpty ? '?' : name.substring(0, 1),
                            style: TextStyle(
                              color: theme.accentText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? AppLocaleKeys.osCommonDash.tr : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.roleLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(theme),
              ],
            ),
            const SizedBox(height: 12),
            _moneyRow(
              theme,
              AppLocaleKeys.osPayrollColBasic.tr,
              snapshot.basic,
            ),
            const SizedBox(height: 4),
            _moneyRow(
              theme,
              AppLocaleKeys.osPayrollColAllowances.tr,
              snapshot.allowances,
            ),
            const SizedBox(height: 4),
            _moneyRow(
              theme,
              AppLocaleKeys.osPayrollColDeductions.tr,
              snapshot.deductions,
            ),
            const SizedBox(height: 8),
            Text(
              OsFinanceFormat.money(snapshot.net),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: theme.accentText,
              ),
            ),
            Text(
              AppLocaleKeys.osPayrollColNet.tr,
              style: TextStyle(fontSize: 11, color: theme.mutedText),
            ),
            if (snapshot.advance > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${AppLocaleKeys.osPayrollColAdvance.tr}: ${OsFinanceFormat.money(snapshot.advance)}',
                style: TextStyle(fontSize: 11, color: theme.mutedText),
              ),
            ],
            if (!snapshot.noSalary && !snapshot.isPaid) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (snapshot.canEdit && onAdjust != null)
                    Expanded(
                      child: FilledButton(
                        onPressed: loading ? null : onAdjust,
                        style: OsButtonStyles.secondaryCompact(theme),
                        child: Text(
                          AppLocaleKeys.osPayrollAdjustEdit.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (snapshot.canEdit && onAdjust != null)
                    const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: loading ? null : onDisburse,
                      style: OsButtonStyles.primaryCompact(),
                      child: Text(
                        AppLocaleKeys.osPayrollDisburse.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(AppThemeExtension theme) {
    if (snapshot.noSalary) {
      return Text(
        AppLocaleKeys.osPayrollNoSalary.tr,
        style: const TextStyle(
          color: AppColors.caution,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (snapshot.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            const Icon(Icons.check_circle, size: 12, color: AppColors.success),
            const SizedBox(width: 4),
            Text(
              AppLocaleKeys.osPayrollDisbursedPosted.tr,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
                fontSize: 9,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.caution.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppLocaleKeys.osPayrollFilterPending.tr,
        style: const TextStyle(
          color: AppColors.caution,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _moneyRow(AppThemeExtension theme, String label, double amount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: theme.mutedText),
          ),
        ),
        Text(
          OsFinanceFormat.money(amount),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.secondaryText,
          ),
        ),
      ],
    );
  }
}
