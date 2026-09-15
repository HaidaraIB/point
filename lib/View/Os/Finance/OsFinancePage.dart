import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsBankAccountModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/os_finance_tab_persistence.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Finance/os_voucher_detail_panel.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_list_filters.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

class OsFinancePage extends StatefulWidget {
  const OsFinancePage({super.key});

  @override
  State<OsFinancePage> createState() => _OsFinancePageState();
}

class _OsFinancePageState extends State<OsFinancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  var _restoringPrefs = false;

  @override
  void initState() {
    super.initState();
    final initial = OsFinanceTabPersistence.indexFromRoute();
    _tabs = TabController(length: 3, vsync: this, initialIndex: initial);
    _tabs.addListener(_onTabChanged);
    if (!OsFinanceTabPersistence.hasRouteTab()) {
      _restoreSavedTab();
    } else {
      OsFinanceTabPersistence.saveIndex(initial);
    }
  }

  Future<void> _restoreSavedTab() async {
    final saved = await OsFinanceTabPersistence.loadSavedIndex();
    if (!mounted || saved == _tabs.index) return;
    _restoringPrefs = true;
    _tabs.index = saved;
    _restoringPrefs = false;
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging || _restoringPrefs) return;
    OsFinanceTabPersistence.saveIndex(_tabs.index);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessOsSection(emp)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    final theme = context.appTheme;

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osFinanceTitle.tr,
            subtitle: AppLocaleKeys.osFinanceSubtitle.tr,
            currentRoute: '/os/finance',
          ),
          Material(
            color: theme.cardSurface,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.accentText,
              unselectedLabelColor: theme.mutedText,
              indicatorColor: AppColors.primary,
              labelPadding: const EdgeInsets.symmetric(horizontal: 18),
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              tabs: [
                Tab(text: AppLocaleKeys.osFinanceOverview.tr),
                Tab(text: AppLocaleKeys.osFinanceAccounts.tr),
                Tab(text: AppLocaleKeys.osFinanceVouchers.tr),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _OverviewTab(),
                _AccountsTab(),
                _VouchersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final finance = Get.find<OsFinanceController>();

    return Obx(() {
      final liquidity = finance.totalLiquidity;
      final incoming = finance.totalIncoming;
      final outgoing = finance.totalOutgoing;
      final accountCount = finance.bankAccounts.length;
      final accounts = finance.bankAccounts.toList();

      final coveredInvoiceIds = <String>{
        for (final v in finance.vouchers)
          if ((v.invoiceId ?? '').trim().isNotEmpty) v.invoiceId!.trim(),
      };

      final recent = <_ActivityItem>[
        for (final v in finance.vouchers)
          () {
            final desc = OsFinanceFormat.displayDescription(v.description);
            final party = v.payeeOrPayer;
            final isReceipt = v.type == OsVoucherType.receipt;
            return _ActivityItem(
              id: v.id ?? '',
              date: v.date,
              amount: v.amount,
              isIn: isReceipt,
              accountName: finance.accountById(v.bankAccountId)?.name ??
                  AppLocaleKeys.osFinanceUnknownAccount.tr,
              description: desc.isEmpty
                  ? party
                  : (isReceipt
                          ? AppLocaleKeys.osFinanceActivityReceipt
                          : AppLocaleKeys.osFinanceActivityPayment)
                      .trParams({'party': party, 'desc': desc}),
            );
          }(),
        for (final inv in finance.invoices.where((i) => i.isPaid))
          if (!coveredInvoiceIds.contains(inv.id))
            _ActivityItem(
              id: inv.id ?? '',
              date: inv.date,
              amount: inv.total,
              isIn: true,
              accountName: finance.accountById(inv.bankAccountId)?.name ??
                  AppLocaleKeys.osFinanceUnknownAccount.tr,
              description: AppLocaleKeys.osFinanceActivityInvoice.trParams({
                'client': inv.clientName,
              }),
            ),
      ]..sort((a, b) => b.date.compareTo(a.date));
      final recentSlice = recent.take(6).toList();

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              const cardHeight = 360.0;
              final liquidityCard = _LiquidityCard(
                liquidity: liquidity,
                accountCount: accountCount,
                incoming: incoming,
                outgoing: outgoing,
                accounts: accounts,
              );
              final recentCard = _RecentCard(items: recentSlice);
              if (wide) {
                return SizedBox(
                  height: cardHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: liquidityCard),
                      const SizedBox(width: 16),
                      Expanded(child: recentCard),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  SizedBox(height: cardHeight, child: liquidityCard),
                  const SizedBox(height: 16),
                  SizedBox(height: cardHeight, child: recentCard),
                ],
              );
            },
          ),
        ],
      );
    });
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.id,
    required this.date,
    required this.amount,
    required this.isIn,
    required this.accountName,
    required this.description,
  });

  final String id;
  final String date;
  final double amount;
  final bool isIn;
  final String accountName;
  final String description;
}

class _LiquidityCard extends StatelessWidget {
  const _LiquidityCard({
    required this.liquidity,
    required this.accountCount,
    required this.incoming,
    required this.outgoing,
    required this.accounts,
  });

  final double liquidity;
  final int accountCount;
  final double incoming;
  final double outgoing;
  final List<OsBankAccountModel> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleKeys.osFinanceLiquidity.tr,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            OsFinanceFormat.money(liquidity),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: theme.accentText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocaleKeys.osFinanceLiquidityCalc.tr,
            style: TextStyle(fontSize: 11, color: theme.secondaryText),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocaleKeys.osFinanceLiquidityHint
                .trParams({'count': '$accountCount'}),
            style: TextStyle(fontSize: 12, color: theme.secondaryText),
          ),
          if (accounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final a = accounts[i];
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        OsFinanceFormat.money(a.balance),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.accentText,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: AppLocaleKeys.osFinanceIncoming.tr,
                  value: OsFinanceFormat.money(incoming),
                  color: (Theme.of(context).brightness == Brightness.dark)
                      ? const Color(0xFF4ADE80)
                      : Colors.green,
                  icon: Icons.arrow_upward,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: AppLocaleKeys.osFinanceOutgoing.tr,
                  value: OsFinanceFormat.money(outgoing),
                  color: (Theme.of(context).brightness == Brightness.dark)
                      ? const Color(0xFFF87171)
                      : Colors.redAccent,
                  icon: Icons.arrow_downward,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.items});

  final List<_ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.history, size: 20, color: theme.accentText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleKeys.osFinanceRecent.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      AppLocaleKeys.osFinanceEmptyActivity.tr,
                      style: TextStyle(color: theme.secondaryText),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final tone = item.isIn
                          ? ((Theme.of(context).brightness == Brightness.dark)
                              ? const Color(0xFF4ADE80)
                              : Colors.green)
                          : ((Theme.of(context).brightness == Brightness.dark)
                              ? const Color(0xFFF87171)
                              : Colors.redAccent);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tone.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.history,
                                size: 18,
                                color: tone,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.accountName} · ${item.date}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${item.isIn ? '+' : '-'}${OsFinanceFormat.money(item.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: tone,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccountsTab extends StatefulWidget {
  const _AccountsTab();

  @override
  State<_AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<_AccountsTab> {
  final _search = TextEditingController();
  var _type = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<OsBankAccountModel> _filtered(List<OsBankAccountModel> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((a) {
      if (_type != 'ALL' && a.type != _type) return false;
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    OsFinanceController finance,
    OsBankAccountModel a,
  ) async {
    if (a.id == null) return;
    final hasBalance = a.balance.abs() > 0.0001;
    final linked = finance.vouchers.any((v) => v.bankAccountId == a.id);
    final message = (hasBalance || linked)
        ? AppLocaleKeys.osAccountsDeletePostedConfirm.tr
        : AppLocaleKeys.osAccountsDeleteConfirm.tr;
    await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: message,
      onTap: () => finance.deleteBankAccount(a.id!),
    );
  }

  Future<void> _openForm(
    BuildContext context, {
    OsBankAccountModel? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final existingNumber = existing?.accountNumber.trim() ?? '';
    final numberCtrl = TextEditingController(
      text: (existingNumber.isEmpty ||
              existingNumber == OsBankAccountType.unsetNumber)
          ? ''
          : existingNumber,
    );
    final balanceCtrl = TextEditingController(
      text: existing == null ? '0' : existing.balance.toString(),
    );
    var type = existing?.type ?? OsBankAccountType.bank;

    final saved = await showOsFormDialog(
      context: context,
      title: existing == null
          ? AppLocaleKeys.osAccountsAddTitle.tr
          : AppLocaleKeys.osAccountsEdit.tr,
      titleIcon: Icons.account_balance,
      saveLabel: AppLocaleKeys.osAccountsSaveFull.tr,
      builder: (context, setLocal) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(type),
              initialValue: type,
              decoration: osFinanceFieldDecoration(
                AppLocaleKeys.osAccountsType.tr,
              ),
              items: [
                for (final t in OsBankAccountType.all)
                  DropdownMenuItem(
                    value: t,
                    child: Text(OsFinanceFormat.accountTypeLabel(t)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setLocal(() => type = v);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(fontSize: 16),
              decoration: osFinanceFieldDecoration(
                AppLocaleKeys.osAccountsName.tr,
                hint: AppLocaleKeys.osAccountsNameHint.tr,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: numberCtrl,
              style: const TextStyle(fontSize: 16),
              textDirection: TextDirection.ltr,
              decoration: osFinanceFieldDecoration(
                AppLocaleKeys.osAccountsNumber.tr,
                hint: AppLocaleKeys.osAccountsNumberHint.tr,
              ),
            ),
            if (existing == null) ...[
              const SizedBox(height: 14),
              TextField(
                controller: balanceCtrl,
                style: const TextStyle(fontSize: 16),
                keyboardType: TextInputType.number,
                decoration: osFinanceFieldDecoration(
                  AppLocaleKeys.osAccountsBalance.tr,
                ),
              ),
            ],
          ],
        );
      },
    );

    if (saved != true) {
      nameCtrl.dispose();
      numberCtrl.dispose();
      balanceCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final number = numberCtrl.text.trim().isEmpty
        ? OsFinanceFormat.unsetAccountNumber
        : numberCtrl.text.trim();
    final balance =
        existing?.balance ?? (double.tryParse(balanceCtrl.text.trim()) ?? 0);
    nameCtrl.dispose();
    numberCtrl.dispose();
    balanceCtrl.dispose();

    if (name.isEmpty) return;

    final model = OsBankAccountModel(
      id: existing?.id,
      name: name,
      accountNumber: number,
      balance: balance,
      type: type,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    final ok = await Get.find<OsFinanceController>().saveBankAccount(model);
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osFinanceAccounts.tr,
        AppLocaleKeys.osAccountsSaved.tr,
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osFinanceAccounts.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
    }
  }

  Future<void> _openTransfer(BuildContext context) async {
    final finance = Get.find<OsFinanceController>();
    if (finance.bankAccounts.length < 2) {
      OsSnackbar.error(
        AppLocaleKeys.osAccountsTransfer.tr,
        AppLocaleKeys.osVouchersErrorAccountRequired.tr,
      );
      return;
    }

    String? sourceId = finance.bankAccounts.first.id;
    String? destId = finance.bankAccounts.length > 1
        ? finance.bankAccounts[1].id
        : finance.bankAccounts.first.id;
    final amountCtrl = TextEditingController();

    final saved = await showOsFormDialog(
      context: context,
      title: AppLocaleKeys.osAccountsTransferTitle.tr,
      builder: (context, setLocal) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('src-$sourceId'),
              initialValue: sourceId,
              decoration: osFinanceFieldDecoration(
                AppLocaleKeys.osAccountsTransferSource.tr,
              ),
              items: [
                for (final a in finance.bankAccounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setLocal(() => sourceId = v),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('dst-$destId'),
              initialValue: destId,
              decoration: osFinanceFieldDecoration(
                AppLocaleKeys.osAccountsTransferDest.tr,
              ),
              items: [
                for (final a in finance.bankAccounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setLocal(() => destId = v),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              style: const TextStyle(fontSize: 16),
              keyboardType: TextInputType.number,
              decoration: osFinanceFieldDecoration(
                AppLocaleKeys.osAccountsTransferAmount.tr,
              ),
            ),
          ],
        );
      },
    );

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    amountCtrl.dispose();
    if (saved != true) return;
    if (sourceId == null || destId == null) return;

    final source = finance.accountById(sourceId);
    final dest = finance.accountById(destId);
    if (source == null || dest == null) return;

    try {
      final ok = await finance.transferBetweenAccounts(
        sourceAccountId: sourceId!,
        destAccountId: destId!,
        amount: amount,
        paymentDescription: AppLocaleKeys.osAccountsTransferOutDesc
            .trParams({'name': dest.name}),
        receiptDescription: AppLocaleKeys.osAccountsTransferInDesc
            .trParams({'name': source.name}),
      );
      if (ok) {
        OsSnackbar.success(
          AppLocaleKeys.osAccountsTransfer.tr,
          AppLocaleKeys.osAccountsTransferSaved.tr,
        );
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osAccountsTransfer.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
      }
    } on OsFinanceException catch (e) {
      OsSnackbar.error(AppLocaleKeys.osAccountsTransfer.tr, e.messageKey.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = Get.find<OsFinanceController>();
    final theme = context.appTheme;

    return Obx(() {
      final accounts = finance.bankAccounts.toList();
      final filtered = _filtered(accounts);
      return Column(
        children: [
          OsListFilterBar(
            chips: OsFilterChips(
              value: _type,
              onChanged: (v) => setState(() => _type = v),
              options: [
                OsFilterChipOption(
                  value: 'ALL',
                  label: AppLocaleKeys.osCommonFilterAll.tr,
                ),
                for (final t in OsBankAccountType.all)
                  OsFilterChipOption(
                    value: t,
                    label: OsFinanceFormat.accountTypeLabel(t),
                  ),
              ],
            ),
            search: OsSearchField(
              controller: _search,
              hint: AppLocaleKeys.osAccountsSearch.tr,
              onChanged: (_) => setState(() {}),
            ),
            matchCount: accounts.isEmpty ? null : filtered.length,
            actions: [
              FilledButton.icon(
                onPressed: () => _openTransfer(context),
                style: OsButtonStyles.secondaryCompact(theme),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(AppLocaleKeys.osAccountsTransfer.tr),
              ),
              FilledButton.icon(
                onPressed: () => _openForm(context),
                style: OsButtonStyles.primaryCompact(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocaleKeys.osAccountsAdd.tr),
              ),
            ],
          ),
          Expanded(
            child: filtered.isEmpty
                ? OsEmptyState(
                    message: accounts.isEmpty
                        ? AppLocaleKeys.osAccountsEmpty.tr
                        : AppLocaleKeys.osAccountsEmptyFilter.tr,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 640;
                      if (narrow) {
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _AccountCard(
                              account: filtered[index],
                              onEdit: () => _openForm(
                                context,
                                existing: filtered[index],
                              ),
                              onDelete: () => _confirmDeleteAccount(
                                context,
                                finance,
                                filtered[index],
                              ),
                            );
                          },
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        gridDelegate: const SoftGridDelegate(
                          maxCrossAxisExtent: 360,
                          mainAxisExtent: 248,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final a = filtered[index];
                          return _AccountCard(
                            account: a,
                            onEdit: () => _openForm(context, existing: a),
                            onDelete: () => _confirmDeleteAccount(
                              context,
                              finance,
                              a,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.onDelete,
  });

  final OsBankAccountModel account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final a = account;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.accentText.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  a.type == OsBankAccountType.cash
                      ? Icons.payments_outlined
                      : a.type == OsBankAccountType.vault
                          ? Icons.account_balance_wallet
                          : Icons.account_balance,
                  color: theme.accentText,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            OsFinanceFormat.accountNumberLabel(a.accountNumber),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppLocaleKeys.osAccountsBalanceAvailable.tr,
            style: TextStyle(
              fontSize: 11,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            OsFinanceFormat.money(a.balance),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: theme.accentText,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.accentText.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                OsFinanceFormat.accountTypeLabel(a.type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.accentText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive grid with configurable row height.
class SoftGridDelegate extends SliverGridDelegateWithMaxCrossAxisExtent {
  const SoftGridDelegate({
    required super.maxCrossAxisExtent,
    double mainAxisExtent = 248,
  }) : super(
          mainAxisExtent: mainAxisExtent,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        );
}

class _VouchersTab extends StatefulWidget {
  const _VouchersTab();

  @override
  State<_VouchersTab> createState() => _VouchersTabState();
}

class _VouchersTabState extends State<_VouchersTab> {
  final _searchCtrl = TextEditingController();
  String _typeFilter = 'ALL';
  String? _selectedId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreate(BuildContext context) async {
    final finance = Get.find<OsFinanceController>();
    if (finance.bankAccounts.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osFinanceVouchers.tr,
        AppLocaleKeys.osVouchersErrorAccountRequired.tr,
      );
      return;
    }

    final payeeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var type = OsVoucherType.receipt;
    String? accountId = finance.bankAccounts.first.id;
    var date = DateTime.now();

    final saved = await showOsFormDialog(
      context: context,
      title: AppLocaleKeys.osVouchersAddTitle.tr,
      titleIcon: Icons.description_outlined,
      saveLabel: AppLocaleKeys.osVouchersSaveFull.tr,
      saveIcon: Icons.receipt_long,
      builder: (context, setLocal) {
        final payeeLabel = type == OsVoucherType.payment
            ? AppLocaleKeys.osVouchersPayeePayment.tr
            : AppLocaleKeys.osVouchersPayeeReceipt.tr;
        final typeField = DropdownButtonFormField<String>(
          key: ValueKey(type),
          initialValue: type,
          isExpanded: true,
          decoration: osFinanceFieldDecoration(
            AppLocaleKeys.osVouchersType.tr,
          ),
          items: [
            DropdownMenuItem(
              value: OsVoucherType.receipt,
              child: Text(
                AppLocaleKeys.osVouchersTypeReceiptFull.tr,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: OsVoucherType.payment,
              child: Text(
                AppLocaleKeys.osVouchersTypePaymentFull.tr,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (v) {
            if (v != null) setLocal(() => type = v);
          },
        );
        final accountField = DropdownButtonFormField<String>(
          key: ValueKey(accountId),
          initialValue: accountId,
          isExpanded: true,
          decoration: osFinanceFieldDecoration(
            AppLocaleKeys.osVouchersAccount.tr,
            hint: AppLocaleKeys.osVouchersAccountHint.tr,
          ),
          items: [
            for (final a in finance.bankAccounts)
              DropdownMenuItem(
                value: a.id,
                child: Text(a.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setLocal(() => accountId = v),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 420;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stacked) ...[
                  typeField,
                  const SizedBox(height: 14),
                  accountField,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: typeField),
                      const SizedBox(width: 12),
                      Expanded(child: accountField),
                    ],
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  style: const TextStyle(fontSize: 16),
                  keyboardType: TextInputType.number,
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osVouchersAmountLabel.tr,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: payeeCtrl,
                  style: const TextStyle(fontSize: 16),
                  decoration: osFinanceFieldDecoration(
                    payeeLabel,
                    hint: AppLocaleKeys.osVouchersPayeeHint.tr,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(fontSize: 16),
                  maxLines: 2,
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osVouchersDescription.tr,
                    hint: AppLocaleKeys.osVouchersDescriptionHint.tr,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    final payee = payeeCtrl.text.trim();
    final desc = descCtrl.text.trim();
    payeeCtrl.dispose();
    descCtrl.dispose();
    amountCtrl.dispose();

    if (saved != true) return;
    if (accountId == null || accountId!.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osFinanceVouchers.tr,
        AppLocaleKeys.osVouchersErrorAccountRequired.tr,
      );
      return;
    }

    try {
      final ok = await finance.createVoucher(
        OsVoucherModel(
          type: type,
          amount: amount,
          date: OsFinanceFormat.ymd(date),
          payeeOrPayer: payee,
          description: desc,
          bankAccountId: accountId!,
          source: OsVoucherSource.manual,
          createdAt: DateTime.now(),
        ),
      );
      if (ok) {
        OsSnackbar.success(
          AppLocaleKeys.osFinanceVouchers.tr,
          AppLocaleKeys.osVouchersSaved.tr,
        );
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osFinanceVouchers.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
      }
    } on OsFinanceException catch (e) {
      OsSnackbar.error(AppLocaleKeys.osFinanceVouchers.tr, e.messageKey.tr);
    }
  }

  List<OsVoucherModel> _filtered(List<OsVoucherModel> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((v) {
      final matchType = _typeFilter == 'ALL' || v.type == _typeFilter;
      if (!matchType) return false;
      if (q.isEmpty) return true;
      return v.payeeOrPayer.toLowerCase().contains(q) ||
          v.description.toLowerCase().contains(q) ||
          OsFinanceFormat.voucherRef(v).toLowerCase().contains(q) ||
          (v.id ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmDeleteVoucher(OsVoucherModel voucher) async {
    final message = voucher.isManuallyDeletable
        ? AppLocaleKeys.osVouchersDeleteConfirm.tr
        : AppLocaleKeys.osVouchersDeletePostedConfirm.tr;
    await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osVouchersDelete.tr,
      message: message,
      onTap: () => _deleteVoucher(voucher),
    );
  }

  Future<void> _deleteVoucher(OsVoucherModel voucher) async {
    final id = voucher.id?.trim() ?? '';
    if (id.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osFinanceVouchers.tr,
        AppLocaleKeys.osVouchersErrorMissingId.tr,
      );
      return;
    }
    final finance = Get.find<OsFinanceController>();
    try {
      final ok = await finance.deleteVoucher(id);
      if (!mounted) return;
      if (ok) {
        setState(() => _selectedId = null);
        OsSnackbar.success(
          AppLocaleKeys.osFinanceVouchers.tr,
          AppLocaleKeys.osVouchersDeleted.tr,
        );
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osFinanceVouchers.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
      }
    } on OsFinanceException catch (e) {
      OsSnackbar.error(AppLocaleKeys.osFinanceVouchers.tr, e.messageKey.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = Get.find<OsFinanceController>();
    final theme = context.appTheme;

    return Obx(() {
      final filtered = _filtered(finance.vouchers.toList());
      final selected = filtered.cast<OsVoucherModel?>().firstWhere(
            (v) => v?.id == _selectedId,
            orElse: () => filtered.isEmpty ? null : filtered.first,
          );

      return Column(
        children: [
          OsTabToolbar(
            asCard: true,
            icon: Icons.description_outlined,
            title: AppLocaleKeys.osVouchersBookTitle.tr,
            subtitle: AppLocaleKeys.osVouchersSubtitle.tr,
            actions: [
              FilledButton.icon(
                onPressed: () => _openCreate(context),
                style: OsButtonStyles.primaryCompact(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocaleKeys.osVouchersIssueNew.tr),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in const [
                          'ALL',
                          OsVoucherType.receipt,
                          OsVoucherType.payment,
                        ])
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text(
                                f == 'ALL'
                                    ? AppLocaleKeys.osVouchersTypeAll.tr
                                    : OsFinanceFormat.voucherTypeLabel(f),
                              ),
                              selected: _typeFilter == f,
                              onSelected: (_) =>
                                  setState(() => _typeFilter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: AppLocaleKeys.osVouchersSearch.tr,
                      hintMaxLines: 1,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                AppLocaleKeys.osVouchersMatchCount
                    .trParams({'count': '${filtered.length}'}),
                style: TextStyle(fontSize: 12, color: theme.mutedText),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? OsEmptyState(
                    message: finance.vouchers.isEmpty
                        ? AppLocaleKeys.osVouchersEmpty.tr
                        : AppLocaleKeys.osVouchersEmptyFilter.tr,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final split = constraints.maxWidth >= 980;
                      final list = _VoucherMasterList(
                        vouchers: filtered,
                        selectedId: selected?.id,
                        accountName: (id) =>
                            finance.accountById(id)?.name ??
                            AppLocaleKeys.osFinanceUnknownAccount.tr,
                        onSelect: (id) => setState(() => _selectedId = id),
                      );
                      final detail = selected == null
                          ? OsEmptyState(
                              message: AppLocaleKeys.osVouchersSelectHint.tr,
                            )
                          : SingleChildScrollView(
                              // Directional: outer edge stays 20 in both LTR and RTL.
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                0,
                                0,
                                20,
                                24,
                              ),
                              child: OsVoucherDetailPanel(
                                voucher: selected,
                                accountName: finance
                                        .accountById(selected.bankAccountId)
                                        ?.name ??
                                    AppLocaleKeys.osFinanceUnknownAccount.tr,
                                onDelete: () =>
                                    _confirmDeleteVoucher(selected),
                              ),
                            );

                      if (!split) {
                        return ListView(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            20,
                            0,
                            20,
                            24,
                          ),
                          children: [
                            SizedBox(height: 320, child: list),
                            const SizedBox(height: 16),
                            detail,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 360,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                20,
                                0,
                                10,
                                24,
                              ),
                              child: list,
                            ),
                          ),
                          Expanded(child: detail),
                        ],
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

class _VoucherMasterList extends StatelessWidget {
  const _VoucherMasterList({
    required this.vouchers,
    required this.selectedId,
    required this.accountName,
    required this.onSelect,
  });

  final List<OsVoucherModel> vouchers;
  final String? selectedId;
  final String Function(String id) accountName;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final chipTone = (Theme.of(context).brightness == Brightness.dark)
        ? const Color(0xFF4ADE80)
        : Colors.green;
    final payTone = (Theme.of(context).brightness == Brightness.dark)
        ? const Color(0xFFF87171)
        : Colors.redAccent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: ListView.separated(
          itemCount: vouchers.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: theme.border),
          itemBuilder: (context, index) {
            final v = vouchers[index];
            final selected = v.id == selectedId;
            final typeTone =
                v.type == OsVoucherType.receipt ? chipTone : payTone;
            final desc = OsFinanceFormat.displayDescription(v.description);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(v.id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.accentText.withValues(alpha: 0.1)
                        : null,
                    border: BorderDirectional(
                      start: BorderSide(
                        width: 3,
                        color: selected
                            ? theme.accentText
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              OsFinanceFormat.voucherRef(v),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: theme.accentText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              color: typeTone.withValues(alpha: 0.15),
                              child: Text(
                                OsFinanceFormat.voucherTypeLabel(v.type),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: typeTone,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              v.payeeOrPayer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            OsFinanceFormat.money(v.amount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: theme.primaryText,
                            ),
                          ),
                        ],
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${accountName(v.bankAccountId)} · ${v.date}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
