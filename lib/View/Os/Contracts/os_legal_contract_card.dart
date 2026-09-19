import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_print.dart';
import 'package:point/View/Os/os_button_styles.dart';

/// Grid card for the legal contracts registry (Point OS style).
class OsLegalContractCard extends StatelessWidget {
  const OsLegalContractCard({
    super.key,
    required this.contract,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final OsLegalContractModel contract;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final start = FirestoreOsFinanceApi.formatDate(contract.startDate);
    final end = contract.endDate == null
        ? AppLocaleKeys.osCommonNa.tr
        : FirestoreOsFinanceApi.formatDate(contract.endDate!);
    final lawSnippet = contract.governingLaw.split('(').first.trim();

    return Material(
      color: theme.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contract.contractNumber,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: theme.mutedText,
                      ),
                    ),
                  ),
                  OsLegalContractStatusBadge(status: contract.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OsLegalContractTargetBadge(targetType: contract.targetType),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lawSnippet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: theme.mutedText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                contract.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: theme.primaryText,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.elevatedSurface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            contract.targetName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (contract.partyTwoCompany.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        contract.partyTwoCompany,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: theme.mutedText),
                      ),
                    ],
                    if (contract.partyTwoJobTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contract.partyTwoJobTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 20),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocaleKeys.osLegalContractValue.tr,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            osLegalContractMoneyLabel(
                              contract.totalValue,
                              contract.currency,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocaleKeys.osLegalContractDurationValidity.tr,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$start ${AppLocaleKeys.osLegalContractDateTo.tr} $end',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.secondaryText,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onView,
                      style: OsButtonStyles.inlineAccent(theme),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: Text(AppLocaleKeys.osLegalContractPreviewPrint.tr),
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocaleKeys.osLegalContractEdit.tr,
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, color: theme.secondaryText),
                  ),
                  IconButton(
                    tooltip: AppLocaleKeys.osLegalContractPrint.tr,
                    onPressed: () => printOsLegalContract(contract),
                    icon: Icon(Icons.print_outlined, color: theme.secondaryText),
                  ),
                  if (OsPermissions.canDeleteCurrentOsRecords)
                    IconButton(
                      tooltip: AppLocaleKeys.osCommonDelete.tr,
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.destructive,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
