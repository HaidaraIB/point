import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsCrmController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Controller/OsPayrollController.dart';
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
import 'package:point/Services/firestore/firestore_os_whatsapp_api.dart';
import 'package:point/Services/os_whatsapp_service.dart';
import 'package:point/Utils/chat_attachment_save.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/Utils/os_stream_binding.dart';
import 'package:point/Utils/os_whatsapp_field_values.dart';
import 'package:point/Utils/os_whatsapp_pdf_builder.dart';
import 'package:point/Utils/os_whatsapp_template_vars.dart';
import 'package:point/View/Os/Invoices/os_invoice_print.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_print.dart';
import 'package:point/View/Os/Finance/os_voucher_print.dart';
import 'package:point/View/Os/Payroll/os_payslip_print.dart';
import 'package:point/View/Os/Quotations/os_quotation_print.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_log_display.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsWhatsappHubPurposeOption {
  const OsWhatsappHubPurposeOption({
    required this.purpose,
    required this.mapEntry,
    required this.label,
  });

  final String purpose;
  final OsWhatsappTemplateMapEntry mapEntry;
  final String label;
}

class OsWhatsappHubController extends GetxController {
  final logs = <OsWhatsappLogModel>[].obs;
  final templates = <OsWhatsappTemplateModel>[].obs;
  final templateMap = const OsWhatsappTemplateMapConfig().obs;
  final isSending = false.obs;
  final isLoadingTemplates = false.obs;

  final selectedClientId = RxnString();
  final recipientPhone = ''.obs;
  final recipientName = ''.obs;

  final selectedPurpose = RxnString();
  final selectedMapKey = RxnString();

  final selectedInvoiceId = RxnString();
  final selectedQuotationId = RxnString();
  final selectedVoucherId = RxnString();
  final selectedContractId = RxnString();
  final selectedPayslipId = RxnString();

  final manualParameterValues = <String, String>{}.obs;
  final resolvedParameterValues = <String, String>{}.obs;

  OsFinanceController? _finance;
  OsCrmController? _crm;
  OsLegalContractsController? _legal;
  OsPayrollController? _payroll;

  @override
  void onInit() {
    super.onInit();
    _bindStreams();
    _loadTemplates();
    _applyInitialArguments();
  }

  void applyNavigationArguments([Object? args]) {
    final map = args ?? Get.arguments;
    if (map is! Map) return;
    final clientId = map['clientId']?.toString().trim();
    if (clientId != null && clientId.isNotEmpty) {
      selectClient(clientId);
    }
    final invoiceId = map['invoiceId']?.toString().trim();
    if (invoiceId != null && invoiceId.isNotEmpty) {
      selectedInvoiceId.value = invoiceId;
      selectPurpose(OsWhatsappTemplatePurpose.invoice);
      _prefillFromInvoice(invoiceId);
    }
  }

  void _applyInitialArguments() => applyNavigationArguments();

  void _bindStreams() {
    final emp = Get.find<HomeController>().effectiveEmployee;
    final allowed = OsPermissions.canAccessModule(emp, OsModuleIds.messaging);
    bindOsListStream(
      logs,
      allowed,
      FirestoreOsWhatsappApi.streamLogs(),
    );
    if (Get.isRegistered<OsFinanceController>()) {
      _finance = Get.find<OsFinanceController>();
    }
    if (Get.isRegistered<OsCrmController>()) {
      _crm = Get.find<OsCrmController>();
    }
    if (Get.isRegistered<OsLegalContractsController>()) {
      _legal = Get.find<OsLegalContractsController>();
    }
    if (Get.isRegistered<OsPayrollController>()) {
      _payroll = Get.find<OsPayrollController>();
    }
  }

  Future<void> _loadTemplates() async {
    isLoadingTemplates.value = true;
    try {
      final result = await OsWhatsappService.instance.listTemplatesWithMap();
      templates.assignAll(result.templates);
      templateMap.value = result.map;
      _ensureDefaultPurpose();
    } finally {
      isLoadingTemplates.value = false;
    }
  }

  Future<void> refreshTemplates() => _loadTemplates();

  void _ensureDefaultPurpose() {
    if (selectedPurpose.value != null) return;
    final options = purposeOptions;
    if (options.isEmpty) return;
    selectPurposeOption(options.first);
  }

  List<ClientModel> get clients {
    if (!Get.isRegistered<HomeController>()) return const [];
    return Get.find<HomeController>().clients;
  }

  List<OsWhatsappHubPurposeOption> get purposeOptions {
    final out = <OsWhatsappHubPurposeOption>[];
    for (final entry in templateMap.value.entries) {
      if (!entry.enabled || entry.purpose == OsWhatsappTemplatePurpose.unused) {
        continue;
      }
      out.add(
        OsWhatsappHubPurposeOption(
          purpose: entry.purpose,
          mapEntry: entry,
          label: _purposeLabel(entry),
        ),
      );
    }
    out.sort(
      (a, b) => OsWhatsappTemplatePurpose.sortIndex(a.purpose)
          .compareTo(OsWhatsappTemplatePurpose.sortIndex(b.purpose)),
    );
    return out;
  }

  String _purposeLabel(OsWhatsappTemplateMapEntry entry) {
    if (entry.purpose == OsWhatsappTemplatePurpose.custom &&
        entry.customLabel.trim().isNotEmpty) {
      return entry.customLabel.trim();
    }
    switch (entry.purpose) {
      case OsWhatsappTemplatePurpose.invoice:
        return AppLocaleKeys.osWhatsappPurposeInvoice.tr;
      case OsWhatsappTemplatePurpose.quotation:
        return AppLocaleKeys.osWhatsappPurposeQuotation.tr;
      case OsWhatsappTemplatePurpose.paymentConfirmation:
        return AppLocaleKeys.osWhatsappPurposePaymentConfirmation.tr;
      case OsWhatsappTemplatePurpose.paymentReceipt:
        return AppLocaleKeys.osWhatsappPurposePaymentReceipt.tr;
      case OsWhatsappTemplatePurpose.contract:
        return AppLocaleKeys.osWhatsappPurposeContract.tr;
      case OsWhatsappTemplatePurpose.payslip:
        return AppLocaleKeys.osWhatsappPurposePayslip.tr;
      default:
        return entry.templateName;
    }
  }

  OsWhatsappTemplateMapEntry? get activeMapEntry {
    final key = selectedMapKey.value;
    if (key != null) {
      for (final e in templateMap.value.entries) {
        if (e.mapKey() == key) return e;
      }
    }
    final purpose = selectedPurpose.value;
    if (purpose == null) return null;
    return templateMap.value.primaryForPurpose(purpose);
  }

  OsWhatsappTemplateModel? templateForEntry(OsWhatsappTemplateMapEntry? entry) {
    if (entry == null) return null;
    for (final t in templates) {
      if (t.name == entry.templateName && t.language == entry.languageCode) {
        return t;
      }
    }
    return null;
  }

  OsWhatsappTemplateModel? get activeTemplate =>
      templateForEntry(activeMapEntry);

  List<OsInvoiceModel> get unpaidInvoices {
    final all = _finance?.invoices.toList() ?? const <OsInvoiceModel>[];
    return all.where((i) => !i.isPaid).toList(growable: false);
  }

  List<OsInvoiceModel> get paidInvoices {
    final all = _finance?.invoices.toList() ?? const <OsInvoiceModel>[];
    return all.where((i) => i.isPaid).toList(growable: false);
  }

  List<OsQuotationModel> get quotations {
    return _finance?.quotations.toList() ?? const <OsQuotationModel>[];
  }

  List<OsVoucherModel> get vouchers {
    return _finance?.vouchers.toList() ?? const <OsVoucherModel>[];
  }

  List<OsVoucherModel> get receiptVouchers {
    return vouchers
        .where((v) => v.type == OsVoucherType.receipt)
        .toList(growable: false);
  }

  List<OsVoucherModel> get paymentVouchers {
    return vouchers
        .where((v) => v.type == OsVoucherType.payment)
        .toList(growable: false);
  }

  List<OsVoucherModel> voucherListForPurpose(String? purpose) {
    if (purpose == OsWhatsappTemplatePurpose.paymentConfirmation) {
      return paymentVouchers;
    }
    if (purpose == OsWhatsappTemplatePurpose.paymentReceipt) {
      return receiptVouchers;
    }
    return vouchers;
  }

  List<OsVoucherModel> voucherListForAttachment(String attachment) {
    final normalized =
        OsWhatsappTemplateDocumentAttachment.normalizeAttachment(attachment);
    if (normalized == OsWhatsappTemplateDocumentAttachment.paymentPdf) {
      return paymentVouchers;
    }
    if (normalized == OsWhatsappTemplateDocumentAttachment.receiptPdf ||
        normalized == OsWhatsappTemplateDocumentAttachment.voucherPdf) {
      return receiptVouchers;
    }
    return vouchers;
  }

  List<OsLegalContractModel> get contracts {
    return _legal?.contracts.toList() ?? const <OsLegalContractModel>[];
  }

  List<OsPayslipModel> get payslips {
    return _payroll?.payslips.toList() ?? const <OsPayslipModel>[];
  }

  OsInvoiceModel? get selectedInvoice {
    final id = selectedInvoiceId.value;
    final list = _invoiceListForPurpose();
    if (id == null) return list.isNotEmpty ? list.first : null;
    for (final inv in list) {
      if (inv.id == id) return inv;
    }
    return list.isNotEmpty ? list.first : null;
  }

  OsQuotationModel? get selectedQuotation {
    final id = selectedQuotationId.value;
    final list = quotations;
    if (id == null) return list.isNotEmpty ? list.first : null;
    for (final q in list) {
      if (q.id == id) return q;
    }
    return list.isNotEmpty ? list.first : null;
  }

  OsVoucherModel? get selectedVoucher {
    final id = selectedVoucherId.value;
    final purpose = selectedPurpose.value ?? activeMapEntry?.purpose;
    final list = purpose == OsWhatsappTemplatePurpose.custom
        ? voucherListForAttachment(
            activeMapEntry?.effectiveDocumentAttachment() ??
                OsWhatsappTemplateDocumentAttachment.none,
          )
        : voucherListForPurpose(purpose);
    if (id == null) return list.isNotEmpty ? list.first : null;
    for (final v in list) {
      if (v.id == id) return v;
    }
    return list.isNotEmpty ? list.first : null;
  }

  OsLegalContractModel? get selectedContract {
    final id = selectedContractId.value;
    final list = contracts;
    if (id == null) return list.isNotEmpty ? list.first : null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return list.isNotEmpty ? list.first : null;
  }

  OsPayslipModel? get selectedPayslip {
    final id = selectedPayslipId.value;
    final list = payslips;
    if (id == null) return list.isNotEmpty ? list.first : null;
    for (final p in list) {
      if (p.id == id) return p;
    }
    return list.isNotEmpty ? list.first : null;
  }

  List<OsInvoiceModel> _invoiceListForPurpose() {
    return unpaidInvoices;
  }

  ClientModel? clientById(String? id) {
    if (id == null) return null;
    for (final c in clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  String invoiceListLabel(OsInvoiceModel inv) {
    final ref = OsFinanceFormat.invoiceRef(inv);
    return '$ref · ${OsFinanceFormat.money(inv.total)}';
  }

  String quotationListLabel(OsQuotationModel q) {
    final ref = OsFinanceFormat.quotationRef(q);
    return '$ref · ${OsFinanceFormat.money(q.total)}';
  }

  String voucherListLabel(OsVoucherModel v) {
    final ref = OsFinanceFormat.voucherRef(v);
    return '$ref · ${OsFinanceFormat.money(v.amount)}';
  }

  String contractListLabel(OsLegalContractModel contract) {
    final number = contract.contractNumber.trim();
    final title = contract.title.trim();
    if (number.isEmpty) return title;
    if (title.isEmpty) return number;
    return '$number — $title';
  }

  String payslipListLabel(OsPayslipModel slip) {
    return '${slip.employeeName} · ${slip.period} · '
        '${OsFinanceFormat.money(slip.netPay)}';
  }

  String voucherAccountName(OsVoucherModel voucher) {
    return _finance?.accountById(voucher.bankAccountId)?.name ?? '';
  }

  void selectPurpose(String purpose, {String? mapKey}) {
    selectedPurpose.value = purpose;
    if (mapKey != null) {
      selectedMapKey.value = mapKey;
    } else {
      final entry = templateMap.value.primaryForPurpose(purpose);
      selectedMapKey.value = entry?.mapKey();
    }
    manualParameterValues.clear();
    unawaited(_refreshParameterValues());
  }

  void selectPurposeOption(OsWhatsappHubPurposeOption option) {
    selectPurpose(option.purpose, mapKey: option.mapEntry.mapKey());
  }

  void selectClient(String? id) {
    selectedClientId.value = id;
    final client = clientById(id);
    if (client == null) return;
    recipientName.value = client.name?.trim() ?? '';
    recipientPhone.value = client.phone?.trim() ?? '';
    _refreshParameterValues();
  }

  void selectInvoice(String? id) {
    selectedInvoiceId.value = id;
    if (id != null) _prefillFromInvoice(id);
  }

  void selectVoucher(String? id) {
    selectedVoucherId.value = id;
    if (id != null) {
      final voucher = selectedVoucher;
      if (voucher != null) {
        final linkedInvoice = osWhatsappInvoiceForVoucher(
          voucher,
          _finance?.invoices.toList() ?? const [],
        );
        final client =
            clientById(linkedInvoice?.clientId) ?? clientById(selectedClientId.value);
        final phone = osWhatsappRecipientPhoneForVoucher(
          voucher,
          linkedInvoice: linkedInvoice,
          client: client,
        );
        if (phone.isNotEmpty) {
          recipientPhone.value = phone;
        }
        if (client != null) {
          selectedClientId.value = client.id;
          recipientName.value = client.name?.trim() ?? voucher.payeeOrPayer.trim();
        } else if (linkedInvoice != null) {
          recipientName.value = linkedInvoice.clientName.trim();
        } else {
          recipientName.value = voucher.payeeOrPayer.trim();
        }
      }
    }
    _refreshParameterValues();
  }

  void selectContract(String? id) {
    selectedContractId.value = id;
    _refreshParameterValues();
  }

  void selectPayslip(String? id) {
    selectedPayslipId.value = id;
    _refreshParameterValues();
  }

  void selectQuotation(String? id) {
    selectedQuotationId.value = id;
    if (id == null) return;
    OsQuotationModel? quote;
    for (final q in quotations) {
      if (q.id == id) {
        quote = q;
        break;
      }
    }
    if (quote == null) return;
    ClientModel? client;
    for (final c in clients) {
      if (c.id == quote.clientId) {
        client = c;
        break;
      }
    }
    if (client != null) {
      selectClient(client.id);
    } else {
      recipientName.value = quote.clientName;
      recipientPhone.value = quote.clientPhone?.trim() ?? '';
    }
    _refreshParameterValues();
  }

  Future<void> _prefillFromInvoice(String invoiceId) async {
    OsInvoiceModel? inv;
    for (final item in _invoiceListForPurpose()) {
      if (item.id == invoiceId) {
        inv = item;
        break;
      }
    }
    if (inv == null) {
      for (final item in unpaidInvoices) {
        if (item.id == invoiceId) {
          inv = item;
          break;
        }
      }
    }
    if (inv == null) return;

    final client = osInvoiceClient(inv);
    if (client != null) {
      selectClient(client.id);
    } else {
      recipientName.value = inv.clientName;
      recipientPhone.value = inv.clientPhone?.trim() ?? '';
    }
    await _refreshParameterValues();
  }

  Future<void> _refreshParameterValues() async {
    final entry = activeMapEntry;
    final template = activeTemplate;
    if (entry == null || template == null) {
      resolvedParameterValues.clear();
      return;
    }

    final purpose = entry.purpose;
    final ctx = await _buildSendContextForPurpose(purpose, entry);
    if (ctx == null) {
      resolvedParameterValues.clear();
      return;
    }

    final values = osWhatsappValuesFromMap(
      entry.placeholderFields,
      ctx,
      manualByToken: manualParameterValues,
    );
    resolvedParameterValues.assignAll(values);
    resolvedParameterValues.refresh();
  }

  Map<String, String> get effectiveParameterValues {
    final merged = <String, String>{...resolvedParameterValues};
    for (final e in manualParameterValues.entries) {
      merged[e.key] = e.value;
    }
    return merged;
  }

  void setManualParameter(String token, String value) {
    manualParameterValues[token] = value;
    manualParameterValues.refresh();
    resolvedParameterValues[token] = value;
    resolvedParameterValues.refresh();
  }

  List<OsWhatsappTemplatePlaceholder> get activePlaceholders {
    final t = activeTemplate;
    if (t == null) return const [];
    return osWhatsappExtractPlaceholders(t);
  }

  bool get hasEmptyRequiredParameter {
    final entry = activeMapEntry;
    if (entry == null) return true;
    for (final token in entry.placeholderFields.keys) {
      if ((effectiveParameterValues[token] ?? '').trim().isEmpty) {
        return true;
      }
    }
    return false;
  }

  bool get canSend {
    if (!isApiReady) return false;
    if (recipientPhone.value.trim().isEmpty) return false;
    if (activeMapEntry == null || activeTemplate == null) return false;
    if (hasEmptyRequiredParameter) return false;
    final entry = activeMapEntry!;
    final template = activeTemplate!;
    if (!_hasRequiredRecord(entry, template)) return false;
    final attachment = entry.effectiveDocumentAttachment();
    if (OsWhatsappTemplateDocumentAttachment.isPdfAttachment(attachment) &&
        template.hasDocumentHeader &&
        !_hasRecordForPdfAttachment(attachment)) {
      return false;
    }
    return true;
  }

  Future<OsWhatsappSendContext?> _buildSendContextForPurpose(
    String purpose,
    OsWhatsappTemplateMapEntry entry,
  ) async {
    switch (purpose) {
      case OsWhatsappTemplatePurpose.quotation:
        final q = selectedQuotation;
        if (q == null) return null;
        return osWhatsappContextForQuotation(
          q,
          clientById(selectedClientId.value),
        );
      case OsWhatsappTemplatePurpose.paymentConfirmation:
      case OsWhatsappTemplatePurpose.paymentReceipt:
        final voucher = selectedVoucher;
        if (voucher == null) return null;
        final linkedInvoice = osWhatsappInvoiceForVoucher(
          voucher,
          _finance?.invoices.toList() ?? const [],
        );
        return osWhatsappContextForVoucher(
          voucher,
          linkedInvoice: linkedInvoice,
          client: clientById(selectedClientId.value),
        );
      case OsWhatsappTemplatePurpose.contract:
        final contract = selectedContract;
        if (contract == null) return null;
        return osWhatsappContextForContract(contract);
      case OsWhatsappTemplatePurpose.payslip:
        final slip = selectedPayslip;
        if (slip == null) return null;
        return osWhatsappContextForPayslip(slip);
      case OsWhatsappTemplatePurpose.invoice:
        final inv = selectedInvoice;
        if (inv == null) return null;
        return await osWhatsappContextForInvoice(inv);
      case OsWhatsappTemplatePurpose.custom:
        return _buildCustomSendContext(entry);
      default:
        final client = clientById(selectedClientId.value);
        return OsWhatsappSendContext(client: client);
    }
  }

  Future<OsWhatsappSendContext?> _buildCustomSendContext(
    OsWhatsappTemplateMapEntry entry,
  ) async {
    final attachment = entry.effectiveDocumentAttachment();
    switch (attachment) {
      case OsWhatsappTemplateDocumentAttachment.invoicePdf:
        final inv = selectedInvoice;
        if (inv == null) return null;
        return await osWhatsappContextForInvoice(inv);
      case OsWhatsappTemplateDocumentAttachment.quotationPdf:
        final q = selectedQuotation;
        if (q == null) return null;
        return osWhatsappContextForQuotation(
          q,
          clientById(selectedClientId.value),
        );
      case OsWhatsappTemplateDocumentAttachment.voucherPdf:
      case OsWhatsappTemplateDocumentAttachment.receiptPdf:
      case OsWhatsappTemplateDocumentAttachment.paymentPdf:
        final voucher = selectedVoucher;
        if (voucher == null) return null;
        final linkedInvoice = osWhatsappInvoiceForVoucher(
          voucher,
          _finance?.invoices.toList() ?? const [],
        );
        return osWhatsappContextForVoucher(
          voucher,
          linkedInvoice: linkedInvoice,
          client: clientById(selectedClientId.value),
        );
      case OsWhatsappTemplateDocumentAttachment.contractPdf:
        final contract = selectedContract;
        if (contract == null) return null;
        return osWhatsappContextForContract(contract);
      case OsWhatsappTemplateDocumentAttachment.payslipPdf:
        final slip = selectedPayslip;
        if (slip == null) return null;
        return osWhatsappContextForPayslip(slip);
      default:
        final client = clientById(selectedClientId.value);
        return OsWhatsappSendContext(client: client);
    }
  }

  bool _hasRequiredRecord(
    OsWhatsappTemplateMapEntry entry,
    OsWhatsappTemplateModel template,
  ) {
    switch (entry.purpose) {
      case OsWhatsappTemplatePurpose.invoice:
        return selectedInvoice != null;
      case OsWhatsappTemplatePurpose.quotation:
        return selectedQuotation != null;
      case OsWhatsappTemplatePurpose.paymentConfirmation:
      case OsWhatsappTemplatePurpose.paymentReceipt:
        return selectedVoucher != null;
      case OsWhatsappTemplatePurpose.contract:
        return selectedContract != null;
      case OsWhatsappTemplatePurpose.payslip:
        return selectedPayslip != null;
      case OsWhatsappTemplatePurpose.custom:
        final attachment = entry.effectiveDocumentAttachment();
        if (!OsWhatsappTemplateDocumentAttachment.isPdfAttachment(attachment)) {
          return true;
        }
        return _hasRecordForPdfAttachment(attachment);
      default:
        return true;
    }
  }

  bool _hasRecordForPdfAttachment(String attachment) {
    switch (attachment) {
      case OsWhatsappTemplateDocumentAttachment.invoicePdf:
        return selectedInvoice != null;
      case OsWhatsappTemplateDocumentAttachment.quotationPdf:
        return selectedQuotation != null;
      case OsWhatsappTemplateDocumentAttachment.voucherPdf:
      case OsWhatsappTemplateDocumentAttachment.receiptPdf:
      case OsWhatsappTemplateDocumentAttachment.paymentPdf:
        return selectedVoucher != null;
      case OsWhatsappTemplateDocumentAttachment.contractPdf:
        return selectedContract != null;
      case OsWhatsappTemplateDocumentAttachment.payslipPdf:
        return selectedPayslip != null;
      default:
        return true;
    }
  }

  String _missingPdfRecordMessage(String attachment) {
    switch (attachment) {
      case OsWhatsappTemplateDocumentAttachment.quotationPdf:
        return AppLocaleKeys.osMessagingHubSelectQuotation.tr;
      case OsWhatsappTemplateDocumentAttachment.voucherPdf:
      case OsWhatsappTemplateDocumentAttachment.receiptPdf:
        return AppLocaleKeys.osMessagingHubSelectVoucher.tr;
      case OsWhatsappTemplateDocumentAttachment.paymentPdf:
        return AppLocaleKeys.osMessagingHubSelectPaidInvoice.tr;
      case OsWhatsappTemplateDocumentAttachment.contractPdf:
        return AppLocaleKeys.osMessagingHubSelectContract.tr;
      case OsWhatsappTemplateDocumentAttachment.payslipPdf:
        return AppLocaleKeys.osMessagingHubSelectPayslip.tr;
      default:
        return AppLocaleKeys.osMessagingHubSelectInvoice.tr;
    }
  }

  String? get previewDocumentFilename {
    final entry = activeMapEntry;
    final template = activeTemplate;
    if (entry == null || template == null) return null;
    final attachment = entry.effectiveDocumentAttachment();
    if (!OsWhatsappTemplateDocumentAttachment.isPdfAttachment(attachment)) {
      return null;
    }
    if (!template.hasDocumentHeader) return null;
    switch (attachment) {
      case OsWhatsappTemplateDocumentAttachment.invoicePdf:
        final inv = selectedInvoice;
        return inv == null ? null : osInvoicePdfFilename(inv);
      case OsWhatsappTemplateDocumentAttachment.quotationPdf:
        final q = selectedQuotation;
        return q == null ? null : osQuotationPdfFilename(q);
      case OsWhatsappTemplateDocumentAttachment.voucherPdf:
      case OsWhatsappTemplateDocumentAttachment.receiptPdf:
      case OsWhatsappTemplateDocumentAttachment.paymentPdf:
        final v = selectedVoucher;
        return v == null ? null : osVoucherPdfFilename(v);
      case OsWhatsappTemplateDocumentAttachment.contractPdf:
        final c = selectedContract;
        return c == null ? null : osLegalContractPdfFilename(c);
      case OsWhatsappTemplateDocumentAttachment.payslipPdf:
        final p = selectedPayslip;
        return p == null ? null : osPayslipPdfFilename(p);
      default:
        return null;
    }
  }

  bool get canDownloadDocumentPdf =>
      kIsWeb && (previewDocumentFilename?.isNotEmpty ?? false);

  Future<void> downloadActiveDocumentPdf() async {
    final title = AppLocaleKeys.osMessagingHubTitle.tr;
    isSending.value = true;
    try {
      final built = await _buildDocumentPdfBytes();
      if (built == null) {
        OsSnackbar.error(
          title,
          AppLocaleKeys.osMessagingHubDocumentPdfFailed.tr,
        );
        return;
      }
      final result = await saveChatAttachmentBytes(
        bytes: built.bytes,
        fileName: built.filename,
      );
      if (result.ok) {
        OsSnackbar.success(
          title,
          AppLocaleKeys.osMessagingHubDocumentPdfDone.tr,
        );
      } else {
        OsSnackbar.error(
          title,
          AppLocaleKeys.osMessagingHubDocumentPdfFailed.tr,
        );
      }
    } finally {
      isSending.value = false;
    }
  }

  Future<({Uint8List bytes, String filename, String? referenceId})?>
      _buildDocumentPdfBytes() async {
    final entry = activeMapEntry;
    final template = activeTemplate;
    if (entry == null || template == null) return null;
    final attachment = entry.effectiveDocumentAttachment();
    if (!OsWhatsappTemplateDocumentAttachment.isPdfAttachment(attachment)) {
      return null;
    }
    if (!template.hasDocumentHeader) return null;

    final built = await buildOsWhatsappDocumentPdf(
      attachment: attachment,
      invoice: selectedInvoice,
      quotation: selectedQuotation,
      voucher: selectedVoucher,
      contract: selectedContract,
      payslip: selectedPayslip,
    );
    if (built == null) return null;
    return (
      bytes: built.bytes,
      filename: built.filename,
      referenceId: built.referenceId,
    );
  }

  String buildPreviewText() {
    final t = activeTemplate;
    if (t == null) return '';
    return osWhatsappSubstitutePlaceholders(
      t.previewBodyText(),
      effectiveParameterValues,
    );
  }

  bool get isApiReady {
    final status = OsWhatsappService.instance.cachedSettings;
    return status?.isReadyForSend ?? false;
  }

  bool get hasMappedPurposes => purposeOptions.isNotEmpty;

  Future<void> sendActive() async {
    await _sendMapped(purpose: selectedPurpose.value);
  }

  Future<void> sendFromSendTab() async {
    await _sendMapped(purpose: selectedPurpose.value);
  }

  Future<void> _sendMapped({String? purpose}) async {
    if (!isApiReady) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubNotConfigured.tr,
      );
      return;
    }

    final entry = activeMapEntry;
    final template = activeTemplate;
    if (entry == null || template == null) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubNoMappedTemplates.tr,
      );
      return;
    }

    final phone = recipientPhone.value.trim();
    if (phone.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubRecipientPhone.tr,
      );
      return;
    }

    if (hasEmptyRequiredParameter) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubTemplateParamsIncomplete.tr,
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

    await _refreshParameterValues();

    final built = osWhatsappBuildGraphParameters(
      template,
      effectiveParameterValues,
    );

    String? documentBase64;
    String? documentFilename;
    final category = _categoryForPurpose(entry.purpose);
    String? referenceId;

    final attachment = entry.effectiveDocumentAttachment();
    final needsPdf = template.hasDocumentHeader &&
        OsWhatsappTemplateDocumentAttachment.isPdfAttachment(attachment);
    if (needsPdf) {
      if (!template.hasDocumentHeader) {
        OsSnackbar.error(
          AppLocaleKeys.osMessagingHubTitle.tr,
          AppLocaleKeys.osMessagingHubInvoiceTemplateDocumentRequired.tr,
        );
        return;
      }
      isSending.value = true;
      ({Uint8List bytes, String filename, String? referenceId})? pdf;
      try {
        pdf = await _buildDocumentPdfBytes();
      } finally {
        isSending.value = false;
      }
      if (pdf == null) {
        OsSnackbar.error(
          AppLocaleKeys.osMessagingHubTitle.tr,
          _missingPdfRecordMessage(attachment),
        );
        return;
      }
      referenceId = pdf.referenceId;
      documentBase64 = base64Encode(pdf.bytes);
      documentFilename = pdf.filename;
    }

    isSending.value = true;
    try {
      final preview = buildPreviewText();
      final result = await OsWhatsappService.instance.sendTemplate(
        toPhone: phone,
        templateName: template.name,
        languageCode: template.language.isEmpty ? 'ar' : template.language,
        bodyParameters: built.body,
        headerParameters: built.header,
        buttonParameters: built.buttonUrlByIndex,
        referenceId: referenceId,
        recipientName: recipientName.value,
        category: category,
        preview: preview.isEmpty ? template.name : preview,
        documentBase64: documentBase64,
        documentFilename: documentFilename,
        templateHasDocumentHeader:
            needsPdf && template.hasDocumentHeader,
      );

      if (!result.success) {
        OsSnackbar.error(
          AppLocaleKeys.osMessagingHubTitle.tr,
          whatsappLogErrorForUi(result.errorMessage),
        );
        return;
      }

      final clientId = selectedClientId.value;
      if (clientId != null &&
          clientId.isNotEmpty &&
          _crm != null &&
          Get.isRegistered<OsCrmController>()) {
        await _crm!.logActivity(
          clientId,
          OsCrmActivityType.whatsapp,
          preview.isEmpty ? template.name : preview,
        );
      }

      OsSnackbar.success(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubSentSuccess.tr,
      );
    } finally {
      isSending.value = false;
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

  void ensureInvoicePurposeSelected() {
    selectPurpose(OsWhatsappTemplatePurpose.invoice);
  }
}
