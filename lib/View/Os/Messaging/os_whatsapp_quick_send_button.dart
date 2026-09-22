import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/os_whatsapp_service.dart';

String osWhatsappQuickSendTooltip(bool enabled) {
  return enabled
      ? AppLocaleKeys.osInvoicesWhatsapp.tr
      : AppLocaleKeys.osWhatsappQuickSendNoTemplate.tr;
}

/// Rebuilds when the agency template map loads or changes.
Widget osWhatsappQuickSendScope({
  required String purpose,
  required Widget Function(bool enabled, String tooltip) builder,
}) {
  final service = OsWhatsappService.instance;
  service.ensureTemplateMapLoaded();
  return Obx(() {
    service.templateMapRevision.value;
    final enabled = service.isQuickSendEnabledForPurpose(purpose);
    final tooltip = osWhatsappQuickSendTooltip(enabled);
    return builder(enabled, tooltip);
  });
}
