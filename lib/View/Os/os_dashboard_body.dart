import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_modules.dart';

class OsDashboardBody extends StatelessWidget {
  const OsDashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final finance = Get.find<OsFinanceController>();

    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(() {
          final clientsCount = controller.clients.length;
          final employeesCount = controller.employees.length;
          final invoiceTotal = finance.totalInvoiced;

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final kpiCrossAxisCount = wide
                  ? 4
                  : (constraints.maxWidth >= 560 ? 2 : 1);
              final moduleCrossAxisCount = wide
                  ? 5
                  : (constraints.maxWidth >= 560 ? 2 : 1);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppLocaleKeys.osDashboardTitle.tr,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocaleKeys.osDashboardSubtitle.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GridView.count(
                      crossAxisCount: kpiCrossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: wide ? 1.7 : 2.2,
                      children: [
                        _KpiCard(
                          title: AppLocaleKeys.osKpiClients.tr,
                          value: '$clientsCount',
                          icon: Icons.groups_outlined,
                          color: Colors.blue,
                        ),
                        _KpiCard(
                          title: AppLocaleKeys.osKpiEmployees.tr,
                          value: '$employeesCount',
                          icon: Icons.badge_outlined,
                          color: Colors.indigo,
                        ),
                        _KpiCard(
                          title: AppLocaleKeys.osKpiInvoices.tr,
                          value: OsFinanceFormat.money(invoiceTotal),
                          icon: Icons.receipt_long_outlined,
                          color: Colors.teal,
                        ),
                        _KpiCard(
                          title: AppLocaleKeys.osKpiConversion.tr,
                          value: AppLocaleKeys.osKpiConversionZero.tr,
                          subtitle: AppLocaleKeys.osKpiNotConnected.tr,
                          icon: Icons.trending_up_outlined,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      AppLocaleKeys.osModulesTitle.tr,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: moduleCrossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: wide ? 1.35 : 2.4,
                      children: [
                        for (final module in osModules)
                          _ModuleCard(module: module),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: theme.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: theme.primaryText,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: theme.mutedText),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});

  final OsModule module;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final live = module.isLive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: live
            ? () {
                Get.toNamed(module.route!);
              }
            : null,
        child: Opacity(
          opacity: live ? 1 : 0.85,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(module.icon, color: theme.accentText, size: 22),
                    const Spacer(),
                    if (!live)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.panelTint,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.accentBorder.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          AppLocaleKeys.osModuleComingSoon.tr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.accentText,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: theme.mutedText,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  module.titleKey.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
