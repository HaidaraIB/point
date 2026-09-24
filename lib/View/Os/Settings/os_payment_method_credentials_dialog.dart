import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsAlqasehSettingsStatus.dart';
import 'package:point/Models/Os/OsPaytabsSettingsStatus.dart';
import 'package:point/View/Os/os_alqaseh_settings_panel.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_paytabs_settings_panel.dart';
import 'package:point/View/Os/os_qicard_settings_panel.dart';

enum OsPaymentMethodKind { paytabs, alqaseh, qicard }

Future<void> showOsPaymentMethodCredentialsDialog({
  required BuildContext context,
  required OsPaymentMethodKind kind,
  ValueChanged<OsPaytabsSettingsStatus>? onPaytabsSaved,
  ValueChanged<OsAlqasehSettingsStatus>? onAlqasehSaved,
  Future<void> Function()? onQicardSaved,
}) {
  final title = switch (kind) {
    OsPaymentMethodKind.paytabs => AppLocaleKeys.osSettingsPaytabsSection.tr,
    OsPaymentMethodKind.alqaseh => AppLocaleKeys.osSettingsAlqasehSection.tr,
    OsPaymentMethodKind.qicard => AppLocaleKeys.osSettingsQicardSection.tr,
  };
  final icon = switch (kind) {
    OsPaymentMethodKind.paytabs => Icons.credit_card_outlined,
    OsPaymentMethodKind.alqaseh => Icons.account_balance_outlined,
    OsPaymentMethodKind.qicard => Icons.qr_code_2_outlined,
  };

  return showOsFormDialog(
    context: context,
    title: title,
    titleIcon: icon,
    maxWidth: 600,
    showSave: false,
    builder: (dialogContext, setLocal) {
      switch (kind) {
        case OsPaymentMethodKind.paytabs:
          return OsPaytabsSettingsPanel(
            embedded: true,
            compact: true,
            onSettingsSaved: (status) {
              onPaytabsSaved?.call(status);
              setLocal(() {});
            },
          );
        case OsPaymentMethodKind.alqaseh:
          return OsAlqasehSettingsPanel(
            embedded: true,
            compact: true,
            onSettingsSaved: (status) {
              onAlqasehSaved?.call(status);
              setLocal(() {});
            },
          );
        case OsPaymentMethodKind.qicard:
          return OsQicardSettingsPanel(
            embedded: true,
            compact: true,
            onSettingsSaved: (_) async {
              await onQicardSaved?.call();
              setLocal(() {});
            },
          );
      }
    },
  ).then((_) => null);
}
