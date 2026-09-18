import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Utils/AppColors.dart';
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
      return AppColors.success;
    case OsLegalContractStatus.pendingSignature:
      return AppColors.caution;
    case OsLegalContractStatus.draft:
      return const Color(0xff9CA3AF);
    case OsLegalContractStatus.expired:
    case OsLegalContractStatus.terminated:
      return AppColors.destructive;
    default:
      return AppColors.grey;
  }
}

Color osLegalContractTargetColor(String type) {
  switch (type) {
    case OsLegalContractTargetType.client:
      return AppColors.primary;
    case OsLegalContractTargetType.employee:
      return AppColors.primaryDark;
    case OsLegalContractTargetType.freelancer:
      return AppColors.primary;
    default:
      return AppColors.grey;
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
