/// Legal / client contracts (Point OS — distinct from payroll employee contracts).
class OsLegalContractTargetType {
  OsLegalContractTargetType._();

  static const client = 'CLIENT';
  static const employee = 'EMPLOYEE';
  static const freelancer = 'FREELANCER';

  static const ordered = [client, employee, freelancer];
}

class OsLegalContractStatus {
  OsLegalContractStatus._();

  static const draft = 'DRAFT';
  static const pendingSignature = 'PENDING_SIGNATURE';
  static const active = 'ACTIVE';
  static const expired = 'EXPIRED';
  static const terminated = 'TERMINATED';

  static const ordered = [
    draft,
    pendingSignature,
    active,
    expired,
    terminated,
  ];

  /// Registry filter order (matches point_os Contracts.tsx status `<select>`).
  static const filterOrdered = [
    active,
    pendingSignature,
    draft,
    expired,
    terminated,
  ];
}

class OsLegalContractCurrency {
  OsLegalContractCurrency._();

  static const iqd = 'IQD';
  static const usd = 'USD';

  static const ordered = [iqd, usd];
}
