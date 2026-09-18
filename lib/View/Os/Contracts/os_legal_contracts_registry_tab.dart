import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_card.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_form_dialog.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_preview_dialog.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
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
    final ctrl = Get.find<OsLegalContractsController>();

    return Obx(() {
      final all = ctrl.contracts.toList();
      final list = ctrl.filtered(
        query: _search.text,
        statusFilter: _statusFilter,
        targetFilter: _targetFilter,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsListFilterBar(
            leading: OsFilterChips(
              value: _targetFilter,
              onChanged: (v) => setState(() => _targetFilter = v),
              options: [
                OsFilterChipOption(
                  value: 'ALL',
                  label: AppLocaleKeys.osLegalContractFilterAllTypes.tr,
                ),
                for (final t in OsLegalContractTargetType.ordered)
                  OsFilterChipOption(
                    value: t,
                    label: osLegalContractTargetLabel(t),
                    color: osLegalContractTargetColor(t),
                  ),
              ],
            ),
            chips: OsFilterChips(
              value: _statusFilter,
              onChanged: (v) => setState(() => _statusFilter = v),
              options: [
                OsFilterChipOption(
                  value: 'ALL',
                  label: AppLocaleKeys.osLegalContractFilterAllStatus.tr,
                ),
                for (final s in OsLegalContractStatus.filterOrdered)
                  OsFilterChipOption(
                    value: s,
                    label: osLegalContractStatusLabel(s),
                    color: osLegalContractStatusColor(s),
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
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OsEmptyState(
                          message: all.isEmpty
                              ? AppLocaleKeys.osLegalContractEmpty.tr
                              : AppLocaleKeys.osLegalContractEmptyNoMatch.tr,
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
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final cross = constraints.maxWidth >= 1100
                          ? 3
                          : constraints.maxWidth >= 720
                              ? 2
                              : 1;
                      const gap = 12.0;
                      final cardW =
                          (constraints.maxWidth - 32 - gap * (cross - 1)) /
                              cross;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final contract in list)
                              SizedBox(
                                width: cardW,
                                child: OsLegalContractCard(
                                  contract: contract,
                                  onView: () => showOsLegalContractPreviewDialog(
                                    context,
                                    contract,
                                  ),
                                  onEdit: () => showOsLegalContractFormDialog(
                                    context,
                                    existing: contract,
                                  ),
                                  onDelete: () =>
                                      _delete(context, ctrl, contract),
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
