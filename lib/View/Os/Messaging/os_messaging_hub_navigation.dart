import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Services/os_whatsapp_service.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/View/Os/os_snackbar.dart';

Future<T?> _withMessagingHubOpeningOverlay<T>(
  Future<T?> Function() action,
) async {
  final overlayContext = Get.overlayContext ?? Get.context;
  if (overlayContext == null) return action();

  NavigatorState? dialogNavigator;

  unawaited(
    showDialog<void>(
      context: overlayContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        dialogNavigator = Navigator.of(ctx, rootNavigator: true);
        final theme = ctx.appTheme;
        return PopScope(
          canPop: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Material(
                color: theme.cardSurface,
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: theme.accentText,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          AppLocaleKeys.osMessagingHubOpening.tr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  await Future<void>.delayed(Duration.zero);

  try {
    return await action();
  } finally {
    _dismissMessagingHubOpeningOverlay(dialogNavigator, overlayContext);
  }
}

void _dismissMessagingHubOpeningOverlay(
  NavigatorState? dialogNavigator,
  BuildContext overlayContext,
) {
  try {
    if (dialogNavigator != null &&
        dialogNavigator.mounted &&
        dialogNavigator.canPop()) {
      dialogNavigator.pop();
      return;
    }
  } catch (_) {}

  try {
    final navigator = Navigator.of(overlayContext, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
  } catch (_) {
    if (Get.isDialogOpen == true) {
      Get.back(closeOverlays: true);
    }
  }
}

Future<bool> ensureOsWhatsappApiAvailable() async {
  final emp = Get.find<HomeController>().effectiveEmployee;
  if (!OsPermissions.canAccessModule(emp, OsModuleIds.messaging)) {
    OsSnackbar.error(
      AppLocaleKeys.osMessagingHubTitle.tr,
      AppLocaleKeys.errorsForbidden.tr,
    );
    return false;
  }
  final status = await OsWhatsappService.instance.loadSettings(force: true);
  if (status?.isReadyForSend != true) {
    OsSnackbar.error(
      AppLocaleKeys.osMessagingHubTitle.tr,
      AppLocaleKeys.osMessagingHubNotConfigured.tr,
    );
    return false;
  }
  return true;
}

Future<void> openOsMessagingHubForClient(String clientId) async {
  final ready = await _withMessagingHubOpeningOverlay(
    ensureOsWhatsappApiAvailable,
  );
  if (ready != true) return;
  await Get.toNamed(
    '/os/messaging',
    arguments: {'clientId': clientId},
  );
}

Future<void> openOsMessagingHubForInvoice(OsInvoiceModel invoice) async {
  final id = invoice.id?.trim();
  if (id == null || id.isEmpty) return;

  final ready = await _withMessagingHubOpeningOverlay(
    ensureOsWhatsappApiAvailable,
  );
  if (ready != true) return;

  await Get.toNamed(
    '/os/messaging',
    arguments: {
      'invoiceId': id,
      if (invoice.clientId.trim().isNotEmpty)
        'clientId': invoice.clientId.trim(),
    },
  );
}
