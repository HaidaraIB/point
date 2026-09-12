import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/View/Os/os_snackbar.dart';

Future<void> printOsExpensesSheet({
  required List<OsDailyExpenseModel> expenses,
  required String Function(OsDailyExpenseModel) categoryLabel,
  required String Function(OsDailyExpenseModel) amountLabel,
}) async {
  OsSnackbar.error(
    AppLocaleKeys.osExpensesPrint.tr,
    AppLocaleKeys.osExpensesPrintFallback.tr,
  );
}
