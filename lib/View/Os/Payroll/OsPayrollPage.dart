import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/os_payroll_tab_persistence.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Payroll/Mobile/OsPayrollMobileScreen.dart';
import 'package:point/View/Os/Payroll/os_advances_tab.dart';
import 'package:point/View/Os/Payroll/os_contracts_tab.dart';
import 'package:point/View/Os/Payroll/os_payroll_run_tab.dart';
import 'package:point/View/Os/Payroll/os_payslips_tab.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/responsive.dart';

class OsPayrollPage extends StatefulWidget {
  const OsPayrollPage({super.key});

  @override
  State<OsPayrollPage> createState() => _OsPayrollPageState();
}

class _OsPayrollPageState extends State<OsPayrollPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  var _restoringPrefs = false;

  @override
  void initState() {
    super.initState();
    Get.find<OsPayrollController>();
    Get.find<OsFinanceController>();
    final initial = OsPayrollTabPersistence.indexFromRoute();
    _tabs = TabController(length: 4, vsync: this, initialIndex: initial);
    _tabs.addListener(_onTabChanged);
    if (!OsPayrollTabPersistence.hasRouteTab()) {
      _restoreSavedTab();
    } else {
      OsPayrollTabPersistence.saveIndex(initial);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<OsPayrollController>().ensureCurrentRun();
    });
  }

  Future<void> _restoreSavedTab() async {
    final saved = await OsPayrollTabPersistence.loadSavedIndex();
    if (!mounted || saved == _tabs.index) return;
    _restoringPrefs = true;
    _tabs.index = saved;
    _restoringPrefs = false;
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging || _restoringPrefs) return;
    OsPayrollTabPersistence.saveIndex(_tabs.index);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessModule(emp, OsModuleIds.payroll)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    if (Responsive.isMobile(context)) {
      return OsPayrollMobileScreen(tabs: _tabs);
    }

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
                Tab(text: AppLocaleKeys.osPayrollTabRun.tr),
                Tab(text: AppLocaleKeys.osPayrollTabSlips.tr),
                Tab(text: AppLocaleKeys.osPayrollTabContracts.tr),
                Tab(text: AppLocaleKeys.osPayrollTabAdvances.tr),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
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
