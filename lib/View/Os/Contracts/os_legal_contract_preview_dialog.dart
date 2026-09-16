import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_print.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';

Future<void> showOsLegalContractPreviewDialog(
  BuildContext context,
  OsLegalContractModel contract, {
  VoidCallback? onEdit,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _OsLegalContractPreviewDialog(
      contract: contract,
      onEdit: onEdit,
    ),
  );
}

class _OsLegalContractPreviewDialog extends StatelessWidget {
  const _OsLegalContractPreviewDialog({
    required this.contract,
    this.onEdit,
  });

  final OsLegalContractModel contract;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<OsLegalContractsController>();
    final settings = ctrl.settings.value;

    return OsDialogFrame(
      title: contract.title,
      icon: Icons.description_outlined,
      maxWidth: 800,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  contract.contractNumber,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: context.appTheme.accentText,
                  ),
                ),
              ),
              OsLegalContractStatusBadge(status: contract.status),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            settings.agencyLegalName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: context.appTheme.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocaleKeys.osLegalContractPreviewOfficial.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.appTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          _infoRow(
            context,
            AppLocaleKeys.osLegalContractPartyName.tr,
            contract.targetName,
          ),
          _infoRow(
            context,
            AppLocaleKeys.osLegalContractStart.tr,
            FirestoreOsFinanceApi.formatDate(contract.startDate),
          ),
          if (contract.endDate != null)
            _infoRow(
              context,
              AppLocaleKeys.osLegalContractEnd.tr,
              FirestoreOsFinanceApi.formatDate(contract.endDate!),
            ),
          _infoRow(
            context,
            AppLocaleKeys.osLegalContractValue.tr,
            osLegalContractMoneyLabel(contract.totalValue, contract.currency),
          ),
          _infoRow(
            context,
            AppLocaleKeys.osLegalContractGoverningLaw.tr,
            contract.governingLaw,
          ),
          _infoRow(
            context,
            AppLocaleKeys.osLegalContractJurisdiction.tr,
            contract.jurisdiction,
          ),
          const SizedBox(height: 16),
          for (final clause in contract.clauses)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clause.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: context.appTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    clause.content,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: context.appTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      settings.agencyAuthorizedSignatory,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.appTheme.primaryText,
                      ),
                    ),
                    Text(
                      settings.agencySignatoryTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTheme.secondaryText,
                      ),
                    ),
                    Text(
                      AppLocaleKeys.osLegalContractPreviewPartyOne.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      contract.targetName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.appTheme.primaryText,
                      ),
                    ),
                    Text(
                      AppLocaleKeys.osLegalContractPreviewPartyTwo.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => printOsLegalContract(contract),
                style: OsButtonStyles.secondaryCompact(context.appTheme),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: Text(AppLocaleKeys.osLegalContractPrint.tr),
              ),
              if (contract.status == OsLegalContractStatus.pendingSignature)
                FilledButton.icon(
                  onPressed: () async {
                    final ok = await ctrl.updateStatus(
                      contract.id,
                      OsLegalContractStatus.active,
                    );
                    if (context.mounted) {
                      if (ok) Navigator.pop(context);
                    }
                  },
                  style: OsButtonStyles.primaryCompact(),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(AppLocaleKeys.osLegalContractMarkSigned.tr),
                ),
              if (onEdit != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit!();
                  },
                  style: OsButtonStyles.secondaryCompact(context.appTheme),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(AppLocaleKeys.osLegalContractEdit.tr),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = context.appTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.mutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: theme.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}
