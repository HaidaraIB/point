import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/OsEmailHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsEmailSettings.dart';
import 'package:point/Models/Os/os_hr_letter_enums.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';

class OsEmailHubPreviewFrame extends StatelessWidget {
  const OsEmailHubPreviewFrame({
    super.key,
    required this.child,
    required this.settings,
  });

  final Widget child;
  final OsEmailSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: theme.accentText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleKeys.osEmailHubPreviewTitle.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.panelTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  AppLocaleKeys.osEmailHubPreviewBadge.tr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.mutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.panelTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.accentText,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        settings.senderName.isNotEmpty
                            ? settings.senderName.characters.first
                            : 'N',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: theme.primaryText,
                            ),
                          ),
                          Text(
                            settings.senderEmail,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                child,
                if (settings.signatureText.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: theme.border),
                  Text(
                    settings.signatureText.trim(),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.mutedText,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OsEmailHubInvoicePreview extends StatelessWidget {
  const OsEmailHubInvoicePreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final inv = hub.selectedInvoice;
      if (inv == null) return const SizedBox.shrink();
      final theme = context.appTheme;
      final settings = hub.settings.value;
      final ref = OsFinanceFormat.invoiceRef(inv);

      return OsEmailHubPreviewFrame(
        settings: settings,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _metaRow(
              theme,
              '${inv.clientName} (${hub.invoiceRecipientEmail.value})',
              hub.invoiceEmailSubject(),
            ),
            const SizedBox(height: 10),
            if (hub.invoiceCustomNote.value.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.cardSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    right: BorderSide(color: theme.accentText, width: 3),
                  ),
                ),
                child: Text(
                  hub.invoiceCustomNote.value.trim(),
                  style: TextStyle(fontSize: 12, color: theme.primaryText),
                ),
              ),
            const SizedBox(height: 10),
            if (inv.items.isNotEmpty)
              ...inv.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.primaryText,
                          ),
                        ),
                      ),
                      Text(
                        '${item.quantity} × ${OsFinanceFormat.money(item.total)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.cardSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    OsFinanceFormat.money(inv.total),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: theme.accentText,
                    ),
                  ),
                  Text(
                    '${AppLocaleKeys.osInvoicesDueDate.tr}: ${inv.dueDate}',
                    style: TextStyle(fontSize: 11, color: theme.secondaryText),
                  ),
                ],
              ),
            ),
            if (hub.invoiceIncludeBankDetails.value &&
                hub.selectedBank != null) ...[
              const SizedBox(height: 8),
              Text(
                AppLocaleKeys.osEmailHubBankDetails.trParams({
                  'name': hub.selectedBank!.name,
                  'number': OsFinanceFormat.accountNumberLabel(
                    hub.selectedBank!.accountNumber,
                  ),
                }),
                style: TextStyle(fontSize: 11, color: theme.secondaryText),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              ref,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: theme.mutedText,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class OsEmailHubQuotationPreview extends StatelessWidget {
  const OsEmailHubQuotationPreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final quote = hub.selectedQuote;
      if (quote == null) return const SizedBox.shrink();
      final theme = context.appTheme;
      return OsEmailHubPreviewFrame(
        settings: hub.settings.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _metaRow(
              theme,
              '${quote.clientName} (${hub.quoteRecipientEmail.value})',
              hub.quotationEmailSubject(),
            ),
            if (hub.quoteIntroMessage.value.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                hub.quoteIntroMessage.value.trim(),
                style: TextStyle(fontSize: 12, color: theme.primaryText),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              OsFinanceFormat.money(quote.total),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: theme.accentText,
              ),
            ),
            Text(
              '${AppLocaleKeys.osQuotationsExpiry.tr}: ${quote.expiryDate}',
              style: TextStyle(fontSize: 11, color: theme.secondaryText),
            ),
          ],
        ),
      );
    });
  }
}

class OsEmailHubPayslipPreview extends StatelessWidget {
  const OsEmailHubPayslipPreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final emp = hub.selectedPayslipEmployee;
      if (emp == null) return const SizedBox.shrink();
      final theme = context.appTheme;
      final basic = hub.payslipBasicSalary(emp);
      final net = hub.payslipNetPay(emp);
      final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;

      return OsEmailHubPreviewFrame(
        settings: hub.settings.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hub.payslipMonth.value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: theme.accentText,
              ),
            ),
            const SizedBox(height: 8),
            _kv(theme, name, hub.employeePositionLabel(emp)),
            _kv(theme, AppLocaleKeys.osEmailHubRecipientEmail.tr,
                hub.payslipRecipientEmail.value),
            const SizedBox(height: 10),
            _moneyRow(theme, AppLocaleKeys.osPayslipsBasic.tr, basic),
            _moneyRow(
              theme,
              hub.payslipBonusNote.value.trim().isEmpty
                  ? AppLocaleKeys.osEmailHubPayslipAllowances.tr
                  : hub.payslipBonusNote.value.trim(),
              hub.payslipAllowances.value,
              positive: true,
            ),
            _moneyRow(
              theme,
              AppLocaleKeys.osEmailHubPayslipDeductions.tr,
              hub.payslipDeductions.value,
              negative: true,
            ),
            const SizedBox(height: 8),
            Text(
              OsFinanceFormat.money(net),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: theme.accentText,
              ),
            ),
            Text(
              hub.payslipPaymentMethod.value,
              style: TextStyle(fontSize: 11, color: theme.secondaryText),
            ),
          ],
        ),
      );
    });
  }
}

class OsEmailHubAppreciationPreview extends StatelessWidget {
  const OsEmailHubAppreciationPreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final emp = hub.selectedAppreciationEmployee;
      if (emp == null) return const SizedBox.shrink();
      final theme = context.appTheme;
      return OsEmailHubPreviewFrame(
        settings: hub.settings.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _metaRow(
              theme,
              hub.appreciationRecipientEmail.value,
              hub.appreciationEmailSubject(),
            ),
            const SizedBox(height: 10),
            Text(
              hub.appreciationEmailBody(),
              style: TextStyle(fontSize: 12, color: theme.primaryText, height: 1.5),
            ),
          ],
        ),
      );
    });
  }
}

class OsEmailHubPenaltyPreview extends StatelessWidget {
  const OsEmailHubPenaltyPreview({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final emp = hub.selectedPenaltyEmployee;
      if (emp == null) return const SizedBox.shrink();
      final theme = context.appTheme;
      final showDeduction =
          hub.penaltySeverity.value == OsPenaltySeverity.salaryDeduction;
      return OsEmailHubPreviewFrame(
        settings: hub.settings.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _metaRow(
              theme,
              hub.penaltyRecipientEmail.value,
              hub.penaltyEmailSubject(),
            ),
            const SizedBox(height: 10),
            Text(
              hub.penaltyEmailBody(),
              style: TextStyle(fontSize: 12, color: theme.primaryText, height: 1.5),
            ),
            if (showDeduction && hub.penaltyDeductionAmount.value > 0) ...[
              const SizedBox(height: 8),
              Text(
                AppLocaleKeys.osEmailHubPenaltiesDeductionLine.trParams({
                  'amount':
                      OsFinanceFormat.money(hub.penaltyDeductionAmount.value),
                }),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

Widget _metaRow(AppThemeExtension theme, String to, String subject) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        to,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.primaryText),
      ),
      const SizedBox(height: 4),
      Text(
        subject,
        style: TextStyle(fontSize: 11, color: theme.secondaryText),
      ),
    ],
  );
}

Widget _kv(AppThemeExtension theme, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: theme.mutedText),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.primaryText,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _moneyRow(
  AppThemeExtension theme,
  String label,
  double amount, {
  bool positive = false,
  bool negative = false,
}) {
  Color color = theme.primaryText;
  if (positive) color = Colors.green.shade700;
  if (negative) color = Colors.redAccent;
  final prefix = positive ? '+' : (negative ? '-' : '');
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: theme.secondaryText)),
        Text(
          '$prefix${OsFinanceFormat.money(amount)}',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    ),
  );
}

String formatEmailLogDate(DateTime date) {
  return DateFormat('yyyy-MM-dd HH:mm').format(date);
}
