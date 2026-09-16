import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_print.dart';
import 'package:point/View/Os/os_button_styles.dart';

/// Full-width registry row for a legal contract (quotations-page style).
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
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final statusColor = osLegalContractStatusColor(contract.status);
    final start = FirestoreOsFinanceApi.formatDate(contract.startDate);
    final end = contract.endDate == null
        ? AppLocaleKeys.osCommonNa.tr
        : FirestoreOsFinanceApi.formatDate(contract.endDate!);

    final meta =
        '${AppLocaleKeys.osLegalContractNumber.tr}: ${contract.contractNumber} • '
        '${osLegalContractTargetLabel(contract.targetType)} • '
        '$start — $end';

    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.description_outlined, color: statusColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contract.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                contract.targetName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meta,
                style: TextStyle(fontSize: 12, color: theme.mutedText),
              ),
            ],
          ),
        ),
      ],
    );

    final amount = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          osLegalContractMoneyLabel(contract.totalValue, contract.currency),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: theme.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        OsLegalContractStatusBadge(status: contract.status),
      ],
    );

    FilledButton toolButton({
      required VoidCallback onPressed,
      required String label,
      IconData? icon,
    }) {
      final child = Text(label);
      final style = OsButtonStyles.inlineTool(theme);
      if (icon == null) {
        return FilledButton(onPressed: onPressed, style: style, child: child);
      }
      return FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 16),
        label: child,
      );
    }

    final actions = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: onView,
            style: OsButtonStyles.inlinePrimary(),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text(AppLocaleKeys.osLegalContractView.tr),
          ),
          toolButton(
            onPressed: onEdit,
            label: AppLocaleKeys.osLegalContractEdit.tr,
            icon: Icons.edit_outlined,
          ),
          toolButton(
            onPressed: () => printOsLegalContract(contract),
            label: AppLocaleKeys.osLegalContractPrint.tr,
            icon: Icons.print_outlined,
          ),
          IconButton(
            tooltip: AppLocaleKeys.osCommonDelete.tr,
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.destructive,
              size: 20,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: theme.cardSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (narrow) ...[
                info,
                const SizedBox(height: 14),
                Align(alignment: AlignmentDirectional.centerStart, child: amount),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: info),
                    amount,
                  ],
                ),
              const SizedBox(height: 16),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}
