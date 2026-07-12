import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';

/// Admin settings sections. Add new values here as the hub grows.
enum SettingsSection {
  appVersion,
  attendancePolicy,
  libraryPermissions,
}

extension SettingsSectionX on SettingsSection {
  String get labelKey {
    switch (this) {
      case SettingsSection.appVersion:
        return AppLocaleKeys.adminSettingsSectionAppVersion;
      case SettingsSection.attendancePolicy:
        return AppLocaleKeys.adminSettingsSectionAttendancePolicy;
      case SettingsSection.libraryPermissions:
        return AppLocaleKeys.adminSettingsSectionLibraryPermissions;
    }
  }

  String get label => labelKey.tr;

  IconData get icon {
    switch (this) {
      case SettingsSection.appVersion:
        return Icons.system_update_alt_outlined;
      case SettingsSection.attendancePolicy:
        return Icons.schedule_outlined;
      case SettingsSection.libraryPermissions:
        return Icons.folder_copy_outlined;
    }
  }
}

const List<SettingsSection> kSettingsSections = SettingsSection.values;
