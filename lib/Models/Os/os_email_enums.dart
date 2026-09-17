/// Email dispatch categories (point_os parity).
class OsEmailCategory {
  OsEmailCategory._();

  static const invoice = 'INVOICE';
  static const quotation = 'QUOTATION';
  static const payslip = 'PAYSLIP';
  static const appreciation = 'APPRECIATION';
  static const penalty = 'PENALTY';
  static const custom = 'CUSTOM';
  static const contract = 'CONTRACT';
}

/// Delivery status stored on [OsEmailLogModel].
class OsEmailLogStatus {
  OsEmailLogStatus._();

  static const sent = 'SENT';
  static const failed = 'FAILED';
  static const queued = 'QUEUED';
}
