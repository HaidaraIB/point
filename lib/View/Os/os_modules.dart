import 'package:flutter/material.dart';
import 'package:point/Localization/AppLocaleKeys.dart';

/// Shared Point OS module catalog (hub cards + subpage nav).
class OsModule {
  const OsModule({
    required this.titleKey,
    required this.icon,
    this.route,
  });

  final String titleKey;
  final IconData icon;

  /// Named GetX route when live; null = coming soon.
  final String? route;

  bool get isLive => route != null && route!.isNotEmpty;
}

/// Hub entry for subpage nav (not shown as a module card on the hub grid).
const osHubModule = OsModule(
  titleKey: AppLocaleKeys.osNavHub,
  icon: Icons.grid_view_rounded,
  route: '/os',
);

/// Module cards on `/os` and chips on subpage nav (excluding hub).
const osModules = <OsModule>[
  OsModule(
    titleKey: AppLocaleKeys.osModuleCrm,
    icon: Icons.people_outline,
    route: '/os/crm',
  ),
  OsModule(
    titleKey: AppLocaleKeys.osModuleInvoices,
    icon: Icons.receipt_long_outlined,
    route: '/os/invoices',
  ),
  OsModule(
    titleKey: AppLocaleKeys.osModuleQuotations,
    icon: Icons.request_quote_outlined,
    route: '/os/quotations',
  ),
  OsModule(
    titleKey: AppLocaleKeys.osModuleFinance,
    icon: Icons.account_balance_wallet_outlined,
    route: '/os/finance',
  ),
  OsModule(
    titleKey: AppLocaleKeys.osModuleExpenses,
    icon: Icons.payments_outlined,
    route: '/os/expenses',
  ),
  OsModule(
    titleKey: AppLocaleKeys.osModulePayroll,
    icon: Icons.badge_outlined,
    route: '/os/payroll',
  ),
  OsModule(
    titleKey: AppLocaleKeys.osModuleContracts,
    icon: Icons.description_outlined,
    route: '/os/contracts',
  ),
  OsModule(
    titleKey: AppLocaleKeys.osModuleEmailHub,
    icon: Icons.mail_outline,
    route: '/os/email-hub',
  ),
  OsModule(
    titleKey: AppLocaleKeys.osModuleServices,
    icon: Icons.design_services_outlined,
    route: '/os/services',
  ),
  OsModule(
    titleKey: AppLocaleKeys.osModuleBranches,
    icon: Icons.apartment_outlined,
    route: '/os/branches',
  ),
];

/// Hub + all modules for the sticky subpage strip.
List<OsModule> osNavModules() => [osHubModule, ...osModules];
