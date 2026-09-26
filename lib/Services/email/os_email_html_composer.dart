import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/Os/OsEmailSettings.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/os_hr_letter_enums.dart';
import 'package:point/Services/email/email_html_builders.dart';
import 'package:point/Services/email/email_html_shell.dart';
import 'package:point/View/Os/os_finance_format.dart';

/// Composes translated OS hub HTML from domain models.
class OsEmailHtmlComposer {
  OsEmailHtmlComposer._();

  static String localeFromText(String text) => EmailHtmlShell.detectLocale(text);

  static String _locale() {
    final code = Get.locale?.languageCode ?? 'ar';
    return code == 'en' ? 'en' : 'ar';
  }

  static String _signature(OsEmailSettings settings) =>
      settings.signatureText.trim();

  static String invoice({
    required OsInvoiceModel invoice,
    required OsEmailSettings settings,
    String customNote = '',
    String paymentLink = '',
  }) {
    final locale = _locale();
    final ref = OsFinanceFormat.invoiceRef(invoice);
    final greeting = AppLocaleKeys.emailTemplateGreeting.trParams({
      'name': invoice.clientName,
    });
    final intro = AppLocaleKeys.emailTemplateInvoiceIntro.trParams({
      'client': invoice.clientName,
      'ref': ref,
    });

    return EmailHtmlBuilders.invoice(
      locale: locale,
      subtitle: AppLocaleKeys.osEmailHubCategoryInvoice.tr,
      heading: AppLocaleKeys.emailTemplateInvoiceHeading.trParams({'ref': ref}),
      greeting: greeting,
      intro: intro,
      reference: ref,
      totalLabel: AppLocaleKeys.emailTemplateInvoiceTotalDue.tr,
      totalAmount: OsFinanceFormat.money(invoice.total),
      dueDateLabel: AppLocaleKeys.osInvoicesDueDate.tr,
      dueDate: invoice.dueDate,
      items: invoice.items,
      colItem: AppLocaleKeys.emailTemplateInvoiceColItem.tr,
      colQty: AppLocaleKeys.emailTemplateInvoiceColQty.tr,
      colTotal: AppLocaleKeys.emailTemplateInvoiceColTotal.tr,
      customNote: customNote,
      paymentLink: paymentLink,
      payCtaLabel: paymentLink.isNotEmpty
          ? AppLocaleKeys.emailTemplateInvoicePayCta.tr
          : '',
      settings: settings,
      signature: _signature(settings),
      preheader: OsFinanceFormat.money(invoice.total),
    );
  }

  static String quotation({
    required OsQuotationModel quote,
    required OsEmailSettings settings,
    String introMessage = '',
    String acceptLink = '',
  }) {
    final locale = _locale();
    final ref = OsFinanceFormat.quotationRef(quote);
    final greeting = AppLocaleKeys.emailTemplateGreeting.trParams({
      'name': quote.clientName,
    });
    final intro = introMessage.trim().isNotEmpty
        ? introMessage.trim()
        : AppLocaleKeys.osEmailHubQuoteDefaultIntro.tr;

    return EmailHtmlBuilders.quotation(
      locale: locale,
      subtitle: AppLocaleKeys.osEmailHubCategoryQuotation.tr,
      heading: AppLocaleKeys.emailTemplateQuotationHeading.trParams({'ref': ref}),
      greeting: greeting,
      intro: intro,
      reference: ref,
      totalLabel: AppLocaleKeys.emailTemplateQuotationTotal.tr,
      totalAmount: OsFinanceFormat.money(quote.total),
      expiryLabel: AppLocaleKeys.osQuotationsExpiry.tr,
      expiryDate: quote.expiryDate,
      acceptLink: acceptLink,
      acceptCtaLabel: acceptLink.isNotEmpty
          ? AppLocaleKeys.emailTemplateQuotationAcceptCta.tr
          : '',
      settings: settings,
      signature: _signature(settings),
      preheader: OsFinanceFormat.money(quote.total),
    );
  }

  static String payslip({
    required EmployeeModel employee,
    required OsEmailSettings settings,
    required String month,
    required double basic,
    required double allowances,
    required double deductions,
    required String allowancesLabel,
    required String paymentMethod,
    required String positionLabel,
    String note = '',
  }) {
    final locale = _locale();
    final name = employee.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    final position = positionLabel.trim().isNotEmpty
        ? positionLabel.trim()
        : AppLocaleKeys.osCommonDash.tr;
    final email = employee.email?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    final net = basic + allowances - deductions;

    return EmailHtmlBuilders.payslip(
      locale: locale,
      subtitle: AppLocaleKeys.osEmailHubCategoryPayslip.tr,
      heading: AppLocaleKeys.emailTemplatePayslipHeading.trParams({
        'period': month,
      }),
      greeting: AppLocaleKeys.emailTemplateGreeting.trParams({'name': name}),
      period: month,
      employeeName: name,
      positionLabel: AppLocaleKeys.emailTemplatePayslipPosition.tr,
      position: position,
      emailLabel: AppLocaleKeys.osEmailHubRecipientEmail.tr,
      email: email,
      earningsTitle: AppLocaleKeys.emailTemplatePayslipEarnings.tr,
      deductionsTitle: AppLocaleKeys.emailTemplatePayslipDeductionsSection.tr,
      basicLabel: AppLocaleKeys.osPayslipsBasic.tr,
      basicAmount: OsFinanceFormat.money(basic),
      allowancesLabel: allowancesLabel,
      allowancesAmount: OsFinanceFormat.money(allowances),
      deductionsLabel: AppLocaleKeys.osEmailHubPayslipDeductions.tr,
      deductionsAmount: OsFinanceFormat.money(deductions),
      netPayLabel: AppLocaleKeys.emailTemplatePayslipNetPay.tr,
      netPayAmount: OsFinanceFormat.money(net),
      paymentMethodLabel: AppLocaleKeys.osEmailHubPayslipPaymentMethod.tr,
      paymentMethod: paymentMethod,
      note: note,
      settings: settings,
      signature: _signature(settings),
      preheader: OsFinanceFormat.money(net),
    );
  }

  static String appreciation({
    required EmployeeModel employee,
    required OsEmailSettings settings,
    required String typeLabel,
    required String reason,
    required String positionLabel,
    double bonus = 0,
  }) {
    final locale = _locale();
    final name = employee.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    final position = positionLabel.trim().isNotEmpty
        ? positionLabel.trim()
        : AppLocaleKeys.osCommonDash.tr;
    final body = AppLocaleKeys.osEmailHubAppreciationBody.trParams({
      'name': name,
      'position': position,
      'type': typeLabel,
      'reason': reason,
    });
    final bonusLine = bonus > 0
        ? AppLocaleKeys.osEmailHubAppreciationBonusLine.trParams({
            'amount': OsFinanceFormat.money(bonus),
          })
        : '';

    return EmailHtmlBuilders.appreciation(
      locale: locale,
      subtitle: AppLocaleKeys.osEmailHubCategoryAppreciation.tr,
      heading: AppLocaleKeys.emailTemplateAppreciationHeading.tr,
      certificateTitle: AppLocaleKeys.emailTemplateAppreciationCertificate.tr,
      bodyText: body,
      employeeName: name,
      positionLine: position,
      reason: reason,
      bonusLine: bonusLine,
      settings: settings,
      signature: _signature(settings),
      preheader: name,
    );
  }

  static String penalty({
    required EmployeeModel employee,
    required OsEmailSettings settings,
    required String severityLabel,
    required String severityBadge,
    required String reason,
    required String gracePeriod,
    double deductionAmount = 0,
    bool showDeduction = false,
  }) {
    final locale = _locale();
    final name = employee.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    final greeting = AppLocaleKeys.osEmailHubPenaltiesBody.trParams({
      'name': name,
      'severity': severityLabel,
      'reason': reason,
      'grace': gracePeriod,
    });
    final deductionLine = showDeduction && deductionAmount > 0
        ? AppLocaleKeys.osEmailHubPenaltiesDeductionLine.trParams({
            'amount': OsFinanceFormat.money(deductionAmount),
          })
        : '';

    return EmailHtmlBuilders.penalty(
      locale: locale,
      subtitle: AppLocaleKeys.osEmailHubCategoryPenalty.tr,
      heading: AppLocaleKeys.emailTemplatePenaltyHeading.tr,
      greeting: greeting,
      severityBadge: severityBadge,
      reasonTitle: AppLocaleKeys.osEmailHubPenaltiesReason.tr,
      reason: reason,
      graceNote: AppLocaleKeys.emailTemplatePenaltyGraceNote.trParams({
        'grace': gracePeriod,
      }),
      deductionLine: deductionLine,
      settings: settings,
      signature: _signature(settings),
      preheader: severityBadge,
    );
  }

  static String contract({
    required OsLegalContractModel contract,
    required OsEmailSettings settings,
    required String startDate,
    required String amount,
  }) {
    final locale = _locale();
    final greeting = AppLocaleKeys.emailTemplateGreeting.trParams({
      'name': contract.targetName,
    });
    final body = AppLocaleKeys.osLegalContractEmailBody.trParams({
      'number': contract.contractNumber,
      'start': startDate,
      'amount': amount,
    });

    return EmailHtmlBuilders.contract(
      locale: locale,
      subtitle: AppLocaleKeys.osEmailHubCategoryContract.tr,
      heading: AppLocaleKeys.emailTemplateContractHeading.trParams({
        'title': contract.title,
      }),
      greeting: greeting,
      bodyText: body,
      contractNumberLabel: AppLocaleKeys.emailTemplateContractNumber.tr,
      contractNumber: contract.contractNumber,
      startDateLabel: AppLocaleKeys.emailTemplateContractStart.tr,
      startDate: startDate,
      amountLabel: AppLocaleKeys.emailTemplateContractAmount.tr,
      amount: amount,
      settings: settings,
      signature: _signature(settings),
      preheader: contract.contractNumber,
    );
  }

  static String penaltySeverityBadge(String severity, double amount) {
    switch (severity) {
      case OsPenaltySeverity.notice:
        return AppLocaleKeys.osEmailHubPenaltiesSeverityNoticeShort.tr;
      case OsPenaltySeverity.firstWarning:
        return AppLocaleKeys.osEmailHubPenaltiesSeverityFirstWarningShort.tr;
      case OsPenaltySeverity.finalWarning:
        return AppLocaleKeys.osEmailHubPenaltiesSeverityFinalWarningShort.tr;
      case OsPenaltySeverity.salaryDeduction:
        return AppLocaleKeys.osEmailHubPenaltiesSeveritySalaryDeductionShort
            .trParams({'amount': OsFinanceFormat.money(amount)});
      default:
        return AppLocaleKeys.osEmailHubCategoryPenalty.tr;
    }
  }
}
