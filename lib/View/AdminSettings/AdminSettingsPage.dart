import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/View/AdminSettings/sections/app_version_settings_section.dart';
import 'package:point/View/AdminSettings/sections/company_location_settings_section.dart';
import 'package:point/View/AdminSettings/settings_section_nav.dart';
import 'package:point/View/AdminSettings/settings_sections.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  SettingsSection _selected = SettingsSection.appVersion;

  Widget _buildSectionContent() {
    switch (_selected) {
      case SettingsSection.appVersion:
        return const AppVersionSettingsSection();
      case SettingsSection.companyLocation:
        return const CompanyLocationSettingsSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (emp?.role != 'admin') {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    return ResponsiveScaffold(
      selectedTab: 11,
      sideMenu: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SettingsSectionLayout(
          selected: _selected,
          onSelected: (section) => setState(() => _selected = section),
          content: _buildSectionContent(),
        ),
      ),
    );
  }
}
