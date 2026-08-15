import 'package:flutter/material.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/View/Tasks/DetailsDialogs/DAdministrativeDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';

/// Opens the existing details dialog/page for [task] (same as tapping a row).
void openTaskDetails(BuildContext context, TaskModel task) {
  switch (task.type) {
    case '0':
      showCampaignDetailsDialog(context, task: task);
      break;
    case '1':
      showDesignDetailsDialog(context, task: task);
      break;
    case '2':
      showDPhotographyDialog(context, task: task);
      break;
    case '3':
      showContentWriteDialog(context, task: task);
      break;
    case '4':
      showMontageDialog(context, task: task);
      break;
    case '5':
      showPublishDialog(context, task: task);
      break;
    case '6':
      showProgrammingDialog(context, task: task);
      break;
    case '7':
      showAdministrativeTaskDetailsDialog(context, task: task);
      break;
    default:
  }
}
