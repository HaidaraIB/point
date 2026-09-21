import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_form_dialog.dart';
import 'package:point/View/Os/Contracts/os_legal_contracts_registry_tab.dart';
import 'package:point/View/Os/Contracts/os_legal_contracts_templates_tab.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_kpi_card.dart';
import 'package:point/View/Os/os_horizontal_scroll_view.dart';
import 'package:point/View/Os/Contracts/Mobile/OsContractsMobileScreen.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/responsive.dart';

class OsContractsPage extends StatefulWidget {
  const OsContractsPage({super.key});

  @override
  State<OsContractsPage> createState() => _OsContractsPageState();
}

class _OsContractsPageState extends State<OsContractsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    Get.find<OsLegalContractsController>();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessModule(emp, OsModuleIds.contracts)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    if (Responsive.isMobile(context)) {
      return OsContractsMobileScreen(tabs: _tabs);
    }

    final theme = context.appTheme;
    final ctrl = Get.find<OsLegalContractsController>();

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osLegalContractTitle.tr,
            subtitle: AppLocaleKeys.osLegalContractSubtitle.tr,
            currentRoute: '/os/contracts',
            actions: [
              FilledButton.icon(
                onPressed: () => showOsLegalContractFormDialog(context),
                style: OsButtonStyles.primaryCompact(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocaleKeys.osLegalContractAdd.tr),
              ),
            ],
          ),
          Obx(() {
            final all = ctrl.contracts.toList();
            return OsHorizontalScrollContainer(
              height: 118,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              builder: (_) => Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: OsKpiCard(
                      dense: true,
                      title: AppLocaleKeys.osLegalContractKpiTotal.tr,
                      value: '${all.length}',
                      subtitle: AppLocaleKeys.osLegalContractKpiTotalHint.tr,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: OsKpiCard(
                      dense: true,
                      title: AppLocaleKeys.osLegalContractKpiActive.tr,
                      value:
                          '${ctrl.countByStatus(OsLegalContractStatus.active)}',
                      subtitle: AppLocaleKeys.osLegalContractKpiActiveHint.tr,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: OsKpiCard(
                      dense: true,
                      title: AppLocaleKeys.osLegalContractKpiPending.tr,
                      value:
                          '${ctrl.countByStatus(OsLegalContractStatus.pendingSignature)}',
                      subtitle: AppLocaleKeys.osLegalContractKpiPendingHint.tr,
                      color: AppColors.caution,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 196,
                    child: OsKpiCard(
                      dense: true,
                      title: AppLocaleKeys.osLegalContractKpiValue.tr,
                      value: OsFinanceFormat.money(ctrl.activeValueIqd()),
                      subtitle: AppLocaleKeys.osLegalContractKpiValueHint.tr,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Material(
            color: theme.cardSurface,
            child: OsTabBarScrollContainer(
              tabBarBuilder: (scrollController) => TabBar(
                controller: _tabs,
                scrollController: scrollController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: theme.accentText,
                unselectedLabelColor: theme.mutedText,
                indicatorColor: AppColors.primary,
                labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                tabs: [
                  Tab(
                    child: Obx(
                      () => Text(
                        '${AppLocaleKeys.osLegalContractTabRegistryFull.tr} (${Get.find<OsLegalContractsController>().contracts.length})',
                      ),
                    ),
                  ),
                  Tab(text: AppLocaleKeys.osLegalContractTabTemplatesFull.tr),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                OsLegalContractsRegistryTab(),
                OsLegalContractsTemplatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
