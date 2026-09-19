import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsEmployeeAdvanceModel.dart';
import 'package:point/Models/Os/os_payroll_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/firestore/firestore_os_payroll_api.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Payroll/os_advance_form_dialog.dart';
import 'package:point/View/Os/Payroll/os_advance_repay_dialog.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_list_filters.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsAdvancesTab extends StatefulWidget {
  const OsAdvancesTab({super.key});

  @override
  State<OsAdvancesTab> createState() => _OsAdvancesTabState();
}

class _OsAdvancesTabState extends State<OsAdvancesTab> {
  final _search = TextEditingController();
  var _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<OsEmployeeAdvanceModel> _filtered(List<OsEmployeeAdvanceModel> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((a) {
      if (_status != 'ALL' && a.status != _status) return false;
      if (q.isNotEmpty && !a.employeeName.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _repay(
    BuildContext context,
    OsEmployeeAdvanceModel a,
  ) async {
    if (a.id == null || a.remainingAmount <= 0) {
      OsSnackbar.error(
        AppLocaleKeys.osAdvancesTitle.tr,
        AppLocaleKeys.osAdvancesStatusSettled.tr,
      );
      return;
    }
    await showOsAdvanceRepayDialog(context, a);
  }

  Future<void> _writeOff(
    BuildContext context,
    OsPayrollController payroll,
    OsEmployeeAdvanceModel a,
  ) async {
    final id = a.id;
    if (id == null) return;
    final confirmed = await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osAdvancesWriteOff.tr,
      message: AppLocaleKeys.osAdvancesWriteOffConfirm.tr,
      confirmText: AppLocaleKeys.osAdvancesWriteOff.tr,
      onTap: () async {
        try {
          final ok = await payroll.writeOffAdvance(id);
          if (!ok) {
            OsSnackbar.error(
              AppLocaleKeys.osAdvancesTitle.tr,
              AppLocaleKeys.osCommonSaveFailed.tr,
            );
            throw Exception('write-off failed');
          }
        } on OsPayrollException catch (e) {
          OsSnackbar.error(
            AppLocaleKeys.osAdvancesTitle.tr,
            e.messageKey.tr,
          );
          rethrow;
        }
      },
    );
    if (confirmed == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OsSnackbar.success(
          AppLocaleKeys.osAdvancesTitle.tr,
          AppLocaleKeys.osAdvancesWrittenOff.tr,
        );
      });
    }
  }

  Future<void> _delete(
    BuildContext context,
    OsPayrollController payroll,
    OsEmployeeAdvanceModel a,
  ) async {
    final id = a.id;
    if (id == null) return;
    final confirmed = await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: AppLocaleKeys.osAdvancesDeleteConfirm.tr,
      onTap: () async {
        final ok = await payroll.deleteAdvance(id);
        if (!ok) {
          OsSnackbar.error(
            AppLocaleKeys.osAdvancesTitle.tr,
            AppLocaleKeys.osCommonSaveFailed.tr,
          );
          throw Exception('delete failed');
        }
      },
    );
    if (confirmed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OsSnackbar.success(
          AppLocaleKeys.osAdvancesTitle.tr,
          AppLocaleKeys.osAdvancesDeleted.tr,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final payroll = Get.find<OsPayrollController>();

    return Obx(() {
      final all = payroll.advances.toList();
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
                  value: OsEmployeeAdvanceStatus.active,
                  label: AppLocaleKeys.osAdvancesStatusActive.tr,
                ),
                OsFilterChipOption(
                  value: OsEmployeeAdvanceStatus.settled,
                  label: AppLocaleKeys.osAdvancesStatusSettled.tr,
                ),
              ],
            ),
            search: OsSearchField(
              controller: _search,
              hint: AppLocaleKeys.osAdvancesSearch.tr,
              onChanged: (_) => setState(() {}),
            ),
            actions: [
              FilledButton.icon(
                style: OsButtonStyles.primaryCompact(),
                onPressed: () => showOsAdvanceFormDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocaleKeys.osAdvancesAdd.tr),
              ),
            ],
            matchCount: all.isEmpty ? null : items.length,
          ),
          Expanded(
            child: items.isEmpty
                ? OsEmptyState(
                    message: all.isEmpty
                        ? AppLocaleKeys.osAdvancesEmpty.tr
                        : AppLocaleKeys.osAdvancesEmptyFilter.tr,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 900
                          ? 3
                          : constraints.maxWidth > 560
                              ? 2
                              : 1;
                      const gap = 16.0;
                      final cardW =
                          (constraints.maxWidth - 32 - gap * (cols - 1)) / cols;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final a in items)
                              SizedBox(
                                width: cardW,
                                child: _AdvanceCard(
                                  advance: a,
                                  onRepay: () => _repay(context, a),
                                  onWriteOff: () =>
                                      _writeOff(context, payroll, a),
                                  onDelete: () => _delete(context, payroll, a),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({
    required this.advance,
    required this.onRepay,
    required this.onWriteOff,
    required this.onDelete,
  });

  final OsEmployeeAdvanceModel advance;
  final VoidCallback onRepay;
  final VoidCallback onWriteOff;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final active = advance.status == OsEmployeeAdvanceStatus.active;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: AppColors.primary),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        advance.employeeName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                    if (OsPermissions.canDeleteCurrentOsRecords)
                      IconButton(
                        tooltip: AppLocaleKeys.osCommonDelete.tr,
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.mutedText,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _kv(
                  theme,
                  AppLocaleKeys.osAdvancesTotalGranted.tr,
                  OsFinanceFormat.money(advance.totalAmount),
                ),
                const SizedBox(height: 8),
                _kv(
                  theme,
                  AppLocaleKeys.osAdvancesPaid.tr,
                  OsFinanceFormat.money(advance.paidAmount),
                  valueColor: AppColors.success,
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: theme.border),
                const SizedBox(height: 10),
                _kv(
                  theme,
                  AppLocaleKeys.osAdvancesRemaining.tr,
                  OsFinanceFormat.money(advance.remainingAmount),
                  labelColor: theme.accentText,
                  valueColor: theme.accentText,
                  bold: true,
                ),
                if (active) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      FilledButton(
                        style: OsButtonStyles.secondaryCompact(theme),
                        onPressed: onRepay,
                        child: Text(AppLocaleKeys.osAdvancesRepay.tr),
                      ),
                      TextButton(
                        onPressed: onWriteOff,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.destructive,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          AppLocaleKeys.osAdvancesWriteOff.tr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(
    AppThemeExtension theme,
    String label,
    String value, {
    Color? labelColor,
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: labelColor ?? theme.mutedText,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: valueColor ?? theme.primaryText,
          ),
        ),
      ],
    );
  }
}
