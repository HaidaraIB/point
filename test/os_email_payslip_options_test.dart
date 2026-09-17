import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppTranslations.dart';
import 'package:point/Models/Os/OsBankAccountModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/View/Os/EmailHub/os_email_payslip_options.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.addTranslations(AppTranslations().keys);
    Get.updateLocale(const Locale('en'));
  });

  tearDown(Get.reset);

  test('payslip payment method options come from finance accounts', () {
    final accounts = [
      OsBankAccountModel(
        id: 'a1',
        name: 'Rafidain',
        accountNumber: '123',
        balance: 0,
        type: OsBankAccountType.bank,
        createdAt: DateTime(2026, 1, 1),
      ),
      OsBankAccountModel(
        id: 'a2',
        name: 'Petty cash',
        accountNumber: 'N/A',
        balance: 0,
        type: OsBankAccountType.cash,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    final options = payslipPaymentMethodOptions(accounts);
    expect(options, hasLength(2));
    expect(options.first, contains('Rafidain'));
    expect(options.last, contains('Petty cash'));
    expect(defaultPayslipPaymentMethod(accounts), options.first);
  });

  test('empty accounts yield no default payment method', () {
    expect(payslipPaymentMethodOptions(const []), isEmpty);
    expect(defaultPayslipPaymentMethod(const []), isNull);
  });
}
