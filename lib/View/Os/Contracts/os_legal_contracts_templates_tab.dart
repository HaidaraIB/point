import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_form_dialog.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/os_button_styles.dart';

class OsLegalContractsTemplatesTab extends StatelessWidget {
  const OsLegalContractsTemplatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final ctrl = Get.find<OsLegalContractsController>();
    final templates = ctrl.templates;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: templates.length,
      itemBuilder: (context, i) {
        final t = templates[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                    OsLegalContractTargetBadge(targetType: t.targetType),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  t.description,
                  style: TextStyle(fontSize: 13, color: theme.secondaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocaleKeys.osLegalContractClausesCount.trParams({
                    'count': '${t.clauses.length}',
                  }),
                  style: TextStyle(fontSize: 12, color: theme.mutedText),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    onPressed: () => showOsLegalContractFormDialog(
                      context,
                      template: t,
                    ),
                    style: OsButtonStyles.primaryCompact(),
                    icon: const Icon(Icons.edit_document, size: 18),
                    label: Text(AppLocaleKeys.osLegalContractUseTemplate.tr),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
