import 'dart:convert';

import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsCrmController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/OsWhatsappLogModel.dart';
import 'package:point/Models/Os/os_crm_activity.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Models/Os/os_whatsapp_enums.dart';
import 'package:point/Models/Os/os_whatsapp_template_map.dart';
import 'package:point/Services/os_whatsapp_service.dart';
import 'package:point/Utils/os_whatsapp_field_values.dart';
import 'package:point/Utils/os_whatsapp_pdf_builder.dart';
import 'package:point/Utils/os_whatsapp_template_vars.dart';
import 'package:point/Utils/whatsapp_phone.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/Messaging/os_messaging_hub_navigation.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_log_display.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_missing_fields_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

const _recipientPhoneId = 'recipient_phone';

class _OsWhatsappQuickSendPayload {
  const _OsWhatsappQuickSendPayload({
    required this.purpose,
    required this.context,
    required this.recipientName,
    this.clientId,
    this.invoice,
    this.quotation,
    this.voucher,
    this.contract,
    this.payslip,
    this.employeeId,
  });

  final String purpose;
  final OsWhatsappSendContext context;
  final String recipientName;
  final String? clientId;
  final OsInvoiceModel? invoice;
  final OsQuotationModel? quotation;
  final OsVoucherModel? voucher;
  final OsLegalContractModel? contract;
  final OsPayslipModel? payslip;
  final String? employeeId;
}

Future<void> sendOsInvoiceViaWhatsapp(OsInvoiceModel invoice) async {
  final ctx = await osWhatsappContextForInvoice(invoice);
  final client = osInvoiceClient(invoice);
  await _quickSend(
    _OsWhatsappQuickSendPayload(
      purpose: OsWhatsappTemplatePurpose.invoice,
      context: ctx,
      recipientName: _nameFromContext(ctx, invoice.clientName),
      clientId: _nonEmpty(client?.id) ?? _nonEmpty(invoice.clientId),
      invoice: invoice,
    ),
  );
}

Future<void> sendOsQuotationViaWhatsapp(OsQuotationModel quote) async {
  final client = _clientById(quote.clientId);
  final ctx = osWhatsappContextForQuotation(quote, client);
  await _quickSend(
    _OsWhatsappQuickSendPayload(
      purpose: OsWhatsappTemplatePurpose.quotation,
      context: ctx,
      recipientName: _nameFromContext(ctx, quote.clientName),
      clientId: _nonEmpty(client?.id) ?? _nonEmpty(quote.clientId),
      quotation: quote,
    ),
  );
}

String osWhatsappPurposeForVoucher(OsVoucherModel voucher) {
  return voucher.type == OsVoucherType.receipt
      ? OsWhatsappTemplatePurpose.paymentReceipt
      : OsWhatsappTemplatePurpose.paymentConfirmation;
}

Future<void> sendOsVoucherViaWhatsapp(OsVoucherModel voucher) async {
  final purpose = osWhatsappPurposeForVoucher(voucher);
  OsInvoiceModel? linked;
  if (Get.isRegistered<OsFinanceController>() &&
      (voucher.invoiceId?.trim().isNotEmpty ?? false)) {
    linked = osWhatsappInvoiceForVoucher(
      voucher,
      Get.find<OsFinanceController>().invoices.toList(),
    );
  }
  final client = _clientById(linked?.clientId);
  final ctx = osWhatsappContextForVoucher(
    voucher,
    linkedInvoice: linked,
    client: client,
  );
  await _quickSend(
    _OsWhatsappQuickSendPayload(
      purpose: purpose,
      context: ctx,
      recipientName: voucher.payeeOrPayer.trim(),
      clientId: client?.id,
      voucher: voucher,
      invoice: linked,
    ),
  );
}

Future<void> sendOsContractViaWhatsapp(OsLegalContractModel contract) async {
  await _quickSend(
    _OsWhatsappQuickSendPayload(
      purpose: OsWhatsappTemplatePurpose.contract,
      context: osWhatsappContextForContract(contract),
      recipientName: contract.targetName.trim().isNotEmpty
          ? contract.targetName.trim()
          : contract.partyTwoCompany.trim(),
      contract: contract,
      employeeId: _nonEmpty(contract.targetId),
    ),
  );
}

Future<void> sendOsPayslipViaWhatsapp(OsPayslipModel payslip) async {
  await _quickSend(
    _OsWhatsappQuickSendPayload(
      purpose: OsWhatsappTemplatePurpose.payslip,
      context: osWhatsappContextForPayslip(payslip),
      recipientName: payslip.employeeName.trim(),
      payslip: payslip,
      employeeId: _nonEmpty(payslip.employeeId),
    ),
  );
}

String? _nonEmpty(String? value) {
  final t = value?.trim() ?? '';
  return t.isEmpty ? null : t;
}

ClientModel? _clientById(String? clientId) {
  final id = _nonEmpty(clientId);
  if (id == null || !Get.isRegistered<HomeController>()) return null;
  for (final c in Get.find<HomeController>().clients) {
    if (c.id == id) return c;
  }
  return null;
}

String _nameFromContext(OsWhatsappSendContext ctx, String fallback) {
  final name = ctx.client?.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  final snap = fallback.trim();
  return snap.isNotEmpty ? snap : AppLocaleKeys.osCommonDash.tr;
}

String _resolveRecipientPhone(_OsWhatsappQuickSendPayload payload) {
  final ctx = payload.context;
  final fromClient = ctx.client?.phone?.trim();
  if (fromClient != null && fromClient.isNotEmpty) {
    return normalizeWhatsappPhone(fromClient) ?? fromClient;
  }
  final fromInvoice = ctx.invoice?.clientPhone?.trim();
  if (fromInvoice != null && fromInvoice.isNotEmpty) {
    return normalizeWhatsappPhone(fromInvoice) ?? fromInvoice;
  }
  final fromQuote = ctx.quotation?.clientPhone?.trim();
  if (fromQuote != null && fromQuote.isNotEmpty) {
    return normalizeWhatsappPhone(fromQuote) ?? fromQuote;
  }
  final fromContract = ctx.contract?.partyTwoPhone.trim();
  if (fromContract != null && fromContract.isNotEmpty) {
    return normalizeWhatsappPhone(fromContract) ?? fromContract;
  }
  final voucher = payload.voucher;
  if (voucher != null) {
    final fromVoucher = osWhatsappRecipientPhoneForVoucher(
      voucher,
      linkedInvoice: ctx.invoice,
      client: ctx.client,
    );
    if (fromVoucher.isNotEmpty) {
      return normalizeWhatsappPhone(fromVoucher) ?? fromVoucher;
    }
  }
  if (payload.employeeId != null && Get.isRegistered<HomeController>()) {
    for (final emp in Get.find<HomeController>().employees) {
      if (emp.id == payload.employeeId) {
        final phone = emp.phone?.trim();
        if (phone != null && phone.isNotEmpty) {
          return normalizeWhatsappPhone(phone) ?? phone;
        }
        break;
      }
    }
  }
  return '';
}

Future<void> _quickSend(_OsWhatsappQuickSendPayload initial) async {
  final ready = await ensureOsWhatsappApiAvailable();
  if (!ready) return;

  final templatesResult = await OsWhatsappService.instance.listTemplatesWithMap();
  final mapEntry = templatesResult.map.primaryForPurpose(initial.purpose);
  if (mapEntry == null) {
    OsSnackbar.error(
      AppLocaleKeys.osMessagingHubTitle.tr,
      AppLocaleKeys.osWhatsappQuickSendNoTemplate.tr,
    );
    return;
  }

  OsWhatsappTemplateModel? template;
  for (final t in templatesResult.templates) {
    if (t.name == mapEntry.templateName &&
        t.language == mapEntry.languageCode) {
      template = t;
      break;
    }
  }
  if (template == null) {
    OsSnackbar.error(
      AppLocaleKeys.osMessagingHubTitle.tr,
      AppLocaleKeys.osMessagingHubNoTemplates.tr,
    );
    return;
  }

  if (template.hasCallPermissionRequest) {
    OsSnackbar.error(
      AppLocaleKeys.osMessagingHubTitle.tr,
      AppLocaleKeys.osMessagingHubErrorCallPermission.tr,
    );
    return;
  }

  var payload = initial;
  var manualByToken = <String, String>{};
  var recipientPhone = _resolveRecipientPhone(payload);

  while (true) {
    final values = osWhatsappValuesFromMap(
      mapEntry.placeholderFields,
      payload.context,
      manualByToken: manualByToken,
    );
    final missing = osWhatsappCollectMissingFields(
      recipientPhone: recipientPhone,
      mapEntry: mapEntry,
      resolvedValues: values,
    );
    if (missing.isEmpty) break;

    final filled = await showOsWhatsappMissingFieldsDialog(fields: missing);
    if (filled == null) return;

    final phoneFilled = filled[_recipientPhoneId]?.trim();
    if (phoneFilled != null && phoneFilled.isNotEmpty) {
      recipientPhone = normalizeWhatsappPhone(phoneFilled) ?? phoneFilled;
    }

    for (final e in filled.entries) {
      if (e.key == _recipientPhoneId) continue;
      manualByToken[e.key] = e.value;
    }

    await _persistMissingFields(
      payload: payload,
      mapEntry: mapEntry,
      filled: filled,
      recipientPhone: recipientPhone,
    );

    payload = await _reloadPayload(payload);
    recipientPhone = _resolveRecipientPhone(payload);
  }

  final effectiveValues = osWhatsappValuesFromMap(
    mapEntry.placeholderFields,
    payload.context,
    manualByToken: manualByToken,
  );
  final templatePlaceholders = osWhatsappExtractPlaceholders(template);
  for (final placeholder in templatePlaceholders) {
    if ((effectiveValues[placeholder.token] ?? '').trim().isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubTemplateParamsIncomplete.tr,
      );
      return;
    }
  }

  if (recipientPhone.trim().isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osMessagingHubTitle.tr,
      AppLocaleKeys.osMessagingHubRecipientPhone.tr,
    );
    return;
  }

  final lockedTemplate = template;
  final built = osWhatsappBuildGraphParameters(lockedTemplate, effectiveValues);
  String? documentBase64;
  String? documentFilename;
  String? referenceId;

  final attachment = mapEntry.effectiveDocumentAttachment();
  final needsPdf = lockedTemplate.hasDocumentHeader &&
      OsWhatsappTemplateDocumentAttachment.isPdfAttachment(attachment);
  if (needsPdf) {
    final pdf = await buildOsWhatsappDocumentPdf(
      attachment: attachment,
      invoice: payload.invoice,
      quotation: payload.quotation,
      voucher: payload.voucher,
      contract: payload.contract,
      payslip: payload.payslip,
    );
    if (pdf == null) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubDocumentPdfFailed.tr,
      );
      return;
    }
    referenceId = pdf.referenceId;
    documentBase64 = base64Encode(pdf.bytes);
    documentFilename = pdf.filename;
  }

  final preview = osWhatsappSubstitutePlaceholders(
    lockedTemplate.previewBodyText(),
    effectiveValues,
  );

  final result = await OsWhatsappService.instance.sendTemplate(
    toPhone: recipientPhone,
    templateName: lockedTemplate.name,
    languageCode:
        lockedTemplate.language.isEmpty ? 'ar' : lockedTemplate.language,
    bodyParameters: built.body,
    headerParameters: built.header,
    buttonParameters: built.buttonUrlByIndex,
    referenceId: referenceId,
    recipientName: payload.recipientName,
    category: _categoryForPurpose(payload.purpose),
    preview: preview.isEmpty ? lockedTemplate.name : preview,
    documentBase64: documentBase64,
    documentFilename: documentFilename,
    templateHasDocumentHeader: needsPdf && lockedTemplate.hasDocumentHeader,
  );

  if (!result.success) {
    OsSnackbar.error(
      AppLocaleKeys.osMessagingHubTitle.tr,
      whatsappLogErrorForUi(result.errorMessage),
    );
    return;
  }

  final clientId = payload.clientId?.trim();
  if (clientId != null &&
      clientId.isNotEmpty &&
      Get.isRegistered<OsCrmController>()) {
    await Get.find<OsCrmController>().logActivity(
      clientId,
      OsCrmActivityType.whatsapp,
      preview.isEmpty ? lockedTemplate.name : preview,
    );
  }

  OsSnackbar.success(
    AppLocaleKeys.osMessagingHubTitle.tr,
    AppLocaleKeys.osMessagingHubSentSuccess.tr,
  );
}

Future<_OsWhatsappQuickSendPayload> _reloadPayload(
  _OsWhatsappQuickSendPayload payload,
) async {
  if (payload.invoice?.id != null && Get.isRegistered<OsFinanceController>()) {
    final id = payload.invoice!.id!;
    final inv = Get.find<OsFinanceController>().invoices
        .cast<OsInvoiceModel?>()
        .firstWhere((i) => i?.id == id, orElse: () => null);
    if (inv != null) {
      final ctx = await osWhatsappContextForInvoice(inv);
      return _OsWhatsappQuickSendPayload(
        purpose: payload.purpose,
        context: ctx,
        recipientName: payload.recipientName,
        clientId: payload.clientId,
        invoice: inv,
      );
    }
  }
  if (payload.quotation?.id != null && Get.isRegistered<OsFinanceController>()) {
    final id = payload.quotation!.id!;
    final quote = Get.find<OsFinanceController>().quotations
        .cast<OsQuotationModel?>()
        .firstWhere((q) => q?.id == id, orElse: () => null);
    if (quote != null) {
      return _OsWhatsappQuickSendPayload(
        purpose: payload.purpose,
        context: osWhatsappContextForQuotation(quote, _clientById(quote.clientId)),
        recipientName: payload.recipientName,
        clientId: payload.clientId,
        quotation: quote,
      );
    }
  }
  if (payload.voucher?.id != null && Get.isRegistered<OsFinanceController>()) {
    final id = payload.voucher!.id!;
    final voucher = Get.find<OsFinanceController>().vouchers
        .cast<OsVoucherModel?>()
        .firstWhere((v) => v?.id == id, orElse: () => null);
    if (voucher != null) {
      final linked = payload.invoice;
      return _OsWhatsappQuickSendPayload(
        purpose: payload.purpose,
        context: osWhatsappContextForVoucher(
          voucher,
          linkedInvoice: linked,
          client: _clientById(payload.clientId),
        ),
        recipientName: payload.recipientName,
        clientId: payload.clientId,
        voucher: voucher,
        invoice: linked,
      );
    }
  }
  if (payload.contract?.id != null &&
      Get.isRegistered<OsLegalContractsController>()) {
    final id = payload.contract!.id;
    final contract = Get.find<OsLegalContractsController>().contracts
        .cast<OsLegalContractModel?>()
        .firstWhere((c) => c?.id == id, orElse: () => null);
    if (contract != null) {
      return _OsWhatsappQuickSendPayload(
        purpose: payload.purpose,
        context: osWhatsappContextForContract(contract),
        recipientName: payload.recipientName,
        contract: contract,
        employeeId: payload.employeeId,
      );
    }
  }
  return payload;
}

Future<void> _persistMissingFields({
  required _OsWhatsappQuickSendPayload payload,
  required OsWhatsappTemplateMapEntry mapEntry,
  required Map<String, String> filled,
  required String recipientPhone,
}) async {
  final home =
      Get.isRegistered<HomeController>() ? Get.find<HomeController>() : null;
  final finance = Get.isRegistered<OsFinanceController>()
      ? Get.find<OsFinanceController>()
      : null;
  final legal = Get.isRegistered<OsLegalContractsController>()
      ? Get.find<OsLegalContractsController>()
      : null;

  if (filled.containsKey(_recipientPhoneId) && recipientPhone.isNotEmpty) {
    final clientId = payload.clientId?.trim();
    if (clientId != null && clientId.isNotEmpty && home != null) {
      final client = _clientById(clientId);
      if (client != null) {
        await home.updateClient(client.copyWith(phone: recipientPhone));
      }
    }

    final employeeId = payload.employeeId?.trim();
    if (employeeId != null && employeeId.isNotEmpty && home != null) {
      for (final emp in home.employees) {
        if (emp.id == employeeId) {
          await home.updateEmployee(emp.copyWith(phone: recipientPhone));
          break;
        }
      }
    }

    if (payload.invoice != null && finance != null) {
      await finance.saveInvoice(
        payload.invoice!.copyWith(clientPhone: recipientPhone),
      );
    }
    if (payload.quotation != null && finance != null) {
      await finance.saveQuotation(
        payload.quotation!.copyWith(clientPhone: recipientPhone),
      );
    }
    if (payload.voucher != null && finance != null) {
      await finance.saveVoucher(
        payload.voucher!.copyWith(payeePhone: recipientPhone),
      );
    }
    if (payload.contract != null && legal != null) {
      await legal.saveContract(
        payload.contract!.copyWith(partyTwoPhone: recipientPhone),
      );
    }
  }

  ClientModel? client = _clientById(payload.clientId);
  for (final e in filled.entries) {
    if (e.key == _recipientPhoneId) continue;
    final fieldKey = mapEntry.placeholderFields[e.key];
    if (fieldKey == null || fieldKey == OsWhatsappTemplateFieldKey.manual) {
      continue;
    }
    final value = e.value.trim();
    if (value.isEmpty) continue;

    switch (fieldKey) {
      case OsWhatsappTemplateFieldKey.clientName:
        if (client != null && home != null) {
          await home.updateClient(client.copyWith(name: value));
          client = client.copyWith(name: value);
        }
        if (payload.invoice != null && finance != null) {
          await finance.saveInvoice(
            payload.invoice!.copyWith(clientName: value),
          );
        }
        if (payload.quotation != null && finance != null) {
          await finance.saveQuotation(
            payload.quotation!.copyWith(clientName: value),
          );
        }
        break;
      case OsWhatsappTemplateFieldKey.company:
        if (client != null && home != null) {
          await home.updateClient(client.copyWith(company: value));
          client = client.copyWith(company: value);
        }
        break;
      case OsWhatsappTemplateFieldKey.dueDate:
        if (payload.invoice != null && finance != null) {
          await finance.saveInvoice(payload.invoice!.copyWith(dueDate: value));
        }
        break;
      case OsWhatsappTemplateFieldKey.expiryDate:
        if (payload.quotation != null && finance != null) {
          await finance.saveQuotation(
            payload.quotation!.copyWith(expiryDate: value),
          );
        }
        break;
      case OsWhatsappTemplateFieldKey.contractPartyName:
        if (payload.contract != null && legal != null) {
          await legal.saveContract(
            payload.contract!.copyWith(targetName: value),
          );
        }
        break;
      default:
        break;
    }
  }
}

String _categoryForPurpose(String purpose) {
  switch (purpose) {
    case OsWhatsappTemplatePurpose.invoice:
      return OsWhatsappCategory.invoice;
    case OsWhatsappTemplatePurpose.quotation:
    case OsWhatsappTemplatePurpose.paymentConfirmation:
    case OsWhatsappTemplatePurpose.paymentReceipt:
    case OsWhatsappTemplatePurpose.contract:
    case OsWhatsappTemplatePurpose.payslip:
      return OsWhatsappCategory.crm;
    default:
      return OsWhatsappCategory.custom;
  }
}
