import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsEmailHubController.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsBankAccountModel.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_form_widgets.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_helpers.dart';
import 'package:point/View/Os/EmailHub/os_email_payslip_options.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/os_hr_letter_enums.dart';
import 'package:point/View/Os/EmailHub/OsEmailHubPage.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_previews.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsEmailHubInvoicesTab extends StatelessWidget {
  const OsEmailHubInvoicesTab({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final invoices = hub.invoices;
      if (invoices.isEmpty) {
        return OsEmailHubDispatchPanel(
          icon: Icons.receipt_long_outlined,
          title: AppLocaleKeys.osEmailHubTabInvoices.tr,
          subtitle: AppLocaleKeys.osEmailHubInvoiceSubtitle.tr,
          isSending: hub.isSending.value,
          onSend: () async {},
          emptyMessage: AppLocaleKeys.osEmailHubNoInvoices.tr,
          children: const [],
        );
      }

      final inv = hub.selectedInvoice;
      return OsEmailHubDispatchPanel(
        icon: Icons.receipt_long_outlined,
        title: AppLocaleKeys.osEmailHubTabInvoices.tr,
        subtitle: AppLocaleKeys.osEmailHubInvoiceSubtitle.tr,
        isSending: hub.isSending.value,
        onSend: () => _send(context),
        children: [
          osEmailHubDocumentDropdown<OsInvoiceModel>(
            context: context,
            label: AppLocaleKeys.osEmailHubSelectInvoice.tr,
            value: inv,
            items: invoices,
            itemLabel: hub.invoiceListLabel,
            onChanged: (v) => hub.selectInvoice(v?.id),
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubRecipientEmail.tr,
            value: hub.invoiceRecipientEmail.value,
            onChanged: (v) => hub.invoiceRecipientEmail.value = v,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubCustomNote.tr,
            value: hub.invoiceCustomNote.value,
            onChanged: (v) => hub.invoiceCustomNote.value = v,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          osEmailHubSwitchRow(
            context,
            label: AppLocaleKeys.osEmailHubIncludeBankDetails.tr,
            value: hub.invoiceIncludeBankDetails.value,
            onChanged: (v) => hub.invoiceIncludeBankDetails.value = v,
          ),
          if (hub.invoiceIncludeBankDetails.value &&
              hub.bankAccounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _bankDropdown(context),
          ],
        ],
        preview: OsEmailHubInvoicePreview(hub: hub),
      );
    });
  }

  Widget _bankDropdown(BuildContext context) {
    final accounts = hub.bankAccounts;
    final selected = hub.selectedBank;
    return osEmailHubDocumentDropdown<OsBankAccountModel>(
      context: context,
      label: AppLocaleKeys.osInvoicesCollectionAccount.tr,
      value: selected,
      items: accounts,
      itemLabel: (b) => b.name,
      onChanged: (b) => hub.selectedBankAccountId.value = b?.id,
    );
  }

  Future<void> _send(BuildContext context) async {
    if (!validateHubRecipientEmail(hub.invoiceRecipientEmail.value)) return;
    final email = hub.invoiceRecipientEmail.value.trim();
    if (!await confirmSendEmail(recipientEmail: email)) return;
    final ok = await hub.sendInvoiceEmail();
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osEmailHubSentSuccess.trParams({
          'email': hub.invoiceRecipientEmail.value.trim(),
        }),
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osInvoicesErrorEmailFailed.tr,
      );
    }
  }
}

class OsEmailHubQuotationsTab extends StatelessWidget {
  const OsEmailHubQuotationsTab({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final quotes = hub.quotations;
      if (quotes.isEmpty) {
        return OsEmailHubDispatchPanel(
          icon: Icons.request_quote_outlined,
          title: AppLocaleKeys.osEmailHubTabQuotations.tr,
          subtitle: AppLocaleKeys.osEmailHubQuoteSubtitle.tr,
          isSending: hub.isSending.value,
          onSend: () async {},
          emptyMessage: AppLocaleKeys.osEmailHubNoQuotations.tr,
          children: const [],
        );
      }

      final quote = hub.selectedQuote;
      return OsEmailHubDispatchPanel(
        icon: Icons.request_quote_outlined,
        title: AppLocaleKeys.osEmailHubTabQuotations.tr,
        subtitle: AppLocaleKeys.osEmailHubQuoteSubtitle.tr,
        isSending: hub.isSending.value,
        onSend: () => _send(context),
        children: [
          osEmailHubDocumentDropdown<OsQuotationModel>(
            context: context,
            label: AppLocaleKeys.osEmailHubSelectQuotation.tr,
            value: quote,
            items: quotes,
            itemLabel: hub.quotationListLabel,
            onChanged: (v) => hub.selectQuote(v?.id),
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubRecipientEmail.tr,
            value: hub.quoteRecipientEmail.value,
            onChanged: (v) => hub.quoteRecipientEmail.value = v,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubQuoteIntro.tr,
            value: hub.quoteIntroMessage.value,
            onChanged: (v) => hub.quoteIntroMessage.value = v,
            maxLines: 4,
          ),
        ],
        preview: OsEmailHubQuotationPreview(hub: hub),
      );
    });
  }

  Future<void> _send(BuildContext context) async {
    if (!validateHubRecipientEmail(hub.quoteRecipientEmail.value)) return;
    final email = hub.quoteRecipientEmail.value.trim();
    if (!await confirmSendEmail(recipientEmail: email)) return;
    final ok = await hub.sendQuotationEmail();
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osEmailHubSentSuccess.trParams({
          'email': hub.quoteRecipientEmail.value.trim(),
        }),
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osInvoicesErrorEmailFailed.tr,
      );
    }
  }
}

class OsEmailHubPayslipsTab extends StatelessWidget {
  const OsEmailHubPayslipsTab({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final employees = hub.employees;
      if (employees.isEmpty) {
        return OsEmailHubDispatchPanel(
          icon: Icons.badge_outlined,
          title: AppLocaleKeys.osEmailHubTabPayslips.tr,
          subtitle: AppLocaleKeys.osEmailHubPayslipSubtitle.tr,
          isSending: hub.isSending.value,
          onSend: () async {},
          emptyMessage: AppLocaleKeys.osEmailHubNoEmployees.tr,
          children: const [],
        );
      }

      final emp = hub.selectedPayslipEmployee;
      return OsEmailHubDispatchPanel(
        icon: Icons.badge_outlined,
        title: AppLocaleKeys.osEmailHubTabPayslips.tr,
        subtitle: AppLocaleKeys.osEmailHubPayslipSubtitle.tr,
        isSending: hub.isSending.value,
        onSend: () => _send(context),
        secondaryLabel: AppLocaleKeys.osEmailHubPayslipSendBatch.tr,
        onSecondaryAction: () => _sendBatch(context),
        children: [
          osEmailHubDocumentDropdown<EmployeeModel>(
            context: context,
            label: AppLocaleKeys.osEmailHubPayslipSelectEmployee.tr,
            value: emp,
            items: employees,
            itemLabel: hub.payslipEmployeeListLabel,
            onChanged: (e) => hub.selectPayslipEmployee(e?.id),
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubRecipientEmail.tr,
            value: hub.payslipRecipientEmail.value,
            onChanged: (v) => hub.payslipRecipientEmail.value = v,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          osEmailHubEnumDropdown(
            context: context,
            label: AppLocaleKeys.osEmailHubPayslipMonth.tr,
            value: hub.payslipMonth.value,
            options: payslipMonthOptions(),
            labelFor: (v) => v,
            onChanged: (v) {
              if (v != null) hub.payslipMonth.value = v;
            },
          ),
          const SizedBox(height: 12),
          if (hub.payslipPaymentMethodOptionsList.isEmpty)
            Text(
              AppLocaleKeys.osEmailHubPayslipNoAccounts.tr,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            )
          else
            osEmailHubEnumDropdown(
              context: context,
              label: AppLocaleKeys.osEmailHubPayslipPaymentMethod.tr,
              value: hub.payslipPaymentMethod.value,
              options: hub.payslipPaymentMethodOptionsList,
              labelFor: (v) => v,
              onChanged: (v) {
                if (v != null) hub.payslipPaymentMethod.value = v;
              },
            ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubPayslipAllowances.tr,
            value: hub.payslipAllowances.value == 0
                ? ''
                : '${hub.payslipAllowances.value.toInt()}',
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(',', '').trim()) ?? 0;
              hub.payslipAllowances.value = n < 0 ? 0 : n;
            },
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubPayslipDeductions.tr,
            value: hub.payslipDeductions.value == 0
                ? ''
                : '${hub.payslipDeductions.value.toInt()}',
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(',', '').trim()) ?? 0;
              hub.payslipDeductions.value = n < 0 ? 0 : n;
            },
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubPayslipBonusNote.tr,
            value: hub.payslipBonusNote.value,
            onChanged: (v) => hub.payslipBonusNote.value = v,
            maxLines: 2,
          ),
        ],
        preview: OsEmailHubPayslipPreview(hub: hub),
      );
    });
  }

  Future<void> _sendBatch(BuildContext context) async {
    final count = hub.payslipBatchRecipientCount();
    if (count == 0) {
      OsSnackbar.error(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osEmailHubNoEmployeeEmail.tr,
      );
      return;
    }
    final confirmed = await confirmPayslipBatchSend(recipientCount: count);
    if (!confirmed) return;

    final result = await hub.sendPayslipBatch();
    if (result.hasAnySent) {
      OsSnackbar.success(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osEmailHubPayslipBatchResult.trParams({
          'sent': '${result.sent}',
          'skipped': '${result.skipped}',
        }),
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osInvoicesErrorEmailFailed.tr,
      );
    }
  }

  Future<void> _send(BuildContext context) async {
    if (!validateHubEmployeeEmail(hub.payslipRecipientEmail.value)) return;
    final email = hub.payslipRecipientEmail.value.trim();
    if (!await confirmSendEmail(recipientEmail: email)) return;
    final ok = await hub.sendPayslipEmail();
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osEmailHubSentSuccess.trParams({
          'email': hub.payslipRecipientEmail.value.trim(),
        }),
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osInvoicesErrorEmailFailed.tr,
      );
    }
  }
}

class OsEmailHubAppreciationTab extends StatelessWidget {
  const OsEmailHubAppreciationTab({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final employees = hub.employees;
      if (employees.isEmpty) {
        return OsEmailHubDispatchPanel(
          icon: Icons.military_tech_outlined,
          title: AppLocaleKeys.osEmailHubTabAppreciation.tr,
          subtitle: AppLocaleKeys.osEmailHubAppreciationSubtitle.tr,
          isSending: hub.isSending.value,
          onSend: () async {},
          emptyMessage: AppLocaleKeys.osEmailHubNoEmployees.tr,
          children: const [],
        );
      }

      final emp = hub.selectedAppreciationEmployee;
      return OsEmailHubDispatchPanel(
        icon: Icons.military_tech_outlined,
        title: AppLocaleKeys.osEmailHubTabAppreciation.tr,
        subtitle: AppLocaleKeys.osEmailHubAppreciationSubtitle.tr,
        isSending: hub.isSending.value,
        onSend: () => _send(context),
        children: [
          osEmailHubDocumentDropdown<EmployeeModel>(
            context: context,
            label: AppLocaleKeys.osEmailHubAppreciationSelectEmployee.tr,
            value: emp,
            items: employees,
            itemLabel: hub.employeeDisplayLabel,
            onChanged: (e) => hub.selectAppreciationEmployee(e?.id),
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubRecipientEmail.tr,
            value: hub.appreciationRecipientEmail.value,
            onChanged: (v) => hub.appreciationRecipientEmail.value = v,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          osEmailHubEnumDropdown(
            context: context,
            label: AppLocaleKeys.osEmailHubAppreciationType.tr,
            value: hub.appreciationType.value,
            options: OsAppreciationType.all,
            labelFor: OsEmailHubController.appreciationTypeLabel,
            onChanged: (v) {
              if (v != null) hub.appreciationType.value = v;
            },
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubAppreciationBonus.tr,
            value: hub.appreciationBonus.value == 0
                ? ''
                : '${hub.appreciationBonus.value.toInt()}',
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(',', '').trim()) ?? 0;
              hub.appreciationBonus.value = n < 0 ? 0 : n;
            },
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubAppreciationReason.tr,
            value: hub.appreciationReason.value,
            onChanged: (v) => hub.appreciationReason.value = v,
            maxLines: 4,
          ),
        ],
        preview: OsEmailHubAppreciationPreview(hub: hub),
      );
    });
  }

  Future<void> _send(BuildContext context) async {
    if (!validateHubEmployeeEmail(hub.appreciationRecipientEmail.value)) {
      return;
    }
    final email = hub.appreciationRecipientEmail.value.trim();
    if (!await confirmSendEmail(recipientEmail: email)) return;
    final ok = await hub.sendAppreciationEmail();
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osEmailHubSentSuccess.trParams({
          'email': hub.appreciationRecipientEmail.value.trim(),
        }),
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osInvoicesErrorEmailFailed.tr,
      );
    }
  }
}

class OsEmailHubPenaltiesTab extends StatelessWidget {
  const OsEmailHubPenaltiesTab({super.key, required this.hub});

  final OsEmailHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final employees = hub.employees;
      if (employees.isEmpty) {
        return OsEmailHubDispatchPanel(
          icon: Icons.warning_amber_outlined,
          title: AppLocaleKeys.osEmailHubTabPenalties.tr,
          subtitle: AppLocaleKeys.osEmailHubPenaltiesSubtitle.tr,
          isSending: hub.isSending.value,
          onSend: () async {},
          emptyMessage: AppLocaleKeys.osEmailHubNoEmployees.tr,
          children: const [],
        );
      }

      final emp = hub.selectedPenaltyEmployee;
      final showDeduction =
          hub.penaltySeverity.value == OsPenaltySeverity.salaryDeduction;
      return OsEmailHubDispatchPanel(
        icon: Icons.warning_amber_outlined,
        title: AppLocaleKeys.osEmailHubTabPenalties.tr,
        subtitle: AppLocaleKeys.osEmailHubPenaltiesSubtitle.tr,
        isSending: hub.isSending.value,
        onSend: () => _send(context),
        children: [
          osEmailHubDocumentDropdown<EmployeeModel>(
            context: context,
            label: AppLocaleKeys.osEmailHubPenaltiesSelectEmployee.tr,
            value: emp,
            items: employees,
            itemLabel: hub.employeeDisplayLabel,
            onChanged: (e) => hub.selectPenaltyEmployee(e?.id),
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubRecipientEmail.tr,
            value: hub.penaltyRecipientEmail.value,
            onChanged: (v) => hub.penaltyRecipientEmail.value = v,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          osEmailHubEnumDropdown(
            context: context,
            label: AppLocaleKeys.osEmailHubPenaltiesSeverity.tr,
            value: hub.penaltySeverity.value,
            options: OsPenaltySeverity.all,
            labelFor: (v) {
              switch (v) {
                case OsPenaltySeverity.notice:
                  return AppLocaleKeys.osEmailHubPenaltiesSeverityNotice.tr;
                case OsPenaltySeverity.firstWarning:
                  return AppLocaleKeys.osEmailHubPenaltiesSeverityFirstWarning.tr;
                case OsPenaltySeverity.finalWarning:
                  return AppLocaleKeys.osEmailHubPenaltiesSeverityFinalWarning.tr;
                case OsPenaltySeverity.salaryDeduction:
                  return AppLocaleKeys
                      .osEmailHubPenaltiesSeveritySalaryDeduction.tr;
                default:
                  return v;
              }
            },
            onChanged: (v) {
              if (v != null) hub.penaltySeverity.value = v;
            },
          ),
          if (showDeduction) ...[
            const SizedBox(height: 12),
            osEmailHubTextField(
              context,
              label: AppLocaleKeys.osEmailHubPenaltiesDeductionAmount.tr,
              value: hub.penaltyDeductionAmount.value == 0
                  ? ''
                  : '${hub.penaltyDeductionAmount.value.toInt()}',
              onChanged: (v) {
                final n = double.tryParse(v.replaceAll(',', '').trim()) ?? 0;
                hub.penaltyDeductionAmount.value = n < 0 ? 0 : n;
              },
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubPenaltiesReason.tr,
            value: hub.penaltyReason.value,
            onChanged: (v) => hub.penaltyReason.value = v,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubPenaltiesGracePeriod.tr,
            value: hub.penaltyGracePeriod.value,
            onChanged: (v) => hub.penaltyGracePeriod.value = v,
          ),
        ],
        preview: OsEmailHubPenaltyPreview(hub: hub),
      );
    });
  }

  Future<void> _send(BuildContext context) async {
    if (!validateHubEmployeeEmail(hub.penaltyRecipientEmail.value)) return;
    final email = hub.penaltyRecipientEmail.value.trim();
    if (!await confirmSendEmail(recipientEmail: email)) return;
    final ok = await hub.sendPenaltyEmail();
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osEmailHubSentSuccess.trParams({
          'email': hub.penaltyRecipientEmail.value.trim(),
        }),
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osInvoicesErrorEmailFailed.tr,
      );
    }
  }
}

// Logs and settings tabs live in os_email_hub_logs_tab.dart and
// os_email_hub_settings_tab.dart respectively.
