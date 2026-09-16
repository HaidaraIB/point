import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';

String osLegalContractStatusLabel(String status) {
  switch (status) {
    case OsLegalContractStatus.active:
      return AppLocaleKeys.osLegalContractStatusActive.tr;
    case OsLegalContractStatus.pendingSignature:
      return AppLocaleKeys.osLegalContractStatusPending.tr;
    case OsLegalContractStatus.draft:
      return AppLocaleKeys.osLegalContractStatusDraft.tr;
    case OsLegalContractStatus.expired:
      return AppLocaleKeys.osLegalContractStatusExpired.tr;
    case OsLegalContractStatus.terminated:
      return AppLocaleKeys.osLegalContractStatusTerminated.tr;
    default:
      return status;
  }
}

String osLegalContractTargetLabel(String type) {
  switch (type) {
    case OsLegalContractTargetType.client:
      return AppLocaleKeys.osLegalContractTargetClient.tr;
    case OsLegalContractTargetType.employee:
      return AppLocaleKeys.osLegalContractTargetEmployee.tr;
    case OsLegalContractTargetType.freelancer:
      return AppLocaleKeys.osLegalContractTargetFreelancer.tr;
    default:
      return type;
  }
}

Color osLegalContractStatusColor(String status) {
  switch (status) {
    case OsLegalContractStatus.active:
      return const Color(0xFF059669);
    case OsLegalContractStatus.pendingSignature:
      return const Color(0xFFD97706);
    case OsLegalContractStatus.draft:
      return const Color(0xFF64748B);
    case OsLegalContractStatus.expired:
      return const Color(0xFFE11D48);
    case OsLegalContractStatus.terminated:
      return const Color(0xFFB91C1C);
    default:
      return const Color(0xFF64748B);
  }
}

Color osLegalContractTargetColor(String type) {
  switch (type) {
    case OsLegalContractTargetType.client:
      return const Color(0xFF4F46E5);
    case OsLegalContractTargetType.employee:
      return const Color(0xFF2563EB);
    case OsLegalContractTargetType.freelancer:
      return const Color(0xFF9333EA);
    default:
      return const Color(0xFF64748B);
  }
}

class OsLegalContractStatusBadge extends StatelessWidget {
  const OsLegalContractStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = osLegalContractStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        osLegalContractStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class OsLegalContractTargetBadge extends StatelessWidget {
  const OsLegalContractTargetBadge({super.key, required this.targetType});

  final String targetType;

  @override
  Widget build(BuildContext context) {
    final color = osLegalContractTargetColor(targetType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        osLegalContractTargetLabel(targetType),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String osLegalContractMoneyLabel(double value, String currency) {
  if (currency == OsLegalContractCurrency.usd) {
    return '${OsFinanceFormat.moneyNumber(value)} ${AppLocaleKeys.osLegalContractCurrencyUsd.tr}';
  }
  return OsFinanceFormat.money(value);
}

Widget osLegalContractMoneyText(
  BuildContext context,
  double value,
  String currency,
) {
  final theme = context.appTheme;
  return Text(
    osLegalContractMoneyLabel(value, currency),
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: theme.primaryText,
    ),
  );
}
