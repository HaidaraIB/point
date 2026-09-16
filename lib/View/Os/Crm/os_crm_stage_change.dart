import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/os_crm_enums.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Os/Crm/os_crm_labels.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Confirms WON/LOST moves, then runs [onApply]. Used by profile and kanban.
Future<void> confirmAndApplyCrmStageChange(
  BuildContext context, {
  required String currentStage,
  required String newStage,
  required Future<bool> Function() onApply,
}) async {
  if (currentStage == newStage) return;

  Future<void> apply() async {
    final ok = await onApply();
    if (!ok) {
      OsSnackbar.error(
        AppLocaleKeys.osCommonSaveFailed.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
    }
  }

  if (newStage == OsCrmStage.won) {
    await FunHelper.showConfirmDailog(
      context,
      title: AppLocaleKeys.osCrmConfirmWonTitle.tr,
      message: AppLocaleKeys.osCrmConfirmWonMessage.tr,
      confirmText: osCrmStageLabel(OsCrmStage.won),
      confirmColor: AppColors.primary,
      onTap: apply,
    );
    return;
  }
  if (newStage == OsCrmStage.lost) {
    await FunHelper.showConfirmDailog(
      context,
      title: AppLocaleKeys.osCrmConfirmLostTitle.tr,
      message: AppLocaleKeys.osCrmConfirmLostMessage.tr,
      confirmText: osCrmStageLabel(OsCrmStage.lost),
      confirmColor: AppColors.caution,
      onTap: apply,
    );
    return;
  }
  await apply();
}
