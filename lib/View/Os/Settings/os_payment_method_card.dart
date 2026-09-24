import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';

/// Shared layout for one invoice payment method on the settings tab.
class OsPaymentMethodCard extends StatelessWidget {
  const OsPaymentMethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.configured,
    required this.configuredLabel,
    required this.notConfiguredLabel,
    required this.enabled,
    required this.onEnabledChanged,
    required this.switchBusy,
    required this.bankAccountId,
    required this.onBankAccountChanged,
    this.bankFieldEnabled = true,
    required this.onEditCredentials,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool configured;
  final String configuredLabel;
  final String notConfiguredLabel;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final bool switchBusy;
  final String? bankAccountId;
  final ValueChanged<String?> onBankAccountChanged;
  final bool bankFieldEnabled;
  final VoidCallback onEditCredentials;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final finance = Get.find<OsFinanceController>();
    final chipColor =
        configured ? const Color(0xFF059669) : theme.mutedText;
    final chipBg = configured
        ? const Color(0xFF059669).withValues(alpha: 0.12)
        : theme.panelTint;

    return Material(
      color: theme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: theme.accentText),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (switchBusy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: enabled,
                    onChanged: onEnabledChanged,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: configured
                      ? chipColor.withValues(alpha: 0.35)
                      : theme.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    configured
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 14,
                    color: chipColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      configured ? configuredLabel : notConfiguredLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: chipColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(bankAccountId),
              initialValue: bankAccountId,
              decoration: osDialogFieldDecoration(context).copyWith(
                labelText:
                    AppLocaleKeys.osSettingsCardProviderDefaultAccount.tr,
              ),
              items: [
                for (final a in finance.bankAccounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: bankFieldEnabled ? onBankAccountChanged : null,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onEditCredentials,
              style: OsButtonStyles.outlinedCompact(theme),
              icon: const Icon(Icons.tune_outlined, size: 18),
              label: Text(AppLocaleKeys.osSettingsPaymentMethodsConfigure.tr),
            ),
          ],
        ),
      ),
    );
  }
}
