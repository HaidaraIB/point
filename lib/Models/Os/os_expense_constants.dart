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

/// Seed branches until Branches module ships (point_os MOCK_BRANCHES).
class OsExpenseBranch {
  const OsExpenseBranch({required this.id, required this.nameKey});

  final String id;
  final String nameKey;
}

const osExpenseBranches = <OsExpenseBranch>[
  OsExpenseBranch(id: 'BR-01', nameKey: AppLocaleKeys.osExpensesBranchBaghdad),
  OsExpenseBranch(id: 'BR-02', nameKey: AppLocaleKeys.osExpensesBranchErbil),
  OsExpenseBranch(id: 'BR-03', nameKey: AppLocaleKeys.osExpensesBranchBasra),
];

class OsExpensePaidByExtras {
  OsExpensePaidByExtras._();

  static const accountant = AppLocaleKeys.osExpensesPaidByAccountant;
  static const management = AppLocaleKeys.osExpensesPaidByManagement;

  static const all = [accountant, management];
}
