import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Models/Os/OsBankAccountModel.dart';
import 'package:point/View/Os/os_finance_format.dart';

/// Recent payroll months for payslip email dispatch (newest first).
List<String> payslipMonthOptions({int months = 18}) {
  final code = Get.locale?.languageCode ?? 'ar';
  final now = DateTime.now();
  return List.generate(months, (i) {
    final date = DateTime(now.year, now.month - i, 1);
    return DateFormat.yMMMM(code).format(date);
  });
}

String defaultPayslipMonth() => payslipMonthOptions(months: 1).first;

/// Human label for a finance account used as payslip disbursement method.
String payslipPaymentMethodLabel(OsBankAccountModel account) {
  final type = OsFinanceFormat.accountTypeLabel(account.type);
  final name = account.name.trim();
  if (name.isEmpty) return type;
  return '$type — $name';
}

/// Payment methods sourced from OS finance bank/cash/vault accounts.
List<String> payslipPaymentMethodOptions(List<OsBankAccountModel> accounts) {
  return accounts.map(payslipPaymentMethodLabel).toList();
}

String? defaultPayslipPaymentMethod(List<OsBankAccountModel> accounts) {
  if (accounts.isEmpty) return null;
  return payslipPaymentMethodLabel(accounts.first);
}
