/// Canonical Point OS module slugs for supervisor permissions.
class OsModuleIds {
  OsModuleIds._();

  static const crm = 'crm';
  static const invoices = 'invoices';
  static const quotations = 'quotations';
  static const finance = 'finance';
  static const expenses = 'expenses';
  static const payroll = 'payroll';
  static const contracts = 'contracts';
  static const emailHub = 'emailHub';
  static const services = 'services';
  static const branches = 'branches';

  static const all = <String>[
    crm,
    invoices,
    quotations,
    finance,
    expenses,
    payroll,
    contracts,
    emailHub,
    services,
    branches,
  ];

  static bool isValid(String id) => all.contains(id);

  static List<String> normalize(Iterable<dynamic>? raw) {
    if (raw == null) return const [];
    final out = <String>[];
    for (final item in raw) {
      final s = item?.toString().trim();
      if (s == null || s.isEmpty || !isValid(s) || out.contains(s)) continue;
      out.add(s);
    }
    return out;
  }
}
