/// Status / type constants for Point OS payroll entities.
class OsPayrollRunStatus {
  OsPayrollRunStatus._();

  static const draft = 'DRAFT';
  static const partial = 'PARTIAL';
  static const completed = 'COMPLETED';

  static const all = [draft, partial, completed];
}

class OsPayslipStatus {
  OsPayslipStatus._();

  static const pending = 'PENDING';
  static const paid = 'PAID';

  static const all = [pending, paid];
}

class OsEmployeeContractStatus {
  OsEmployeeContractStatus._();

  static const active = 'ACTIVE';
  static const expired = 'EXPIRED';

  static const all = [active, expired];
}

class OsEmployeeAdvanceStatus {
  OsEmployeeAdvanceStatus._();

  static const active = 'ACTIVE';
  static const settled = 'SETTLED';

  static const all = [active, settled];
}
