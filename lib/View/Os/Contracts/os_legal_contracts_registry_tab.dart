import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_card.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_form_dialog.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_preview_dialog.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_kpi_card.dart';
import 'package:point/View/Os/os_list_filters.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsLegalContractsRegistryTab extends StatefulWidget {
  const OsLegalContractsRegistryTab({super.key});

  @override
  State<OsLegalContractsRegistryTab> createState() =>
      _OsLegalContractsRegistryTabState();
}

class _OsLegalContractsRegistryTabState
    extends State<OsLegalContractsRegistryTab> {
  final _search = TextEditingController();
  var _statusFilter = 'ALL';
  var _targetFilter = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtersActive =>
      _statusFilter != 'ALL' ||
      _targetFilter != 'ALL' ||
      _search.text.trim().isNotEmpty;

  Future<void> _delete(
    BuildContext context,
    OsLegalContractsController ctrl,
    OsLegalContractModel contract,
  ) async {
    final confirmed = await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: AppLocaleKeys.osLegalContractDeleteConfirm.trParams({
        'number': contract.contractNumber,
      }),
      onTap: () => ctrl.deleteContract(contract.id),
    );
    if (confirmed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OsSnackbar.success(
          AppLocaleKeys.osLegalContractTitle.tr,
          AppLocaleKeys.osLegalContractDeleted.tr,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final ctrl = Get.find<OsLegalContractsController>();

    return Obx(() {
      final all = ctrl.contracts.toList();
      final list = ctrl.filtered(
        query: _search.text,
        statusFilter: _statusFilter,
        targetFilter: _targetFilter,
      );

      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.crossAxisExtent >= 900;
                final cross = wide ? 4 : 2;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: wide ? 2.5 : 2.1,
                  ),
                  delegate: SliverChildListDelegate.fixed([
                    OsKpiCard(
                      title: AppLocaleKeys.osLegalContractKpiTotal.tr,
                      value: '${all.length}',
                      color: theme.primaryText,
                    ),
                    OsKpiCard(
                      title: AppLocaleKeys.osLegalContractKpiActive.tr,
                      value:
                          '${ctrl.countByStatus(OsLegalContractStatus.active)}',
                      color: const Color(0xFF059669),
                    ),
                    OsKpiCard(
                      title: AppLocaleKeys.osLegalContractKpiPending.tr,
                      value:
                          '${ctrl.countByStatus(OsLegalContractStatus.pendingSignature)}',
                      color: const Color(0xFFD97706),
                    ),
                    OsKpiCard(
                      title: AppLocaleKeys.osLegalContractKpiValue.tr,
                      value: OsFinanceFormat.money(ctrl.activeValueIqd()),
                      color: AppColors.primary,
                    ),
                  ]),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: OsListFilterBar(
              chips: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OsFilterChips(
                    value: _statusFilter,
                    onChanged: (v) => setState(() => _statusFilter = v),
                    options: [
                      OsFilterChipOption(
                        value: 'ALL',
                        label: AppLocaleKeys.osCommonFilterAll.tr,
                      ),
                      ...OsLegalContractStatus.ordered.map(
                        (s) => OsFilterChipOption(
                          value: s,
                          label: osLegalContractStatusLabel(s),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OsFilterChips(
                    value: _targetFilter,
                    onChanged: (v) => setState(() => _targetFilter = v),
                    options: [
                      OsFilterChipOption(
                        value: 'ALL',
                        label: AppLocaleKeys.osLegalContractFilterAllTypes.tr,
                      ),
                      ...OsLegalContractTargetType.ordered.map(
                        (t) => OsFilterChipOption(
                          value: t,
                          label: osLegalContractTargetLabel(t),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              search: OsSearchField(
                controller: _search,
                hint: AppLocaleKeys.osLegalContractSearch.tr,
                onChanged: (_) => setState(() {}),
              ),
              matchCount: all.isEmpty ? null : list.length,
            ),
          ),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      all.isEmpty
                          ? AppLocaleKeys.osLegalContractEmpty.tr
                          : AppLocaleKeys.osLegalContractEmptyFilter.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.mutedText,
                      ),
                    ),
                    if (!_filtersActive) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            showOsLegalContractFormDialog(context),
                        style: OsButtonStyles.primaryCompact(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(AppLocaleKeys.osLegalContractAdd.tr),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final c = list[i];
                  return OsLegalContractCard(
                    contract: c,
                    onView: () => showOsLegalContractPreviewDialog(
                      context,
                      c,
                      onEdit: () => showOsLegalContractFormDialog(
                        context,
                        existing: c,
                      ),
                    ),
                    onEdit: () =>
                        showOsLegalContractFormDialog(context, existing: c),
                    onDelete: () => _delete(context, ctrl, c),
                  );
                },
              ),
            ),
        ],
      );
    });
  }
}
