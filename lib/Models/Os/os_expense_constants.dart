import 'package:point/Localization/AppLocaleKeys.dart';

/// Fixed expense categories (point_os EXPENSE_CATEGORIES).
class OsExpenseCategories {
  OsExpenseCategories._();

  static const all = <String>[
    AppLocaleKeys.osExpensesCatHospitality,
    AppLocaleKeys.osExpensesCatFuel,
    AppLocaleKeys.osExpensesCatEquipment,
    AppLocaleKeys.osExpensesCatMaintenance,
    AppLocaleKeys.osExpensesCatSoftware,
    AppLocaleKeys.osExpensesCatRent,
    AppLocaleKeys.osExpensesCatMarketing,
    AppLocaleKeys.osExpensesCatOffice,
    AppLocaleKeys.osExpensesCatPayroll,
    AppLocaleKeys.osExpensesCatOther,
  ];
}

class OsExpensePaymentMethod {
  OsExpensePaymentMethod._();

  static const cash = 'CASH';
  static const zainCash = 'ZAIN_CASH';
  static const qiCard = 'QI_CARD';
  static const bankTransfer = 'BANK_TRANSFER';
  static const visaMaster = 'VISA_MASTER';

  static const all = [
    cash,
    zainCash,
    qiCard,
    bankTransfer,
    visaMaster,
  ];

  static String labelKey(String method) {
    switch (method) {
      case zainCash:
        return AppLocaleKeys.osExpensesPayZain;
      case qiCard:
        return AppLocaleKeys.osExpensesPayQi;
      case bankTransfer:
        return AppLocaleKeys.osExpensesPayTransfer;
      case visaMaster:
        return AppLocaleKeys.osExpensesPayCard;
      case cash:
      default:
        return AppLocaleKeys.osExpensesPayCash;
    }
  }
}

class OsExpenseStatus {
  OsExpenseStatus._();

  static const approved = 'APPROVED';
  static const pending = 'PENDING';
  static const rejected = 'REJECTED';
}

class OsExpensePaidByExtras {
  OsExpensePaidByExtras._();

  static const accountant = AppLocaleKeys.osExpensesPaidByAccountant;
  static const management = AppLocaleKeys.osExpensesPaidByManagement;

  static const all = [accountant, management];
}
