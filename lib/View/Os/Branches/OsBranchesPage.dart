import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsBranchModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/firestore/firestore_os_branches_api.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Branches/os_branch_form_dialog.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_list_filters.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:url_launcher/url_launcher.dart';

class OsBranchesPage extends StatefulWidget {
  const OsBranchesPage({super.key});

  @override
  State<OsBranchesPage> createState() => _OsBranchesPageState();
}

class _OsBranchesPageState extends State<OsBranchesPage> {
  final _search = TextEditingController();
  var _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<OsBranchModel> _filtered(List<OsBranchModel> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((b) {
      if (_status != 'ALL' && b.status != _status) return false;
      if (q.isEmpty) return true;
      return b.name.toLowerCase().contains(q) ||
          b.location.toLowerCase().contains(q) ||
          b.manager.toLowerCase().contains(q) ||
          b.phone.toLowerCase().contains(q);
    }).toList();
  }

  bool get _filtersActive =>
      _status != 'ALL' || _search.text.trim().isNotEmpty;

  int _staffCount(String? branchId) {
    if (branchId == null || branchId.isEmpty) return 0;
    final employees = Get.find<HomeController>().employees;
    return employees.where((e) => e.branchId == branchId).length;
  }

  int _uniqueProvinces(List<OsBranchModel> list) {
    final set = <String>{};
    for (final b in list) {
      final loc = b.location.trim();
      if (loc.isEmpty) continue;
      final province = loc.split('،').first.trim();
      if (province.isNotEmpty) set.add(province);
    }
    return set.length;
  }

  Future<void> _openMap(OsBranchModel branch) async {
    final q = Uri.encodeComponent(branch.location.trim());
    if (q.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osCommonDash.tr,
        AppLocaleKeys.errorsOsBranchesOpenMap.tr,
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$q',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      OsSnackbar.error(
        AppLocaleKeys.osCommonDash.tr,
        AppLocaleKeys.errorsOsBranchesOpenMap.tr,
      );
    }
  }

  Future<void> _call(OsBranchModel branch) async {
    final phone = branch.phone.trim();
    if (phone.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osCommonDash.tr,
        AppLocaleKeys.errorsOsBranchesOpenPhone.tr,
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      OsSnackbar.error(
        AppLocaleKeys.osCommonDash.tr,
        AppLocaleKeys.errorsOsBranchesOpenPhone.tr,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OsFinanceController finance,
    OsBranchModel branch,
  ) async {
    final id = branch.id;
    if (id == null || id.isEmpty) return;

    await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: AppLocaleKeys.osBranchesDeleteConfirm.trParams({
        'name': branch.name,
      }),
      onTap: () async {
        try {
          final ok = await finance.deleteBranch(id);
          if (ok) {
            OsSnackbar.success(
              AppLocaleKeys.osBranchesDeleted.tr,
              branch.name,
            );
          } else {
            OsSnackbar.error(
              AppLocaleKeys.osCommonDeleteFailed.tr,
              AppLocaleKeys.errorsOsBranchesDelete.tr,
            );
          }
        } on OsBranchesException catch (e) {
          OsSnackbar.error(
            AppLocaleKeys.osCommonDeleteFailed.tr,
            e.messageKey.tr,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessModule(emp, OsModuleIds.branches)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    final finance = Get.find<OsFinanceController>();
    final theme = context.appTheme;

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osBranchesTitle.tr,
            subtitle: AppLocaleKeys.osBranchesSubtitle.tr,
            currentRoute: '/os/branches',
            actions: [
              FilledButton.icon(
                onPressed: () => showOsBranchFormDialog(context),
                style: OsButtonStyles.primaryCompact(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocaleKeys.osBranchesAdd.tr),
              ),
            ],
          ),
          Expanded(
            child: Obx(() {
              final all = finance.branches.toList();
              final list = _filtered(all);
              final totalStaff =
                  Get.find<HomeController>().employees.length;
              final activeCount = all.where((b) => b.isActive).length;
              final provinces = _uniqueProvinces(all);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  final mid = constraints.maxWidth >= 700;
                  final crossAxis = wide ? 3 : (mid ? 2 : 1);
                  final kpiCross = wide ? 4 : 2;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: GridView.count(
                          crossAxisCount: kpiCross,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: mid ? 2.4 : 2.1,
                          children: [
                            _KpiCard(
                              title: AppLocaleKeys.osBranchesKpiTotal.tr,
                              value: '${all.length}',
                              color: theme.primaryText,
                            ),
                            _KpiCard(
                              title: AppLocaleKeys.osBranchesKpiActive.tr,
                              value: '$activeCount',
                              color: AppColors.primary,
                            ),
                            _KpiCard(
                              title: AppLocaleKeys.osBranchesKpiStaff.tr,
                              value: '$totalStaff',
                              color: const Color(0xFF059669),
                            ),
                            _KpiCard(
                              title: AppLocaleKeys.osBranchesKpiProvinces
                                  .trParams({'count': '$provinces'}),
                              value: '$provinces',
                              color: const Color(0xFFD97706),
                            ),
                          ],
                        ),
                      ),
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
                              value: OsBranchStatus.active,
                              label:
                                  AppLocaleKeys.osBranchesFilterActive.tr,
                            ),
                            OsFilterChipOption(
                              value: OsBranchStatus.inactive,
                              label: AppLocaleKeys
                                  .osBranchesFilterInactive.tr,
                            ),
                          ],
                        ),
                        search: OsSearchField(
                          controller: _search,
                          hint: AppLocaleKeys.osBranchesSearch.tr,
                          onChanged: (_) => setState(() {}),
                        ),
                        matchCount: all.isEmpty ? null : list.length,
                      ),
                      Expanded(
                        child: list.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                  horizontal: 16,
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      all.isEmpty
                                          ? AppLocaleKeys.osBranchesEmpty.tr
                                          : AppLocaleKeys
                                              .osBranchesEmptyFilter.tr,
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
                                            showOsBranchFormDialog(
                                          context,
                                        ),
                                        style:
                                            OsButtonStyles.primaryCompact(),
                                        icon: const Icon(
                                          Icons.add,
                                          size: 18,
                                        ),
                                        label: Text(
                                          AppLocaleKeys.osBranchesAdd.tr,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  24,
                                ),
                                itemCount: list.length +
                                    (_filtersActive ? 0 : 1),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxis,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: wide
                                      ? 0.95
                                      : (mid ? 0.9 : 1.15),
                                ),
                                itemBuilder: (context, index) {
                                  if (!_filtersActive &&
                                      index == list.length) {
                                    return _AddBranchCard(
                                      onTap: () =>
                                          showOsBranchFormDialog(context),
                                    );
                                  }
                                  final branch = list[index];
                                  return _BranchCard(
                                    branch: branch,
                                    staffCount: _staffCount(branch.id),
                                    onEdit: () => showOsBranchFormDialog(
                                      context,
                                      existing: branch,
                                    ),
                                    onDelete: () => _confirmDelete(
                                      context,
                                      finance,
                                      branch,
                                    ),
                                    onMap: () => _openMap(branch),
                                    onCall: () => _call(branch),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.mutedText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.staffCount,
    required this.onEdit,
    required this.onDelete,
    required this.onMap,
    required this.onCall,
  });

  final OsBranchModel branch;
  final int staffCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMap;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final active = branch.isActive;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.apartment_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFFECFDF5)
                                  : theme.panelTint,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active
                                    ? const Color(0xFFA7F3D0)
                                    : theme.border,
                              ),
                            ),
                            child: Text(
                              active
                                  ? AppLocaleKeys.osBranchesStatusActive.tr
                                  : AppLocaleKeys
                                      .osBranchesStatusInactive.tr,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? const Color(0xFF059669)
                                    : theme.mutedText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: onEdit,
                                tooltip: AppLocaleKeys.osQuotationsEdit.tr,
                                visualDensity: VisualDensity.compact,
                                iconSize: 16,
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: theme.mutedText,
                                ),
                              ),
                              if (OsPermissions.canDeleteCurrentOsRecords)
                                IconButton(
                                  onPressed: onDelete,
                                  tooltip: AppLocaleKeys.osCommonDelete.tr,
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 16,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    branch.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          branch.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Divider(height: 20, color: theme.border),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocaleKeys.osBranchesManager.tr,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: theme.mutedText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              branch.manager.isEmpty
                                  ? AppLocaleKeys.osCommonDash.tr
                                  : branch.manager,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocaleKeys.osBranchesStaff.tr,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: theme.mutedText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    AppLocaleKeys.osBranchesStaffCount
                                        .trParams({
                                      'count': '$staffCount',
                                    }),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: theme.primaryText,
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
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.panelTint,
              border: Border(top: BorderSide(color: theme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primaryText,
                      side: BorderSide(color: theme.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.navigation_outlined, size: 14),
                    label: Text(AppLocaleKeys.osBranchesMap.tr),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primaryText,
                      side: BorderSide(color: theme.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.phone_outlined, size: 14),
                    label: Text(AppLocaleKeys.osBranchesCall.tr),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBranchCard extends StatelessWidget {
  const _AddBranchCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
                        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.border,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.panelTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  size: 28,
                  color: theme.mutedText,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  AppLocaleKeys.osBranchesAddCard.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.mutedText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
