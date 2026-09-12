/// Shared enums for Point OS finance entities.
class OsInvoiceStatus {
  OsInvoiceStatus._();

  static const draft = 'DRAFT';
  static const sent = 'SENT';
  static const overdue = 'OVERDUE';
  static const paid = 'PAID';

  static const all = [draft, sent, overdue, paid];

  /// Statuses editable before payment is locked.
  static const editable = [draft, sent, overdue];
}

class OsBankAccountType {
  OsBankAccountType._();

  static const bank = 'BANK';
  static const cash = 'CASH';
  static const vault = 'VAULT';

  static const all = [bank, cash, vault];

  /// Language-neutral sentinel when account number is blank.
  static const unsetNumber = 'N/A';
}

class OsVoucherType {
  OsVoucherType._();

  static const receipt = 'RECEIPT';
  static const payment = 'PAYMENT';

  static const all = [receipt, payment];
}

class OsVoucherStatus {
  OsVoucherStatus._();

  static const draft = 'DRAFT';
  static const completed = 'COMPLETED';
}

/// How a voucher was created — used to gate manual delete.
class OsVoucherSource {
  OsVoucherSource._();

  /// Entered via the Finance “issue voucher” form.
  static const manual = 'MANUAL';

  /// Auto receipt when an invoice is marked paid.
  static const invoice = 'INVOICE';

  /// Audit pair from an internal account transfer (balance already adjusted).
  static const transfer = 'TRANSFER';

  /// Payment posted with a daily expense.
  static const expense = 'EXPENSE';

  /// Payment posted when a payslip is disbursed.
  static const payroll = 'PAYROLL';
}
