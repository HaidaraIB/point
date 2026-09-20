import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsCrmController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/os_crm_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Crm/os_crm_labels.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/app_data_table.dart';
import 'package:point/View/Shared/responsive.dart';

/// CRM list view — reuses shared [AppDataTable] like invoices/contracts.
class OsCrmListView extends StatefulWidget {
  const OsCrmListView({
    super.key,
    required this.clients,
    required this.crm,
    required this.onTap,
    required this.onChangeStage,
  });

  final List<ClientModel> clients;
  final OsCrmController crm;
  final ValueChanged<String> onTap;
  final Future<void> Function(ClientModel client, String stage) onChangeStage;

  @override
  State<OsCrmListView> createState() => _OsCrmListViewState();
}

class _OsCrmListViewState extends State<OsCrmListView> {
  final _selectedIds = <String>{};
  String? _bulkStage;

  List<String> get _clientIds => widget.clients
      .map((c) => c.id)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toList();

  bool get _allSelected =>
      _clientIds.isNotEmpty && _selectedIds.length == _clientIds.length;

  bool? get _headerCheckboxValue {
    if (_selectedIds.isEmpty) return false;
    if (_allSelected) return true;
    return null;
  }

  void _toggleSelection(String id, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _toggleSelectAll(bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIds
          ..clear()
          ..addAll(_clientIds);
      } else {
        _selectedIds.clear();
        _bulkStage = null;
      }
    });
  }

  Future<void> _applyBulkStage() async {
    final stage = _bulkStage;
    if (stage == null || _selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ids = _selectedIds.toList();

    Future<void> apply() async {
      var ok = 0;
      for (final id in ids) {
        if (await widget.crm.updateStage(id, stage)) ok++;
      }
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _bulkStage = null;
      });
      if (ok > 0) {
        OsSnackbar.success(
          AppLocaleKeys.osCrmSaved.tr,
          AppLocaleKeys.osCrmBulkSelected.trParams({'count': '$ok'}),
        );
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osCommonSaveFailed.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
      }
    }

    if (stage == OsCrmStage.won) {
      await FunHelper.showConfirmDailog(
        context,
        title: AppLocaleKeys.osCrmConfirmWonTitle.tr,
        message:
            '${AppLocaleKeys.osCrmConfirmWonMessage.tr}\n\n'
            '${AppLocaleKeys.osCrmBulkSelected.trParams({'count': '$count'})}',
        confirmText: osCrmStageLabel(OsCrmStage.won),
        confirmColor: AppColors.primary,
        onTap: apply,
      );
      return;
    }
    if (stage == OsCrmStage.lost) {
      await FunHelper.showConfirmDailog(
        context,
        title: AppLocaleKeys.osCrmConfirmLostTitle.tr,
        message:
            '${AppLocaleKeys.osCrmConfirmLostMessage.tr}\n\n'
            '${AppLocaleKeys.osCrmBulkSelected.trParams({'count': '$count'})}',
        confirmText: osCrmStageLabel(OsCrmStage.lost),
        confirmColor: AppColors.caution,
        onTap: apply,
      );
      return;
    }
    await apply();
  }

  DataColumn _checkboxColumn() {
    return DataColumn(
      headingRowAlignment: MainAxisAlignment.center,
      label: Checkbox(
        value: _headerCheckboxValue,
        tristate: true,
        onChanged: _clientIds.isEmpty ? null : _toggleSelectAll,
      ),
    );
  }

  Widget _bulkBar(BuildContext context, AppThemeExtension theme) {
    final mobile = Responsive.isMobile(context);
    final dropdown = DropdownButtonFormField<String>(
      key: ValueKey(_bulkStage),
      initialValue: _bulkStage,
      isExpanded: true,
      decoration: osFinanceFieldDecoration(
        AppLocaleKeys.osCrmBulkMoveStage.tr,
      ),
      items: [
        for (final s in OsCrmStage.ordered)
          DropdownMenuItem(
            value: s,
            child: osCrmStageMenuItemLabel(s),
          ),
      ],
      onChanged: (v) => setState(() => _bulkStage = v),
    );

    final actions = [
      FilledButton(
        onPressed: _bulkStage == null ? null : _applyBulkStage,
        style: OsButtonStyles.primaryCompact(),
        child: Text(AppLocaleKeys.osCrmBulkApply.tr),
      ),
      TextButton(
        onPressed: () => setState(() {
          _selectedIds.clear();
          _bulkStage = null;
        }),
        child: Text(AppLocaleKeys.osCrmBulkClear.tr),
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocaleKeys.osCrmBulkSelected.trParams({
              'count': '${_selectedIds.length}',
            }),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          if (mobile) ...[
            dropdown,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: actions[0]),
                actions[1],
              ],
            ),
          ] else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              children: [
                SizedBox(width: 200, child: dropdown),
                ...actions,
              ],
            ),
        ],
      ),
    );
  }

  Widget _mobileList(BuildContext context, AppThemeExtension theme) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: widget.clients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = widget.clients[i];
        final stage = widget.crm.effectiveStage(c);
        final stageColor = osCrmStageColor(stage);
        final id = c.id;
        return Material(
          color: theme.cardSurface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: id == null ? null : () => widget.onTap(id),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (id != null)
                        Checkbox(
                          value: _selectedIds.contains(id),
                          onChanged: (selected) =>
                              _toggleSelection(id, selected),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.crm.displayCompany(c),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.name ?? AppLocaleKeys.osCommonDash.tr,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_left,
                        color: theme.mutedText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if ((c.phone ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        c.phone!,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.secondaryText,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OsCrmStageSelector(
                          stage: stage,
                          onChanged: (s) => widget.onChangeStage(c, s),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        OsFinanceFormat.money(c.totalRevenue ?? 0),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: theme.accentText,
                        ),
                      ),
                    ],
                  ),
                  if (osCrmLeadSourceDisplay(c.leadSource) != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      osCrmLeadSourceDisplay(c.leadSource)!,
                      style: TextStyle(
                        fontSize: 11,
                        color: stageColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final mobile = Responsive.isMobile(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedIds.isNotEmpty) _bulkBar(context, theme),
          Expanded(
            child: mobile
                ? _mobileList(context, theme)
                : AppDataTable(
        minWidth: 1120,
        dataRowMinHeight: 64,
        dataRowMaxHeight: 72,
        showCheckboxColumn: false,
        columns: [
          _checkboxColumn(),
          appDataColumn(context, AppLocaleKeys.osCrmColCompany.tr),
          appDataColumn(context, AppLocaleKeys.osCrmColContact.tr),
          appDataColumn(context, AppLocaleKeys.osCrmColPhone.tr),
          appDataColumn(context, AppLocaleKeys.osCrmColStage.tr),
          appDataColumn(context, AppLocaleKeys.osCrmColLeadSource.tr),
          appDataColumn(context, AppLocaleKeys.osCrmColRevenue.tr),
          appDataColumn(
            context,
            AppLocaleKeys.osCrmColActions.tr,
            width: 72,
          ),
        ],
        rows: [
          for (final c in widget.clients)
            DataRow(
              cells: [
                appDataCell(
                  Checkbox(
                    value: c.id != null && _selectedIds.contains(c.id),
                    onChanged: c.id == null
                        ? null
                        : (selected) => _toggleSelection(c.id!, selected),
                  ),
                ),
                appDataCell(
                  Text(
                    widget.crm.displayCompany(c),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.secondaryText,
                    ),
                  ),
                ),
                appDataCell(
                  Text(
                    c.name ?? AppLocaleKeys.osCommonDash.tr,
                    style: TextStyle(color: theme.secondaryText),
                  ),
                ),
                appDataCell(
                  Text(
                    (c.phone ?? '').trim().isEmpty
                        ? AppLocaleKeys.osCommonDash.tr
                        : c.phone!,
                    style: TextStyle(color: theme.secondaryText),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                appDataCell(
                  OsCrmStageSelector(
                    stage: widget.crm.effectiveStage(c),
                    onChanged: (stage) {
                      widget.onChangeStage(c, stage);
                    },
                  ),
                ),
                appDataCell(
                  Text(
                    osCrmLeadSourceDisplay(c.leadSource) ??
                        AppLocaleKeys.osCommonDash.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.secondaryText,
                    ),
                  ),
                ),
                appDataCell(
                  Text(
                    OsFinanceFormat.money(c.totalRevenue ?? 0),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.secondaryText,
                    ),
                  ),
                ),
                appDataCell(
                  IconButton(
                    tooltip: AppLocaleKeys.osCrmViewDetails.tr,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    onPressed:
                        c.id == null ? null : () => widget.onTap(c.id!),
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 20,
                      color: theme.mutedText,
                    ),
                  ),
                ),
              ],
            ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}
