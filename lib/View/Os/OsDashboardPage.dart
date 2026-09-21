import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/View/Os/os_dashboard_body.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

class OsDashboardPage extends StatelessWidget {
  const OsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessOsSection(emp)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osDashboardTitle.tr,
            subtitle: AppLocaleKeys.osDashboardSubtitle.tr,
            currentRoute: '/os',
            showBackButton: false,
          ),
          const Expanded(child: OsDashboardBody(contentOnly: true)),
        ],
      ),
    );
  }
}
