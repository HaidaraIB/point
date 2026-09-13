import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/Models/Os/os_expense_constants.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Mobile/Shared/VideoCart.dart';
import 'package:point/View/Os/Expenses/os_expense_form_dialog.dart';
import 'package:point/View/Os/Expenses/os_expense_print.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/app_data_table.dart';
import 'package:point/View/Shared/safe_network_image.dart';

class OsExpensesPage extends StatefulWidget {
  const OsExpensesPage({super.key});

  @override
  State<OsExpensesPage> createState() => _OsExpensesPageState();
}

class _OsExpensesPageState extends State<OsExpensesPage> {
  final _search = TextEditingController();
  final _money = NumberFormat('#,##0', 'en_US');
  var _category = 'ALL';
  var _datePreset = 'ALL';
  var _branch = 'ALL';
  var _withReceiptOnly = false;
  var _tableView = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _paidByLabel(String paidBy) =>
      paidBy.startsWith('os.') ? paidBy.tr : paidBy;

  String _categoryLabel(OsDailyExpenseModel e) {
    final c = e.category.trim();
    if (c.startsWith('os.')) return c.tr;
    return c;
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  String _weekStartStr() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final sundayOffset = today.weekday % 7;
    final start = today.subtract(Duration(days: sundayOffset));
    return '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
  }

  bool _matchesDate(OsDailyExpenseModel e, String today, String weekStart) {
    if (_datePreset == 'ALL') return true;
    final d = e.date;
    if (d.isEmpty) return false;
    switch (_datePreset) {
      case 'TODAY':
        return d == today;
      case 'YESTERDAY':
        final y = DateTime.now().subtract(const Duration(days: 1));
        final ys =
            '${y.year.toString().padLeft(4, '0')}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
        return d == ys;
      case 'WEEK':
        return d.compareTo(weekStart) >= 0;
      case 'MONTH':
        return d.startsWith(today.substring(0, 7));
      default:
        return true;
    }
  }

  List<OsDailyExpenseModel> _filtered(
    List<OsDailyExpenseModel> all,
    String today,
    String weekStart,
  ) {
    final q = _search.text.trim().toLowerCase();
    return all.where((e) {
      if (!_matchesDate(e, today, weekStart)) return false;
      if (_category != 'ALL' && e.category != _category) return false;
      if (_branch != 'ALL' && e.branchId != _branch) return false;
      if (_withReceiptOnly && !e.hasReceipt) return false;
      if (q.isEmpty) return true;
      final hay = [
        e.title,
        e.vendor ?? '',
        e.receiptNumber ?? '',
        e.paidBy,
        e.notes ?? '',
        e.category,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _confirmDelete(
    OsFinanceController finance,
    OsDailyExpenseModel e,
  ) async {
    if (e.id == null) return;
    await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: AppLocaleKeys.osExpensesDeleteConfirm.tr,
      onTap: () async {
        final deleted = await finance.deleteExpense(e.id!);
        if (!deleted) {
          OsSnackbar.error(
            AppLocaleKeys.osExpensesTitle.tr,
            AppLocaleKeys.osCommonSaveFailed.tr,
          );
          throw Exception('delete failed');
        }
      },
    );
  }

  void _viewReceipt(OsDailyExpenseModel e) {
    final url = e.receiptImageUrl?.trim();
    if (url == null || url.isEmpty) return;
    // Receipts are always images; use the shared viewer (CORS-safe on web).
    Get.to(() => ImagePreviewPage(url: url));
  }

  Widget _panel(AppThemeExtension theme, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessOsSection(emp)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    final finance = Get.find<OsFinanceController>();
    final theme = context.appTheme;
    final today = _todayStr();
    final weekStart = _weekStartStr();
    final currency = AppLocaleKeys.osInvoicesCurrency.tr;

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Obx(() {
        final all = finance.expenses.toList();
        final list = _filtered(all, today, weekStart);
        var todayTotal = 0.0;
        var weekTotal = 0.0;
        var monthTotal = 0.0;
        var withReceipt = 0;
        final monthPrefix = today.substring(0, 7);
        for (final e in all) {
          final amt = e.amount;
          if (e.date == today) todayTotal += amt;
          if (e.date.compareTo(weekStart) >= 0) weekTotal += amt;
          if (e.date.startsWith(monthPrefix)) monthTotal += amt;
          if (e.hasReceipt) withReceipt++;
        }
        final pct = all.isEmpty
            ? 0
            : ((withReceipt / all.length) * 100).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OsPageHeader(
              title: AppLocaleKeys.osModuleExpenses.tr,
              currentRoute: '/os/expenses',
              showModuleNav: true,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                  // Header card (point_os)
                  _panel(
                    theme,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final narrow = c.maxWidth < 720;
                          final titleBlock = Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocaleKeys.osExpensesTitle.tr,
                                      style: TextStyle(
                                        fontSize: narrow ? 18 : 22,
                                        fontWeight: FontWeight.w900,
                                        color: theme.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppLocaleKeys.osExpensesSubtitle.tr,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                          final actions = Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.end,
                            children: [
                              FilledButton.icon(
                                onPressed: list.isEmpty
                                    ? null
                                    : () => printOsExpensesSheet(
                                          expenses: list,
                                          categoryLabel: _categoryLabel,
                                          amountLabel: (e) =>
                                              OsFinanceFormat.money(e.amount),
                                        ),
                                icon: const Icon(Icons.print_outlined, size: 16),
                                label: Text(AppLocaleKeys.osExpensesPrint.tr),
                                style: OsButtonStyles.secondaryCompact(theme),
                              ),
                              FilledButton.icon(
                                onPressed: () =>
                                    showOsExpenseFormDialog(context),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(AppLocaleKeys.osExpensesAdd.tr),
                                style: OsButtonStyles.primaryCompact(),
                              ),
                            ],
                          );
                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                titleBlock,
                                const SizedBox(height: 14),
                                actions,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: titleBlock),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: actions,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // KPI row
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth > 1000
                          ? 4
                          : c.maxWidth > 600
                              ? 2
                              : 1;
                      final cards = [
                        _KpiCard(
                          label: AppLocaleKeys.osExpensesKpiToday.tr,
                          value: _money.format(todayTotal),
                          unit: currency,
                          hint: today,
                          hintIcon: Icons.calendar_today_outlined,
                          icon: Icons.trending_down,
                          iconBg: const Color(0x33F43F5E),
                          iconColor: const Color(0xFFF43F5E),
                        ),
                        _KpiCard(
                          label: AppLocaleKeys.osExpensesKpiWeek.tr,
                          value: _money.format(weekTotal),
                          unit: currency,
                          hint: AppLocaleKeys.osExpensesKpiWeekHint.tr,
                          hintIcon: Icons.schedule,
                          icon: Icons.account_balance_wallet_outlined,
                          iconBg: const Color(0x33F59E0B),
                          iconColor: const Color(0xFFF59E0B),
                        ),
                        _KpiCard(
                          label: AppLocaleKeys.osExpensesKpiMonth.tr,
                          value: _money.format(monthTotal),
                          unit: currency,
                          hint: AppLocaleKeys.osExpensesKpiMonthHint.tr,
                          hintIcon: Icons.apartment_outlined,
                          icon: Icons.credit_card,
                          iconBg: AppColors.primary.withValues(alpha: 0.18),
                          iconColor: theme.accentText,
                          valueColor: theme.accentText,
                        ),
                        _KpiCard(
                          label: AppLocaleKeys.osExpensesKpiReceiptCoverage.tr,
                          value: AppLocaleKeys.osExpensesKpiReceiptsOf.trParams({
                            'count': '$withReceipt',
                            'total': '${all.length}',
                          }),
                          unit: '',
                          hint: all.isEmpty
                              ? AppLocaleKeys.osExpensesKpiReceiptsEmpty.tr
                              : AppLocaleKeys.osExpensesKpiReceiptsPct
                                  .trParams({'pct': '$pct'}),
                          hintIcon: Icons.check_circle_outline,
                          icon: Icons.fact_check_outlined,
                          iconBg: const Color(0x3310B981),
                          iconColor: const Color(0xFF10B981),
                          valueColor: const Color(0xFF10B981),
                          hintColor: const Color(0xFF10B981),
                        ),
                      ];
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: cols == 1 ? 2.6 : 1.85,
                        children: cards,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Filters
                  _panel(
                    theme,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Row 1: date + category/branch/receipt filters, view toggle at end
                          LayoutBuilder(
                            builder: (context, c) {
                              final narrow = c.maxWidth < 780;
                              final presets = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final entry in const [
                                    (
                                      'ALL',
                                      AppLocaleKeys.osExpensesFilterAll
                                    ),
                                    (
                                      'TODAY',
                                      AppLocaleKeys.osExpensesFilterToday
                                    ),
                                    (
                                      'YESTERDAY',
                                      AppLocaleKeys.osExpensesFilterYesterday
                                    ),
                                    (
                                      'WEEK',
                                      AppLocaleKeys.osExpensesFilterWeek
                                    ),
                                    (
                                      'MONTH',
                                      AppLocaleKeys.osExpensesFilterMonth
                                    ),
                                  ]) ...[
                                    _DatePill(
                                      label: entry.$2.tr,
                                      selected: _datePreset == entry.$1,
                                      onTap: () => setState(
                                        () => _datePreset = entry.$1,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                ],
                              );
                              final secondaryFilters = Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${AppLocaleKeys.osExpensesCategory.tr}:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.mutedText,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _CompactFilterMenu<String>(
                                        value: _category,
                                        labelBuilder: (v) => v == 'ALL'
                                            ? AppLocaleKeys
                                                .osExpensesFilterCategoryAll.tr
                                            : v.tr,
                                        entries: [
                                          (
                                            'ALL',
                                            AppLocaleKeys
                                                .osExpensesFilterCategoryAll.tr
                                          ),
                                          for (final cat
                                              in OsExpenseCategories.all)
                                            (cat, cat.tr),
                                        ],
                                        onChanged: (v) =>
                                            setState(() => _category = v),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${AppLocaleKeys.osExpensesBranch.tr}:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.mutedText,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _CompactFilterMenu<String>(
                                        value: _branch,
                                        labelBuilder: (v) {
                                          if (v == 'ALL') {
                                            return AppLocaleKeys
                                                .osExpensesFilterBranchAll.tr;
                                          }
                                          for (final b in osExpenseBranches) {
                                            if (b.id == v) return b.nameKey.tr;
                                          }
                                          return v;
                                        },
                                        entries: [
                                          (
                                            'ALL',
                                            AppLocaleKeys
                                                .osExpensesFilterBranchAll.tr
                                          ),
                                          for (final b in osExpenseBranches)
                                            (b.id, b.nameKey.tr),
                                        ],
                                        onChanged: (v) =>
                                            setState(() => _branch = v),
                                      ),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () => setState(
                                      () =>
                                          _withReceiptOnly = !_withReceiptOnly,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: _withReceiptOnly,
                                          onChanged: (v) => setState(
                                            () => _withReceiptOnly =
                                                v ?? false,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Icon(
                                          Icons.camera_alt_outlined,
                                          size: 14,
                                          color: theme.accentText,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          AppLocaleKeys
                                              .osExpensesWithReceiptOnly.tr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme.primaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                              final viewToggle = Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.inputFill,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ViewToggleBtn(
                                      icon: Icons.view_list_outlined,
                                      selected: _tableView,
                                      tooltip:
                                          AppLocaleKeys.osExpensesViewTable.tr,
                                      onTap: () =>
                                          setState(() => _tableView = true),
                                    ),
                                    _ViewToggleBtn(
                                      icon: Icons.grid_view_outlined,
                                      selected: !_tableView,
                                      tooltip:
                                          AppLocaleKeys.osExpensesViewGrid.tr,
                                      onTap: () =>
                                          setState(() => _tableView = false),
                                    ),
                                  ],
                                ),
                              );

                              if (narrow) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: presets,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        viewToggle,
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    secondaryFilters,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          presets,
                                          const SizedBox(width: 16),
                                          secondaryFilters,
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  viewToggle,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          // Row 2: search alone under the filters
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: TextField(
                                controller: _search,
                                onChanged: (_) => setState(() {}),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.primaryText,
                                ),
                                decoration: InputDecoration(
                                  hintText: AppLocaleKeys.osExpensesSearch.tr,
                                  hintMaxLines: 1,
                                  prefixIcon: Icon(
                                    Icons.search,
                                    size: 18,
                                    color: theme.mutedText,
                                  ),
                                  suffixIcon: _search.text.isEmpty
                                      ? null
                                      : IconButton(
                                          icon:
                                              const Icon(Icons.close, size: 16),
                                          onPressed: () {
                                            _search.clear();
                                            setState(() {});
                                          },
                                        ),
                                  filled: true,
                                  fillColor: theme.inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: theme.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: theme.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  isDense: false,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (list.isEmpty)
                    _panel(
                      theme,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 48,
                          horizontal: 24,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.receipt_long,
                                size: 32,
                                color: theme.accentText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppLocaleKeys.osExpensesEmpty.tr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLocaleKeys.osExpensesEmptyHint.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () =>
                                  showOsExpenseFormDialog(context),
                              style: OsButtonStyles.primaryCompact(),
                              child: Text(AppLocaleKeys.osExpensesEmptyCta.tr),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!_tableView)
                    _ExpensesGrid(
                      expenses: list,
                      categoryLabel: _categoryLabel,
                      paidByLabel: _paidByLabel,
                      money: _money,
                      currency: currency,
                      onEdit: (e) =>
                          showOsExpenseFormDialog(context, existing: e),
                      onDelete: (e) => _confirmDelete(finance, e),
                      onReceipt: _viewReceipt,
                    )
                  else
                    _ExpensesTable(
                      expenses: list,
                      categoryLabel: _categoryLabel,
                      paidByLabel: _paidByLabel,
                      money: _money,
                      currency: currency,
                      onEdit: (e) =>
                          showOsExpenseFormDialog(context, existing: e),
                      onDelete: (e) => _confirmDelete(finance, e),
                      onReceipt: _viewReceipt,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _CompactFilterMenu<T> extends StatelessWidget {
  const _CompactFilterMenu({
    required this.value,
    required this.entries,
    required this.labelBuilder,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> entries;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return PopupMenuButton<T>(
      initialValue: value,
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: onChanged,
      itemBuilder: (ctx) => [
        for (final e in entries)
          PopupMenuItem<T>(
            value: e.$1,
            child: Text(e.$2, style: const TextStyle(fontSize: 13)),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            labelBuilder(value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 20, color: theme.mutedText),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Material(
      color: selected ? AppColors.primary : theme.inputFill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : theme.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewToggleBtn extends StatelessWidget {
  const _ViewToggleBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? theme.cardSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        elevation: selected ? 1 : 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 16,
              color: selected ? theme.accentText : theme.mutedText,
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.hint,
    required this.hintIcon,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.valueColor,
    this.hintColor,
  });

  final String label;
  final String value;
  final String unit;
  final String hint;
  final IconData hintIcon;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color? valueColor;
  final Color? hintColor;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.secondaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          const Spacer(),
          Text.rich(
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: valueColor ?? theme.primaryText,
              ),
              children: unit.isEmpty
                  ? null
                  : [
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: theme.mutedText,
                        ),
                      ),
                    ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(hintIcon, size: 12, color: hintColor ?? theme.mutedText),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: hintColor != null ? FontWeight.w600 : null,
                    color: hintColor ?? theme.mutedText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpensesTable extends StatelessWidget {
  const _ExpensesTable({
    required this.expenses,
    required this.categoryLabel,
    required this.paidByLabel,
    required this.money,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
    required this.onReceipt,
  });

  final List<OsDailyExpenseModel> expenses;
  final String Function(OsDailyExpenseModel) categoryLabel;
  final String Function(String) paidByLabel;
  final NumberFormat money;
  final String currency;
  final void Function(OsDailyExpenseModel) onEdit;
  final void Function(OsDailyExpenseModel) onDelete;
  final void Function(OsDailyExpenseModel) onReceipt;

  static const _tableMinWidth = 1280.0;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return AppDataTable(
      minWidth: _tableMinWidth,
      columnSpacing: 20,
      horizontalMargin: 16,
      dataRowMinHeight: 72,
      dataRowMaxHeight: 88,
      columns: [
        appDataColumn(context, AppLocaleKeys.osExpensesColReceipt.tr),
        appDataColumn(context, AppLocaleKeys.osExpensesColStatement.tr),
        appDataColumn(context, AppLocaleKeys.osExpensesCategory.tr),
        appDataColumn(context, AppLocaleKeys.osExpensesColVendor.tr),
        appDataColumn(context, AppLocaleKeys.osExpensesAmount.tr),
        appDataColumn(context, AppLocaleKeys.osExpensesColDatetime.tr),
        appDataColumn(context, AppLocaleKeys.osExpensesColResponsible.tr),
        appDataColumn(context, AppLocaleKeys.osExpensesPaymentMethod.tr),
        appDataColumn(context, AppLocaleKeys.osCommonActions.tr),
      ],
                rows: [
                  for (final e in expenses)
                    DataRow(
                      cells: [
                        DataCell(
                          TableCellCenter(
                            child: e.hasReceipt
                                ? InkWell(
                                    onTap: () => onReceipt(e),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SafeNetworkImage(
                                        e.receiptImageUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _AttachThumb(
                                          onTap: () => onEdit(e),
                                        ),
                                      ),
                                    ),
                                  )
                                : _AttachThumb(onTap: () => onEdit(e)),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 240),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    e.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                  if (e.receiptNumber != null &&
                                      e.receiptNumber!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.inputFill,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#${e.receiptNumber}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.secondaryText,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                categoryLabel(e),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.accentText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: (e.vendor == null || e.vendor!.isEmpty)
                                ? Text(AppLocaleKeys.osCommonDash.tr)
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.storefront_outlined,
                                        size: 14,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(child: Text(e.vendor!)),
                                    ],
                                  ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Text.rich(
                              TextSpan(
                                text: money.format(e.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: theme.primaryText,
                                ),
                                children: [
                                  TextSpan(
                                    text: ' $currency',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: theme.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(e.date),
                                if (e.time.isNotEmpty)
                                  Text(
                                    e.time,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.mutedText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: Color(0xFF3B82F6),
                                ),
                                const SizedBox(width: 6),
                                Text(paidByLabel(e.paidBy)),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.inputFill,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                e.paymentMethod,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.secondaryText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          TableCellCenter(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (e.hasReceipt)
                                  IconButton(
                                    tooltip: AppLocaleKeys
                                        .osExpensesReceiptView.tr,
                                    onPressed: () => onReceipt(e),
                                    icon: Icon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                      color: theme.accentText,
                                    ),
                                  ),
                                IconButton(
                                  onPressed: () => onEdit(e),
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: theme.secondaryText,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => onDelete(e),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Color(0xFFF43F5E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
    );
  }
}

class _AttachThumb extends StatelessWidget {
  const _AttachThumb({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 16, color: theme.mutedText),
            Text(
              AppLocaleKeys.osExpensesAttachReceipt.tr,
              style: TextStyle(fontSize: 9, color: theme.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensesGrid extends StatelessWidget {
  const _ExpensesGrid({
    required this.expenses,
    required this.categoryLabel,
    required this.paidByLabel,
    required this.money,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
    required this.onReceipt,
  });

  final List<OsDailyExpenseModel> expenses;
  final String Function(OsDailyExpenseModel) categoryLabel;
  final String Function(String) paidByLabel;
  final NumberFormat money;
  final String currency;
  final void Function(OsDailyExpenseModel) onEdit;
  final void Function(OsDailyExpenseModel) onDelete;
  final void Function(OsDailyExpenseModel) onReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1000
            ? 3
            : constraints.maxWidth > 640
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: expenses.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: 360,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, i) {
            final e = expenses[i];
            return Container(
              decoration: BoxDecoration(
                color: theme.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (e.hasReceipt)
                    SizedBox(
                      height: 160,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          InkWell(
                            onTap: () => onReceipt(e),
                            child: SafeNetworkImage(
                              e.receiptImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: theme.inputFill,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: theme.mutedText,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black87,
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.visibility_outlined,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocaleKeys.osExpensesViewReceiptTap.tr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (e.receiptNumber != null &&
                              e.receiptNumber!.isNotEmpty)
                            PositionedDirectional(
                              top: 8,
                              start: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#${e.receiptNumber}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    InkWell(
                      onTap: () => onEdit(e),
                      child: Container(
                        height: 112,
                        color: theme.inputFill.withValues(alpha: 0.5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 24,
                              color: theme.mutedText,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLocaleKeys.osExpensesCaptureOrUpload.tr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                categoryLabel(e),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.accentText,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              e.date,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.mutedText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: theme.primaryText,
                          ),
                        ),
                        if (e.vendor != null && e.vendor!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.storefront_outlined,
                                size: 13,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.vendor!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text.rich(
                              TextSpan(
                                text: money.format(e.amount),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: theme.primaryText,
                                ),
                                children: [
                                  TextSpan(
                                    text: ' $currency',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: theme.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.inputFill,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                e.paymentMethod,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: theme.inputFill.withValues(alpha: 0.55),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            paidByLabel(e.paidBy),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.secondaryText,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => onEdit(e),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: theme.secondaryText,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: () => onDelete(e),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Color(0xFFF43F5E),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
