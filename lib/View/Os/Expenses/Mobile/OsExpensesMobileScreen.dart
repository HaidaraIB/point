import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/Models/Os/os_expense_constants.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Expenses/OsExpensesPage.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_list_filters.dart';
import 'package:point/View/Os/os_horizontal_scroll_view.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/safe_network_image.dart';

/// Mobile-only expenses layout (stacked filters + scrollable cards).
class OsExpensesMobileScreen extends StatelessWidget {
  const OsExpensesMobileScreen({
    super.key,
    required this.all,
    required this.list,
    required this.today,
    required this.todayTotal,
    required this.weekTotal,
    required this.monthTotal,
    required this.withReceipt,
    required this.receiptPct,
    required this.currency,
    required this.money,
    required this.search,
    required this.category,
    required this.datePreset,
    required this.branch,
    required this.withReceiptOnly,
    required this.finance,
    required this.categoryLabel,
    required this.paidByLabel,
    required this.onFiltersChanged,
    required this.onCategoryChanged,
    required this.onDatePresetChanged,
    required this.onBranchChanged,
    required this.onReceiptOnlyChanged,
    required this.onAdd,
    required this.onPrint,
    required this.onEdit,
    required this.onDelete,
    required this.onReceipt,
  });

  final List<OsDailyExpenseModel> all;
  final List<OsDailyExpenseModel> list;
  final String today;
  final double todayTotal;
  final double weekTotal;
  final double monthTotal;
  final int withReceipt;
  final int receiptPct;
  final String currency;
  final NumberFormat money;
  final TextEditingController search;
  final String category;
  final String datePreset;
  final String branch;
  final bool withReceiptOnly;
  final OsFinanceController finance;
  final String Function(OsDailyExpenseModel) categoryLabel;
  final String Function(String) paidByLabel;
  final VoidCallback onFiltersChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onDatePresetChanged;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<bool> onReceiptOnlyChanged;
  final VoidCallback onAdd;
  final VoidCallback onPrint;
  final void Function(OsDailyExpenseModel) onEdit;
  final void Function(OsDailyExpenseModel) onDelete;
  final void Function(OsDailyExpenseModel) onReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OsPageHeader(
          title: AppLocaleKeys.osModuleExpenses.tr,
          currentRoute: '/os/expenses',
          actions: [
            if (list.isNotEmpty)
              FilledButton.icon(
                onPressed: onPrint,
                style: OsButtonStyles.secondaryCompact(theme),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: Text(AppLocaleKeys.osExpensesPrint.tr),
              ),
            FilledButton.icon(
              onPressed: onAdd,
              style: OsButtonStyles.primaryCompact(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppLocaleKeys.osExpensesAdd.tr),
            ),
          ],
        ),
        Expanded(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: OsHorizontalScrollContainer(
                  height: 132,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  builder: (_) => Row(
                    children: [
                      SizedBox(
                        width: 168,
                        height: 132,
                        child: OsExpensesKpiCard(
                          dense: true,
                          label: AppLocaleKeys.osExpensesKpiToday.tr,
                          value: money.format(todayTotal),
                          unit: currency,
                          hint: today,
                          hintIcon: Icons.calendar_today_outlined,
                          icon: Icons.trending_down,
                          iconBg: const Color(0x33F43F5E),
                          iconColor: const Color(0xFFF43F5E),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 168,
                        height: 132,
                        child: OsExpensesKpiCard(
                          dense: true,
                          label: AppLocaleKeys.osExpensesKpiWeek.tr,
                          value: money.format(weekTotal),
                          unit: currency,
                          hint: AppLocaleKeys.osExpensesKpiWeekHint.tr,
                          hintIcon: Icons.schedule,
                          icon: Icons.account_balance_wallet_outlined,
                          iconBg: const Color(0x33F59E0B),
                          iconColor: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 168,
                        height: 132,
                        child: OsExpensesKpiCard(
                          dense: true,
                          label: AppLocaleKeys.osExpensesKpiMonth.tr,
                          value: money.format(monthTotal),
                          unit: currency,
                          hint: AppLocaleKeys.osExpensesKpiMonthHint.tr,
                          hintIcon: Icons.apartment_outlined,
                          icon: Icons.credit_card,
                          iconBg: AppColors.primary.withValues(alpha: 0.18),
                          iconColor: theme.accentText,
                          valueColor: theme.accentText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 188,
                        height: 132,
                        child: OsExpensesKpiCard(
                          dense: true,
                          label: AppLocaleKeys.osExpensesKpiReceiptCoverage.tr,
                          value: AppLocaleKeys.osExpensesKpiReceiptsOf.trParams({
                            'count': '$withReceipt',
                            'total': '${all.length}',
                          }),
                          unit: '',
                          hint: all.isEmpty
                              ? AppLocaleKeys.osExpensesKpiReceiptsEmpty.tr
                              : AppLocaleKeys.osExpensesKpiReceiptsPct
                                  .trParams({'pct': '$receiptPct'}),
                          hintIcon: Icons.check_circle_outline,
                          icon: Icons.fact_check_outlined,
                          iconBg: const Color(0x3310B981),
                          iconColor: const Color(0xFF10B981),
                          valueColor: const Color(0xFF10B981),
                          hintColor: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverToBoxAdapter(
                  child: OsExpensesMobileFilters(
                    theme: theme,
                    finance: finance,
                    category: category,
                    datePreset: datePreset,
                    branch: branch,
                    withReceiptOnly: withReceiptOnly,
                    search: search,
                    matchCount: all.isEmpty ? null : list.length,
                    onFiltersChanged: onFiltersChanged,
                    onCategoryChanged: onCategoryChanged,
                    onDatePresetChanged: onDatePresetChanged,
                    onBranchChanged: onBranchChanged,
                    onReceiptOnlyChanged: onReceiptOnlyChanged,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _OsExpensesMobileEmptyState(
                    filteredOut: all.isNotEmpty,
                    onAdd: onAdd,
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final e = list[index];
                      return OsExpenseMobileCard(
                        expense: e,
                        categoryLabel: categoryLabel(e),
                        paidByLabel: paidByLabel(e.paidBy),
                        money: money,
                        currency: currency,
                        onEdit: () => onEdit(e),
                        onDelete: () => onDelete(e),
                        onReceipt: () => onReceipt(e),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OsExpensesMobileEmptyState extends StatelessWidget {
  const _OsExpensesMobileEmptyState({
    required this.filteredOut,
    required this.onAdd,
  });

  final bool filteredOut;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 48, color: theme.mutedText),
          const SizedBox(height: 12),
          Text(
            filteredOut
                ? AppLocaleKeys.osExpensesEmptyFilter.tr
                : AppLocaleKeys.osExpensesEmpty.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleKeys.osExpensesEmptyHint.tr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.secondaryText),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAdd,
            style: OsButtonStyles.primaryCompact(),
            child: Text(AppLocaleKeys.osExpensesEmptyCta.tr),
          ),
        ],
      ),
    );
  }
}

/// Mobile filter block (date presets + dropdowns + receipt toggle).
class OsExpensesMobileFilters extends StatelessWidget {
  const OsExpensesMobileFilters({
    super.key,
    required this.theme,
    required this.finance,
    required this.category,
    required this.datePreset,
    required this.branch,
    required this.withReceiptOnly,
    required this.search,
    required this.onFiltersChanged,
    this.matchCount,
    required this.onCategoryChanged,
    required this.onDatePresetChanged,
    required this.onBranchChanged,
    required this.onReceiptOnlyChanged,
  });

  final AppThemeExtension theme;
  final OsFinanceController finance;
  final String category;
  final String datePreset;
  final String branch;
  final bool withReceiptOnly;
  final TextEditingController search;
  final VoidCallback onFiltersChanged;
  final int? matchCount;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onDatePresetChanged;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<bool> onReceiptOnlyChanged;

  Widget _sectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 1, color: theme.border),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsHorizontalScrollContainer(
            clipBehavior: Clip.hardEdge,
            builder: (_) => Row(
              children: [
                for (final entry in const [
                  ('ALL', AppLocaleKeys.osExpensesFilterAll),
                  ('TODAY', AppLocaleKeys.osExpensesFilterToday),
                  ('YESTERDAY', AppLocaleKeys.osExpensesFilterYesterday),
                  ('WEEK', AppLocaleKeys.osExpensesFilterWeek),
                  ('MONTH', AppLocaleKeys.osExpensesFilterMonth),
                ]) ...[
                  OsExpensesDatePill(
                    label: entry.$2.tr,
                    selected: datePreset == entry.$1,
                    onTap: () => onDatePresetChanged(entry.$1),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          _sectionDivider(),
          Row(
            children: [
              Expanded(
                child: OsExpensesCompactFilterMenu<String>(
                  value: category,
                  labelBuilder: (v) => v == 'ALL'
                      ? AppLocaleKeys.osExpensesFilterCategoryAll.tr
                      : v.tr,
                  entries: [
                    (
                      'ALL',
                      AppLocaleKeys.osExpensesFilterCategoryAll.tr,
                    ),
                    for (final cat in OsExpenseCategories.all) (cat, cat.tr),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OsExpensesCompactFilterMenu<String>(
                  value: branch,
                  labelBuilder: (v) {
                    if (v == 'ALL') {
                      return AppLocaleKeys.osExpensesFilterBranchAll.tr;
                    }
                    return finance.branchName(v);
                  },
                  entries: [
                    (
                      'ALL',
                      AppLocaleKeys.osExpensesFilterBranchAll.tr,
                    ),
                    for (final b in finance.branches)
                      if (b.id != null && b.id!.isNotEmpty) (b.id!, b.name),
                  ],
                  onChanged: onBranchChanged,
                ),
              ),
            ],
          ),
          _sectionDivider(),
          InkWell(
            onTap: () => onReceiptOnlyChanged(!withReceiptOnly),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: withReceiptOnly,
                    onChanged: (v) => onReceiptOnlyChanged(v ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 14,
                    color: theme.accentText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppLocaleKeys.osExpensesWithReceiptOnly.tr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _sectionDivider(),
          OsSearchField(
            controller: search,
            hint: AppLocaleKeys.osExpensesSearch.tr,
            width: double.infinity,
            onChanged: (_) => onFiltersChanged(),
          ),
          if (matchCount != null) ...[
            const SizedBox(height: 8),
            Text(
              AppLocaleKeys.osCommonMatchCount.trParams({
                'count': '$matchCount',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OsExpenseMobileCard extends StatelessWidget {
  const OsExpenseMobileCard({
    super.key,
    required this.expense,
    required this.categoryLabel,
    required this.paidByLabel,
    required this.money,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
    required this.onReceipt,
  });

  final OsDailyExpenseModel expense;
  final String categoryLabel;
  final String paidByLabel;
  final NumberFormat money;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final e = expense;

    return Material(
      color: theme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.hasReceipt)
                InkWell(
                  onTap: onReceipt,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SafeNetworkImage(
                      e.receiptImageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: theme.inputFill,
                        child: Icon(
                          Icons.receipt_long,
                          color: theme.mutedText,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.border),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: theme.mutedText,
                    size: 22,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                        Text(
                          e.date,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.mutedText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            categoryLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.accentText,
                            ),
                          ),
                        ),
                        if (e.vendor != null && e.vendor!.isNotEmpty)
                          Text(
                            e.vendor!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.secondaryText,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        text: money.format(e.amount),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: theme.accentText,
                        ),
                        children: [
                          TextSpan(
                            text: ' $currency',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      paidByLabel,
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
              Column(
                children: [
                  if (e.hasReceipt)
                    IconButton(
                      tooltip: AppLocaleKeys.osExpensesReceiptView.tr,
                      onPressed: onReceipt,
                      icon: Icon(
                        Icons.visibility_outlined,
                        size: 20,
                        color: theme.accentText,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: theme.secondaryText,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (OsPermissions.canDeleteCurrentOsRecords)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Color(0xFFF43F5E),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
