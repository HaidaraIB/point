import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_form_dialog.dart';
import 'package:point/View/Os/Contracts/os_legal_contracts_registry_tab.dart';
import 'package:point/View/Os/Contracts/os_legal_contracts_templates_tab.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_kpi_card.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

/// Mobile layout for `/os/contracts` — horizontal KPIs and compact tabs.
class OsContractsMobileScreen extends StatelessWidget {
  const OsContractsMobileScreen({super.key, required this.tabs});

  final TabController tabs;

  @override
  Widget build(BuildContext context) {
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
            return SizedBox(
              height: 118,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                children: [
                  SizedBox(
                    width: 168,
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
                    width: 168,
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
                    width: 168,
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
                    width: 188,
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
          const SizedBox(height: 6),
          Material(
            color: theme.cardSurface,
            child: TabBar(
              controller: tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.accentText,
              unselectedLabelColor: theme.mutedText,
              indicatorColor: AppColors.primary,
              labelPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              labelStyle: const TextStyle(
                fontSize: 13,
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
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: const [
                OsLegalContractsRegistryTab(compact: true),
                OsLegalContractsTemplatesTab(compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
