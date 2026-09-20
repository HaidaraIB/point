import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Finance/OsFinancePage.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

/// Mobile layout for `/os/finance` — compact tabs and stacked filters/toolbars.
class OsFinanceMobileScreen extends StatelessWidget {
  const OsFinanceMobileScreen({super.key, required this.tabs});

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
            title: AppLocaleKeys.osFinanceTitle.tr,
            subtitle: AppLocaleKeys.osFinanceSubtitle.tr,
            currentRoute: '/os/finance',
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
                Tab(text: AppLocaleKeys.osFinanceOverview.tr),
                Tab(text: AppLocaleKeys.osFinanceAccounts.tr),
                Tab(text: AppLocaleKeys.osFinanceVouchers.tr),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: const [
                OsFinanceOverviewTab(compact: true),
                OsFinanceAccountsTab(compact: true),
                OsFinanceVouchersTab(compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
