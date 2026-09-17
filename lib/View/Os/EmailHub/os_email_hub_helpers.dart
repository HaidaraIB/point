import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsEmailHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsEmailLogModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/Os/os_snackbar.dart';

bool isHubEmailValid(String email) => GetUtils.isEmail(email.trim());

bool validateHubRecipientEmail(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osEmailHubTitle.tr,
      AppLocaleKeys.osInvoicesErrorNoEmail.tr,
    );
    return false;
  }
  if (!isHubEmailValid(trimmed)) {
    OsSnackbar.error(
      AppLocaleKeys.osEmailHubTitle.tr,
      AppLocaleKeys.osEmailHubInvalidEmail.tr,
    );
    return false;
  }
  return true;
}

bool validateHubEmployeeEmail(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osEmailHubTitle.tr,
      AppLocaleKeys.osEmailHubNoEmployeeEmail.tr,
    );
    return false;
  }
  if (!isHubEmailValid(trimmed)) {
    OsSnackbar.error(
      AppLocaleKeys.osEmailHubTitle.tr,
      AppLocaleKeys.osEmailHubInvalidEmail.tr,
    );
    return false;
  }
  return true;
}

Future<bool> confirmSendEmail({required String recipientEmail}) async {
  final ctx = Get.context;
  if (ctx == null) return false;
  final confirmed = await FunHelper.showConfirmDailog(
    ctx,
    title: AppLocaleKeys.osEmailHubSendConfirmTitle.tr,
    message: AppLocaleKeys.osEmailHubSendConfirmMessage.trParams({
      'email': recipientEmail,
    }),
    confirmText: AppLocaleKeys.osEmailHubSend.tr,
    onTap: () {},
  );
  return confirmed == true;
}

Future<bool> confirmPayslipBatchSend({
  required int recipientCount,
}) async {
  final ctx = Get.context;
  if (ctx == null) return false;
  final confirmed = await FunHelper.showConfirmDailog(
    ctx,
    title: AppLocaleKeys.osEmailHubPayslipBatchConfirmTitle.tr,
    message: AppLocaleKeys.osEmailHubPayslipBatchConfirmMessage.trParams({
      'count': '$recipientCount',
    }),
    confirmText: AppLocaleKeys.osEmailHubSend.tr,
    onTap: () {},
  );
  return confirmed == true;
}

Future<void> confirmClearEmailLogs(OsEmailHubController hub) async {
  final ctx = Get.context;
  if (ctx == null) return;
  await FunHelper.showDeleteConfirmDialog(
    ctx,
    title: AppLocaleKeys.osEmailHubLogsClearTitle.tr,
    message: AppLocaleKeys.osEmailHubLogsClearMessage.tr,
    onTap: () async {
      final ok = await hub.clearLogs();
      if (ok) {
        OsSnackbar.success(
          AppLocaleKeys.osEmailHubTitle.tr,
          AppLocaleKeys.osEmailHubLogsCleared.tr,
        );
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osEmailHubTitle.tr,
          AppLocaleKeys.errorsServer.tr,
        );
      }
    },
  );
}

Future<void> confirmDeleteEmailLog({
  required BuildContext context,
  required OsEmailHubController hub,
  required OsEmailLogModel log,
}) async {
  await FunHelper.showDeleteConfirmDialog(
    context,
    title: AppLocaleKeys.osEmailHubLogsDeleteTitle.tr,
    message: AppLocaleKeys.osEmailHubLogsDeleteMessage.trParams({
      'email': log.recipientEmail,
    }),
    onTap: () => hub.deleteLog(log.id ?? ''),
  );
}

Future<bool> confirmResendEmailLog({
  required BuildContext context,
  required String recipientEmail,
}) async {
  final confirmed = await FunHelper.showConfirmDailog(
    context,
    title: AppLocaleKeys.osEmailHubLogsResendConfirmTitle.tr,
    message: AppLocaleKeys.osEmailHubLogsResendConfirmMessage.trParams({
      'email': recipientEmail,
    }),
    confirmText: AppLocaleKeys.osEmailHubLogsResend.tr,
    onTap: () {},
  );
  return confirmed == true;
}
