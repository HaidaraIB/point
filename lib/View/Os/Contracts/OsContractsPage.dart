import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_form_dialog.dart';
import 'package:point/View/Os/Contracts/os_legal_contracts_registry_tab.dart';
import 'package:point/View/Os/Contracts/os_legal_contracts_templates_tab.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

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
            title: AppLocaleKeys.osLegalContractTitle.tr,
            subtitle: AppLocaleKeys.osLegalContractSubtitle.tr,
            currentRoute: '/os/contracts',
            actions: [
              ListenableBuilder(
                listenable: _tabs,
                builder: (context, _) {
                  if (_tabs.index != 0) return const SizedBox.shrink();
                  return FilledButton.icon(
                    onPressed: () => showOsLegalContractFormDialog(context),
                    style: OsButtonStyles.primaryCompact(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppLocaleKeys.osLegalContractAdd.tr),
                  );
                },
              ),
            ],
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
                Tab(text: AppLocaleKeys.osLegalContractTabRegistry.tr),
                Tab(text: AppLocaleKeys.osLegalContractTabTemplates.tr),
              ],
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
