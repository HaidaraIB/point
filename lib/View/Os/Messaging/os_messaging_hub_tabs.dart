import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsWhatsappHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/OsWhatsappLogModel.dart';
import 'package:point/Models/Os/os_whatsapp_enums.dart';
import 'package:point/Models/Os/os_whatsapp_template_map.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/EmailHub/OsEmailHubPage.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_form_widgets.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_log_display.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_message_preview.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_document_action_button.dart';
import 'package:point/View/Shared/phone_number_text.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/whatsapp_phone_field.dart';

String osWhatsappFieldLabel(String fieldKey) {
  switch (fieldKey) {
    case OsWhatsappTemplateFieldKey.clientName:
      return AppLocaleKeys.osWhatsappFieldClientName.tr;
    case OsWhatsappTemplateFieldKey.company:
      return AppLocaleKeys.osWhatsappFieldCompany.tr;
    case OsWhatsappTemplateFieldKey.phone:
      return AppLocaleKeys.osWhatsappFieldPhone.tr;
    case OsWhatsappTemplateFieldKey.invoiceRef:
      return AppLocaleKeys.osWhatsappFieldInvoiceRef.tr;
    case OsWhatsappTemplateFieldKey.quoteRef:
      return AppLocaleKeys.osWhatsappFieldQuoteRef.tr;
    case OsWhatsappTemplateFieldKey.amount:
      return AppLocaleKeys.osWhatsappFieldAmount.tr;
    case OsWhatsappTemplateFieldKey.total:
      return AppLocaleKeys.osWhatsappFieldTotal.tr;
    case OsWhatsappTemplateFieldKey.issueDate:
      return AppLocaleKeys.osWhatsappFieldIssueDate.tr;
    case OsWhatsappTemplateFieldKey.dueDate:
      return AppLocaleKeys.osWhatsappFieldDueDate.tr;
    case OsWhatsappTemplateFieldKey.expiryDate:
      return AppLocaleKeys.osWhatsappFieldExpiryDate.tr;
    case OsWhatsappTemplateFieldKey.paymentLink:
      return AppLocaleKeys.osWhatsappFieldPaymentLink.tr;
    case OsWhatsappTemplateFieldKey.invoiceStatus:
      return AppLocaleKeys.osWhatsappFieldInvoiceStatus.tr;
    case OsWhatsappTemplateFieldKey.voucherRef:
      return AppLocaleKeys.osWhatsappFieldVoucherRef.tr;
    case OsWhatsappTemplateFieldKey.voucherPayee:
      return AppLocaleKeys.osWhatsappFieldVoucherPayee.tr;
    case OsWhatsappTemplateFieldKey.voucherDate:
      return AppLocaleKeys.osWhatsappFieldVoucherDate.tr;
    case OsWhatsappTemplateFieldKey.contractNumber:
      return AppLocaleKeys.osWhatsappFieldContractNumber.tr;
    case OsWhatsappTemplateFieldKey.contractTitle:
      return AppLocaleKeys.osWhatsappFieldContractTitle.tr;
    case OsWhatsappTemplateFieldKey.contractPartyName:
      return AppLocaleKeys.osWhatsappFieldContractPartyName.tr;
    case OsWhatsappTemplateFieldKey.contractStartDate:
      return AppLocaleKeys.osWhatsappFieldContractStartDate.tr;
    case OsWhatsappTemplateFieldKey.contractEndDate:
      return AppLocaleKeys.osWhatsappFieldContractEndDate.tr;
    case OsWhatsappTemplateFieldKey.contractTotalValue:
      return AppLocaleKeys.osWhatsappFieldContractTotalValue.tr;
    case OsWhatsappTemplateFieldKey.payslipEmployeeName:
      return AppLocaleKeys.osWhatsappFieldPayslipEmployeeName.tr;
    case OsWhatsappTemplateFieldKey.payslipPeriod:
      return AppLocaleKeys.osWhatsappFieldPayslipPeriod.tr;
    case OsWhatsappTemplateFieldKey.payslipRef:
      return AppLocaleKeys.osWhatsappFieldPayslipRef.tr;
    case OsWhatsappTemplateFieldKey.payslipNetPay:
      return AppLocaleKeys.osWhatsappFieldPayslipNetPay.tr;
    case OsWhatsappTemplateFieldKey.manual:
      return AppLocaleKeys.osWhatsappFieldManual.tr;
    default:
      return fieldKey;
  }
}

/// Preview sample for a mapped field key in template settings.
String osWhatsappSampleValueForField(String fieldKey) {
  switch (fieldKey) {
    case OsWhatsappTemplateFieldKey.clientName:
      return 'Sample client';
    case OsWhatsappTemplateFieldKey.company:
      return 'Sample Co.';
    case OsWhatsappTemplateFieldKey.phone:
      return '+964 770 000 0000';
    case OsWhatsappTemplateFieldKey.invoiceRef:
      return 'INV-001';
    case OsWhatsappTemplateFieldKey.quoteRef:
      return 'QUO-001';
    case OsWhatsappTemplateFieldKey.amount:
      return '900 IQD';
    case OsWhatsappTemplateFieldKey.total:
      return '1,000 IQD';
    case OsWhatsappTemplateFieldKey.issueDate:
      return '2026-01-01';
    case OsWhatsappTemplateFieldKey.dueDate:
      return '2026-01-15';
    case OsWhatsappTemplateFieldKey.expiryDate:
      return '2026-02-01';
    case OsWhatsappTemplateFieldKey.paymentLink:
      return 'https://pay.example/inv-001';
    case OsWhatsappTemplateFieldKey.invoiceStatus:
      return 'Sent';
    case OsWhatsappTemplateFieldKey.voucherRef:
      return 'RCP-001';
    case OsWhatsappTemplateFieldKey.voucherPayee:
      return 'Sample client';
    case OsWhatsappTemplateFieldKey.voucherDate:
      return '2026-01-10';
    case OsWhatsappTemplateFieldKey.contractNumber:
      return 'CTR-001';
    case OsWhatsappTemplateFieldKey.contractTitle:
      return 'Service agreement';
    case OsWhatsappTemplateFieldKey.contractPartyName:
      return 'Sample client';
    case OsWhatsappTemplateFieldKey.contractStartDate:
      return '2026-01-01';
    case OsWhatsappTemplateFieldKey.contractEndDate:
      return '2026-12-31';
    case OsWhatsappTemplateFieldKey.contractTotalValue:
      return '5,000 IQD';
    case OsWhatsappTemplateFieldKey.payslipEmployeeName:
      return 'Sample employee';
    case OsWhatsappTemplateFieldKey.payslipPeriod:
      return '2026-01';
    case OsWhatsappTemplateFieldKey.payslipRef:
      return 'SLIP-001';
    case OsWhatsappTemplateFieldKey.payslipNetPay:
      return '750 IQD';
    case OsWhatsappTemplateFieldKey.manual:
      return '…';
    default:
      return '…';
  }
}

Widget osMessagingHubDocumentPdfDownloadAction(
  BuildContext context,
  OsWhatsappHubController hub,
) {
  return Obx(() {
    if (!hub.canDownloadDocumentPdf) return const SizedBox.shrink();
    final theme = context.appTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OsDocumentActionOutlinedButton(
          style: OsButtonStyles.outlinedCompact(theme),
          icon: Icons.picture_as_pdf_outlined,
          label: AppLocaleKeys.osMessagingHubDownloadDocumentPdf.tr,
          onPressed: hub.downloadActiveDocumentPdf,
        ),
      ),
    );
  });
}

Widget osMessagingHubPreviewPanel(
  BuildContext context,
  OsWhatsappHubController hub,
) {
  final theme = context.appTheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        AppLocaleKeys.osMessagingHubPreview.tr,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.secondaryText,
        ),
      ),
      const SizedBox(height: 6),
      Obx(
        () => osMessagingHubWhatsappPreview(
          context,
          hub.activeTemplate,
          valueByToken: hub.effectiveParameterValues,
          documentFilename: hub.previewDocumentFilename,
        ),
      ),
    ],
  );
}

List<Widget> osMessagingHubParameterSummary(
  BuildContext context,
  OsWhatsappHubController hub,
) {
  final entry = hub.activeMapEntry;
  if (entry == null) return const [];
  final widgets = <Widget>[];
  for (final p in hub.activePlaceholders) {
    final fieldKey = entry.placeholderFields[p.token] ?? '';
    if (fieldKey.isEmpty) continue;
    final isManual = fieldKey == OsWhatsappTemplateFieldKey.manual;
    final value = hub.effectiveParameterValues[p.token] ?? '';
    if (isManual) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: osEmailHubTextField(
            context,
            label: '{{${p.token}}}',
            value: value,
            onChanged: (v) => hub.setManualParameter(p.token, v),
          ),
        ),
      );
    } else if (value.trim().isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  osWhatsappFieldLabel(fieldKey),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTheme.secondaryText,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  return widgets;
}

Widget _noMappedTemplatesMessage(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        AppLocaleKeys.osMessagingHubNoMappedTemplates.tr,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.appTheme.secondaryText,
          fontSize: 15,
          height: 1.45,
        ),
      ),
    ),
  );
}

class OsMessagingHubSendTab extends StatelessWidget {
  const OsMessagingHubSendTab({super.key, required this.hub});

  final OsWhatsappHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (hub.isLoadingTemplates.value && hub.templates.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!hub.hasMappedPurposes) {
        return _noMappedTemplatesMessage(context);
      }

      final options = hub.purposeOptions;
      final purpose = hub.selectedPurpose.value;
      final compact = Responsive.isMobile(context);

      final formChildren = <Widget>[
        Text(
          AppLocaleKeys.osMessagingHubSelectPurpose.tr,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: context.appTheme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final selected = opt.mapEntry.mapKey() == hub.selectedMapKey.value;
            return ChoiceChip(
              label: Text(opt.label),
              selected: selected,
              onSelected: (_) => hub.selectPurposeOption(opt),
              selectedColor:
                  context.appTheme.accentText.withValues(alpha: 0.18),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        ..._recordPickers(context, hub, purpose),
        const SizedBox(height: 12),
        if (hub.clients.isNotEmpty)
          osEmailHubDocumentDropdown<ClientModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectClient.tr,
            value: hub.clientById(hub.selectedClientId.value),
            items: hub.clients,
            itemLabel: (c) => c.name?.trim().isNotEmpty == true
                ? c.name!.trim()
                : (c.company?.trim() ?? c.id ?? ''),
            onChanged: (c) => hub.selectClient(c?.id),
          ),
        if (hub.clients.isNotEmpty) const SizedBox(height: 12),
        WhatsappPhoneField(
          initialNormalized: hub.recipientPhone.value.trim().isEmpty
              ? null
              : hub.recipientPhone.value.trim(),
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osMessagingHubRecipientPhone.tr,
          ),
          onChanged: (v) => hub.recipientPhone.value = v ?? '',
        ),
        const SizedBox(height: 12),
        ...osMessagingHubParameterSummary(context, hub),
        osMessagingHubDocumentPdfDownloadAction(context, hub),
        if (!compact) ...[
          const SizedBox(height: 12),
          osMessagingHubPreviewPanel(context, hub),
        ],
      ];

      return OsEmailHubDispatchPanel(
        icon: Icons.chat_outlined,
        title: AppLocaleKeys.osMessagingHubTabSend.tr,
        subtitle: AppLocaleKeys.osMessagingHubSubtitle.tr,
        isSending: hub.isSending.value,
        sendEnabled: hub.canSend,
        onSend: hub.sendFromSendTab,
        sendLabel: AppLocaleKeys.osMessagingHubSend.tr,
        preview: compact ? osMessagingHubPreviewPanel(context, hub) : null,
        children: formChildren,
      );
    });
  }

  List<Widget> _recordPickers(
    BuildContext context,
    OsWhatsappHubController hub,
    String? purpose,
  ) {
    if (purpose == OsWhatsappTemplatePurpose.custom) {
      final attachment = hub.activeMapEntry?.effectiveDocumentAttachment();
      if (OsWhatsappTemplateDocumentAttachment.isPdfAttachment(attachment)) {
        return _pdfAttachmentRecordPickers(
          context,
          hub,
          attachment!,
          purpose,
        );
      }
      return const [];
    }

    switch (purpose) {
      case OsWhatsappTemplatePurpose.invoice:
        final invoices = hub.unpaidInvoices;
        if (invoices.isEmpty) {
          return [
            Text(
              AppLocaleKeys.osMessagingHubNoInvoices.tr,
              style: TextStyle(color: context.appTheme.secondaryText),
            ),
          ];
        }
        return [
          osEmailHubDocumentDropdown<OsInvoiceModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectInvoice.tr,
            value: hub.selectedInvoice,
            items: invoices,
            itemLabel: hub.invoiceListLabel,
            onChanged: (v) => hub.selectInvoice(v?.id),
          ),
          const SizedBox(height: 12),
        ];
      case OsWhatsappTemplatePurpose.quotation:
        final quotes = hub.quotations;
        if (quotes.isEmpty) {
          return [
            Text(
              AppLocaleKeys.osMessagingHubNoQuotations.tr,
              style: TextStyle(color: context.appTheme.secondaryText),
            ),
          ];
        }
        return [
          osEmailHubDocumentDropdown<OsQuotationModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectQuotation.tr,
            value: hub.selectedQuotation,
            items: quotes,
            itemLabel: hub.quotationListLabel,
            onChanged: (v) => hub.selectQuotation(v?.id),
          ),
          const SizedBox(height: 12),
        ];
      case OsWhatsappTemplatePurpose.paymentConfirmation:
        return _voucherRecordPicker(
          context,
          hub,
          items: hub.paymentVouchers,
          emptyMessage: AppLocaleKeys.osMessagingHubNoPaidInvoices.tr,
          label: AppLocaleKeys.osMessagingHubSelectPaidInvoice.tr,
        );
      case OsWhatsappTemplatePurpose.paymentReceipt:
        return _voucherRecordPicker(
          context,
          hub,
          items: hub.receiptVouchers,
          emptyMessage: AppLocaleKeys.osMessagingHubNoVouchers.tr,
          label: AppLocaleKeys.osMessagingHubSelectVoucher.tr,
        );
      case OsWhatsappTemplatePurpose.contract:
        final contracts = hub.contracts;
        if (contracts.isEmpty) {
          return [
            Text(
              AppLocaleKeys.osMessagingHubNoContracts.tr,
              style: TextStyle(color: context.appTheme.secondaryText),
            ),
          ];
        }
        return [
          osEmailHubDocumentDropdown<OsLegalContractModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectContract.tr,
            value: hub.selectedContract,
            items: contracts,
            itemLabel: hub.contractListLabel,
            onChanged: (v) => hub.selectContract(v?.id),
          ),
          const SizedBox(height: 12),
        ];
      case OsWhatsappTemplatePurpose.payslip:
        final payslips = hub.payslips;
        if (payslips.isEmpty) {
          return [
            Text(
              AppLocaleKeys.osMessagingHubNoPayslips.tr,
              style: TextStyle(color: context.appTheme.secondaryText),
            ),
          ];
        }
        return [
          osEmailHubDocumentDropdown<OsPayslipModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectPayslip.tr,
            value: hub.selectedPayslip,
            items: payslips,
            itemLabel: hub.payslipListLabel,
            onChanged: (v) => hub.selectPayslip(v?.id),
          ),
          const SizedBox(height: 12),
        ];
      default:
        return const [];
    }
  }

  List<Widget> _pdfAttachmentRecordPickers(
    BuildContext context,
    OsWhatsappHubController hub,
    String attachment,
    String? purpose,
  ) {
    switch (attachment) {
      case OsWhatsappTemplateDocumentAttachment.invoicePdf:
        final invoices = hub.unpaidInvoices;
        if (invoices.isEmpty) {
          return [
            Text(
              AppLocaleKeys.osMessagingHubNoInvoices.tr,
              style: TextStyle(color: context.appTheme.secondaryText),
            ),
          ];
        }
        return [
          osEmailHubDocumentDropdown<OsInvoiceModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectInvoice.tr,
            value: hub.selectedInvoice,
            items: invoices,
            itemLabel: hub.invoiceListLabel,
            onChanged: (v) => hub.selectInvoice(v?.id),
          ),
          const SizedBox(height: 12),
        ];
      case OsWhatsappTemplateDocumentAttachment.quotationPdf:
        final quotes = hub.quotations;
        if (quotes.isEmpty) {
          return [
            Text(
              AppLocaleKeys.osMessagingHubNoQuotations.tr,
              style: TextStyle(color: context.appTheme.secondaryText),
            ),
          ];
        }
        return [
          osEmailHubDocumentDropdown<OsQuotationModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectQuotation.tr,
            value: hub.selectedQuotation,
            items: quotes,
            itemLabel: hub.quotationListLabel,
            onChanged: (v) => hub.selectQuotation(v?.id),
          ),
          const SizedBox(height: 12),
        ];
      case OsWhatsappTemplateDocumentAttachment.voucherPdf:
      case OsWhatsappTemplateDocumentAttachment.receiptPdf:
        return _voucherRecordPicker(
          context,
          hub,
          items: hub.receiptVouchers,
          emptyMessage: AppLocaleKeys.osMessagingHubNoVouchers.tr,
          label: AppLocaleKeys.osMessagingHubSelectVoucher.tr,
        );
      case OsWhatsappTemplateDocumentAttachment.paymentPdf:
        return _voucherRecordPicker(
          context,
          hub,
          items: hub.paymentVouchers,
          emptyMessage: AppLocaleKeys.osMessagingHubNoPaidInvoices.tr,
          label: AppLocaleKeys.osMessagingHubSelectPaidInvoice.tr,
        );
      case OsWhatsappTemplateDocumentAttachment.contractPdf:
        final contracts = hub.contracts;
        if (contracts.isEmpty) {
          return [
            Text(
              AppLocaleKeys.osMessagingHubNoContracts.tr,
              style: TextStyle(color: context.appTheme.secondaryText),
            ),
          ];
        }
        return [
          osEmailHubDocumentDropdown<OsLegalContractModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectContract.tr,
            value: hub.selectedContract,
            items: contracts,
            itemLabel: hub.contractListLabel,
            onChanged: (v) => hub.selectContract(v?.id),
          ),
          const SizedBox(height: 12),
        ];
      case OsWhatsappTemplateDocumentAttachment.payslipPdf:
        final payslips = hub.payslips;
        if (payslips.isEmpty) {
          return [
            Text(
              AppLocaleKeys.osMessagingHubNoPayslips.tr,
              style: TextStyle(color: context.appTheme.secondaryText),
            ),
          ];
        }
        return [
          osEmailHubDocumentDropdown<OsPayslipModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectPayslip.tr,
            value: hub.selectedPayslip,
            items: payslips,
            itemLabel: hub.payslipListLabel,
            onChanged: (v) => hub.selectPayslip(v?.id),
          ),
          const SizedBox(height: 12),
        ];
      default:
        return const [];
    }
  }

  List<Widget> _voucherRecordPicker(
    BuildContext context,
    OsWhatsappHubController hub, {
    required List<OsVoucherModel> items,
    required String emptyMessage,
    required String label,
  }) {
    if (items.isEmpty) {
      return [
        Text(
          emptyMessage,
          style: TextStyle(color: context.appTheme.secondaryText),
        ),
      ];
    }
    return [
      osEmailHubDocumentDropdown<OsVoucherModel>(
        context: context,
        label: label,
        value: hub.selectedVoucher,
        items: items,
        itemLabel: hub.voucherListLabel,
        onChanged: (v) => hub.selectVoucher(v?.id),
      ),
      const SizedBox(height: 12),
    ];
  }
}

class OsMessagingHubLogsTab extends StatelessWidget {
  const OsMessagingHubLogsTab({super.key, required this.hub});

  final OsWhatsappHubController hub;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final compact = Responsive.isMobile(context);
    return Obx(() {
      final items = hub.logs;
      if (items.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 48,
                  color: theme.mutedText.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocaleKeys.osMessagingHubLogsEmpty.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.secondaryText,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.separated(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16,
          12,
          compact ? 12 : 16,
          24,
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _WhatsappLogEntryCard(
            log: items[index],
            templates: hub.templates.toList(),
          );
        },
      );
    });
  }
}

class _WhatsappLogEntryCard extends StatelessWidget {
  const _WhatsappLogEntryCard({
    required this.log,
    required this.templates,
  });

  final OsWhatsappLogModel log;
  final List<OsWhatsappTemplateModel> templates;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final failed = log.status == OsWhatsappLogStatus.failed;
    final accent = failed ? const Color(0xFFE11D48) : const Color(0xFF059669);
    final category = osWhatsappLogCategoryLabel(log.type);
    final errorText = failed && log.errorMessage.isNotEmpty
        ? whatsappLogErrorForUi(log.errorMessage)
        : null;

    return Material(
      color: theme.cardSurface,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: BorderDirectional(
              start: BorderSide(color: accent, width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _WhatsappLogStatusChip(failed: failed),
                    const SizedBox(width: 8),
                    _WhatsappLogCategoryChip(label: category),
                    if (osWhatsappLogAttachmentFilename(log) != null) ...[
                      const SizedBox(width: 8),
                      _WhatsappLogAttachmentChip(
                        label: osWhatsappLogAttachmentFilename(log)!,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      formatWhatsappLogDate(log.sentAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      log.type.toUpperCase() == OsWhatsappCategory.invoice
                          ? Icons.receipt_long_outlined
                          : Icons.chat_outlined,
                      size: 20,
                      color: theme.accentText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (log.recipientName.trim().isNotEmpty)
                            Text(
                              log.recipientName.trim(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: theme.primaryText,
                              ),
                            ),
                          if (log.recipientPhone.trim().isNotEmpty) ...[
                            if (log.recipientName.trim().isNotEmpty)
                              const SizedBox(height: 2),
                            PhoneNumberText(
                              log.recipientPhone,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.article_outlined,
                                size: 14,
                                color: theme.mutedText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  osWhatsappLogTemplateLabel(log.templateName),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (log.preview.trim().isNotEmpty ||
                    osWhatsappTemplateForLog(templates, log) != null) ...[
                  const SizedBox(height: 10),
                  osWhatsappLogMessagePreview(context, log, templates),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      errorText,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WhatsappLogStatusChip extends StatelessWidget {
  const _WhatsappLogStatusChip({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final color = failed ? const Color(0xFFE11D48) : const Color(0xFF059669);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        failed
            ? AppLocaleKeys.osMessagingHubStatusFailed.tr
            : AppLocaleKeys.osMessagingHubStatusSent.tr,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _WhatsappLogCategoryChip extends StatelessWidget {
  const _WhatsappLogCategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.appTheme.panelTint,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.appTheme.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.appTheme.secondaryText,
        ),
      ),
    );
  }
}

class _WhatsappLogAttachmentChip extends StatelessWidget {
  const _WhatsappLogAttachmentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.appTheme.accentText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.attach_file_rounded,
            size: 12,
            color: context.appTheme.accentText,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.appTheme.accentText,
            ),
          ),
        ],
      ),
    );
  }
}
