import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Payroll/os_advances_tab.dart';
import 'package:point/View/Os/Payroll/os_contracts_tab.dart';
import 'package:point/View/Os/Payroll/os_payroll_run_tab.dart';
import 'package:point/View/Os/Payroll/os_payslips_tab.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

/// Mobile layout for `/os/payroll` — same four tabs, compact header.
class OsPayrollMobileScreen extends StatelessWidget {
  const OsPayrollMobileScreen({super.key, required this.tabs});

  final TabController tabs;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osPayrollTitle.tr,
            subtitle: AppLocaleKeys.osPayrollSubtitle.tr,
            currentRoute: '/os/payroll',
          ),
          Material(
            color: theme.cardSurface,
            child: TabBar(
              controller: tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.accentText,
              unselectedLabelColor: theme.mutedText,
              indicatorColor: AppColors.primary,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              tabs: [
                Tab(text: AppLocaleKeys.osPayrollTabRun.tr),
                Tab(text: AppLocaleKeys.osPayrollTabSlips.tr),
                Tab(text: AppLocaleKeys.osPayrollTabContracts.tr),
                Tab(text: AppLocaleKeys.osPayrollTabAdvances.tr),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: const [
                OsPayrollRunTab(),
                OsPayslipsTab(),
                OsContractsTab(),
                OsAdvancesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
