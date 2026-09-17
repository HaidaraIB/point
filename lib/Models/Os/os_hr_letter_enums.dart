/// Appreciation letter occasion (point_os EmailHub).
class OsAppreciationType {
  OsAppreciationType._();

  static const excellence = 'EXCELLENCE';
  static const speed = 'SPEED';
  static const employeeOfMonth = 'EMPLOYEE_OF_MONTH';
  static const loyalty = 'LOYALTY';

  static const all = <String>[
    excellence,
    speed,
    employeeOfMonth,
    loyalty,
  ];
}

/// Administrative penalty / warning severity (point_os EmailHub).
class OsPenaltySeverity {
  OsPenaltySeverity._();

  static const notice = 'NOTICE';
  static const firstWarning = 'FIRST_WARNING';
  static const finalWarning = 'FINAL_WARNING';
  static const salaryDeduction = 'SALARY_DEDUCTION';

  static const all = <String>[
    notice,
    firstWarning,
    finalWarning,
    salaryDeduction,
  ];
}
