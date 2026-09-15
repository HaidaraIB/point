import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsServiceModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Services/os_service_form_dialog.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_list_filters.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

class OsServicesPage extends StatefulWidget {
  const OsServicesPage({super.key});

  @override
  State<OsServicesPage> createState() => _OsServicesPageState();
}

class _OsServicesPageState extends State<OsServicesPage> {
  final _search = TextEditingController();
  var _category = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<OsServiceModel> _filtered(List<OsServiceModel> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((s) {
      if (_category != 'ALL' && s.category != _category) return false;
      if (q.isEmpty) return true;
      final catLabel = OsServiceCategory.labelKey(s.category).tr.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          catLabel.contains(q) ||
          s.category.toLowerCase().contains(q);
    }).toList();
  }

  bool get _filtersActive =>
      _category != 'ALL' || _search.text.trim().isNotEmpty;

  IconData _categoryIcon(String category) {
    switch (category) {
      case OsServiceCategory.visualProduction:
        return Icons.videocam_outlined;
      case OsServiceCategory.postProduction:
        return Icons.content_cut_outlined;
      case OsServiceCategory.digitalMarketing:
        return Icons.share_outlined;
      case OsServiceCategory.creativeDesign:
        return Icons.palette_outlined;
      case OsServiceCategory.artisticProduction:
      default:
        return Icons.camera_alt_outlined;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OsFinanceController finance,
    OsServiceModel service,
  ) async {
    final id = service.id;
    if (id == null || id.isEmpty) return;

    await FunHelper.showDeleteConfirmDialog(
      context,
      title: AppLocaleKeys.osCommonDelete.tr,
      message: AppLocaleKeys.osServicesDeleteConfirm.trParams({
        'name': service.name,
      }),
      onTap: () async {
        final ok = await finance.deleteService(id);
        if (ok) {
          OsSnackbar.success(
            AppLocaleKeys.osServicesDeleted.tr,
            service.name,
          );
        } else {
          OsSnackbar.error(
            AppLocaleKeys.osCommonDeleteFailed.tr,
            AppLocaleKeys.errorsOsServicesDelete.tr,
          );
        }
      },
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

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osServicesTitle.tr,
            subtitle: AppLocaleKeys.osServicesSubtitle.tr,
            currentRoute: '/os/services',
            actions: [
              FilledButton.icon(
                onPressed: () => showOsServiceFormDialog(context),
                style: OsButtonStyles.primaryCompact(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocaleKeys.osServicesAdd.tr),
              ),
            ],
          ),
          Expanded(
            child: Obx(() {
              final all = finance.services.toList();
              final list = _filtered(all);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  final mid = constraints.maxWidth >= 700;
                  final crossAxis = wide ? 3 : (mid ? 2 : 1);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OsListFilterBar(
                        chips: OsFilterChips(
                          value: _category,
                          onChanged: (v) => setState(() => _category = v),
                          options: [
                            OsFilterChipOption(
                              value: 'ALL',
                              label: AppLocaleKeys.osCommonFilterAll.tr,
                            ),
                            for (final c in OsServiceCategory.all)
                              OsFilterChipOption(
                                value: c,
                                label: OsServiceCategory.labelKey(c).tr,
                              ),
                          ],
                        ),
                        search: OsSearchField(
                          controller: _search,
                          hint: AppLocaleKeys.osServicesSearch.tr,
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      all.isEmpty
                                          ? AppLocaleKeys.osServicesEmpty.tr
                                          : AppLocaleKeys
                                              .osServicesEmptyFilter.tr,
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
                                            showOsServiceFormDialog(context),
                                        style: OsButtonStyles.primaryCompact(),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: Text(
                                          AppLocaleKeys.osServicesAdd.tr,
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
                                itemCount: list.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxis,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio:
                                      wide ? 1.15 : (mid ? 1.05 : 1.35),
                                ),
                                itemBuilder: (context, index) {
                                  final service = list[index];
                                  return _ServiceCard(
                                    service: service,
                                    icon: _categoryIcon(service.category),
                                    onEdit: () => showOsServiceFormDialog(
                                      context,
                                      existing: service,
                                    ),
                                    onDelete: () => _confirmDelete(
                                      context,
                                      finance,
                                      service,
                                    ),
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.icon,
    required this.onEdit,
    required this.onDelete,
  });

  final OsServiceModel service;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onEdit,
                  tooltip: AppLocaleKeys.osQuotationsEdit.tr,
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  icon: Icon(Icons.edit_outlined, color: theme.mutedText),
                ),
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
            const SizedBox(height: 12),
            Text(
              service.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.panelTint,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                OsServiceCategory.labelKey(service.category).tr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.mutedText,
                ),
              ),
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
                        OsServicePriceType.labelKey(service.priceType).tr,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: theme.mutedText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        OsFinanceFormat.money(service.basePrice),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  service.id ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: theme.mutedText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
