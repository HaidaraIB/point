import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';

/// Admin settings sections. Add new values here as the hub grows.
enum SettingsSection {
  appVersion,
  companyLocation,
}

extension SettingsSectionX on SettingsSection {
  String get labelKey {
    switch (this) {
      case SettingsSection.appVersion:
        return AppLocaleKeys.adminSettingsSectionAppVersion;
      case SettingsSection.companyLocation:
        return AppLocaleKeys.adminSettingsSectionCompanyLocation;
    }
  }

  String get label => labelKey.tr;

  IconData get icon {
    switch (this) {
      case SettingsSection.appVersion:
        return Icons.system_update_alt_outlined;
      case SettingsSection.companyLocation:
        return Icons.location_on_outlined;
    }
  }
}

const List<SettingsSection> kSettingsSections = SettingsSection.values;
