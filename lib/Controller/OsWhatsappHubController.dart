import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsCrmController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsWhatsappLogModel.dart';
import 'package:point/Models/Os/os_crm_activity.dart';
import 'package:point/Services/firestore/firestore_os_whatsapp_api.dart';
import 'package:point/Services/os_whatsapp_service.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/Utils/os_stream_binding.dart';
import 'package:point/Models/Os/os_whatsapp_enums.dart';
import 'package:point/View/Os/Invoices/os_invoice_print.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_log_display.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsWhatsappHubController extends GetxController {
  final logs = <OsWhatsappLogModel>[].obs;
  final templates = <OsWhatsappTemplateModel>[].obs;
  final isSending = false.obs;
  final isLoadingTemplates = false.obs;

  final selectedClientId = RxnString();
  final recipientPhone = ''.obs;
  final recipientName = ''.obs;
  final selectedTemplateName = RxnString();
  final bodyParameters = <String>[].obs;
  final headerParameters = <String>[].obs;

  final selectedInvoiceId = RxnString();

  /// Template vs free-form session message (Send tab).
  final crmSendMode = OsWhatsappHubSendMode.template.obs;

  /// Template vs session for invoice PDF (Invoices tab).
  final invoiceSendMode = OsWhatsappHubSendMode.template.obs;

  final sessionMessageText = ''.obs;

  final isCheckingSessionWindow = false.obs;
  final sessionWindowOpen = false.obs;
  final sessionWindowTracked = false.obs;
  final sessionWindowExpiresAt = Rxn<DateTime>();

  Worker? _sessionPhoneWorker;

  OsFinanceController? _finance;
  OsCrmController? _crm;

  @override
  void onInit() {
    super.onInit();
    _bindStreams();
    _loadTemplates();
    _applyInitialArguments();
    _sessionPhoneWorker = debounce(
      recipientPhone,
      (_) => refreshSessionWindow(),
      time: const Duration(milliseconds: 600),
    );
  }

  @override
  void onClose() {
    _sessionPhoneWorker?.dispose();
    super.onClose();
  }

  Future<void> refreshSessionWindow() async {
    final phone = recipientPhone.value.trim();
    if (phone.isEmpty) {
      sessionWindowOpen.value = false;
      sessionWindowTracked.value = false;
      sessionWindowExpiresAt.value = null;
      return;
    }
    isCheckingSessionWindow.value = true;
    try {
      final status =
          await OsWhatsappService.instance.checkSessionWindow(phone);
      if (status == null) {
        sessionWindowOpen.value = false;
        sessionWindowTracked.value = false;
        sessionWindowExpiresAt.value = null;
        return;
      }
      sessionWindowOpen.value = status.open;
      sessionWindowTracked.value = status.tracked;
      sessionWindowExpiresAt.value = status.expiresAt;
    } finally {
      isCheckingSessionWindow.value = false;
    }
  }

  bool isSessionSendBlocked(String mode) {
    if (mode != OsWhatsappHubSendMode.session) return false;
    if (recipientPhone.value.trim().isEmpty) return true;
    if (isCheckingSessionWindow.value) return true;
    return !sessionWindowOpen.value;
  }

  String buildSessionWindowHintText() {
    if (recipientPhone.value.trim().isEmpty) {
      return AppLocaleKeys.osMessagingHubSessionHint.tr;
    }
    if (isCheckingSessionWindow.value) {
      return AppLocaleKeys.osMessagingHubSessionHint.tr;
    }
    if (!sessionWindowTracked.value) {
      return AppLocaleKeys.osMessagingHubSessionNotTracked.tr;
    }
    if (sessionWindowOpen.value) {
      final exp = sessionWindowExpiresAt.value;
      if (exp != null) {
        return AppLocaleKeys.osMessagingHubSessionOpenUntil.trParams({
          'time': DateFormat('yyyy-MM-dd HH:mm').format(exp.toLocal()),
        });
      }
      return AppLocaleKeys.osMessagingHubSessionHint.tr;
    }
    return AppLocaleKeys.osMessagingHubSessionBlocked.tr;
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
  }

  Future<void> _loadTemplates() async {
    isLoadingTemplates.value = true;
    try {
      final list = await OsWhatsappService.instance.listTemplates();
      templates.assignAll(list);
      if (list.isEmpty) {
        crmSendMode.value = OsWhatsappHubSendMode.session;
      } else if (selectedTemplateName.value == null) {
        final safe = crmSafeTemplates;
        if (safe.isNotEmpty) {
          selectTemplate(safe.first.name);
        } else {
          crmSendMode.value = OsWhatsappHubSendMode.session;
        }
      } else if (selectedTemplate?.hasCallPermissionRequest == true) {
        final safe = crmSafeTemplates;
        selectTemplate(safe.isNotEmpty ? safe.first.name : null);
      }
      if (selectedInvoiceId.value != null &&
          selectedInvoiceId.value!.trim().isNotEmpty) {
        ensureInvoiceDocumentTemplate();
      }
    } finally {
      isLoadingTemplates.value = false;
    }
  }

  Future<void> refreshTemplates() => _loadTemplates();

  List<ClientModel> get clients {
    if (!Get.isRegistered<HomeController>()) return const [];
    return Get.find<HomeController>().clients;
  }

  /// Templates allowed on the Send tab (excludes call-permission).
  List<OsWhatsappTemplateModel> get crmSafeTemplates {
    return templates
        .where((t) => !t.hasCallPermissionRequest)
        .toList(growable: false);
  }

  List<OsInvoiceModel> get unpaidInvoices {
    final all = _finance?.invoices.toList() ?? const <OsInvoiceModel>[];
    return all.where((i) => !i.isPaid).toList(growable: false);
  }

  /// Approved templates with document header, no call-permission buttons.
  List<OsWhatsappTemplateModel> get invoiceTemplates {
    return templates
        .where((t) => t.isEligibleForInvoiceSend)
        .toList(growable: false);
  }

  /// Any approved template safe to pair with an invoice PDF (no call-permission).
  List<OsWhatsappTemplateModel> get invoiceSafeTemplates {
    return templates
        .where((t) => !t.hasCallPermissionRequest)
        .toList(growable: false);
  }

  bool get canUseInvoiceTemplateMode => invoiceSafeTemplates.isNotEmpty;

  OsWhatsappTemplateModel? get selectedInvoiceSafeTemplate {
    final t = selectedTemplate;
    if (t != null && !t.hasCallPermissionRequest) return t;
    return null;
  }

  OsWhatsappTemplateModel? get selectedInvoiceTemplate {
    final t = selectedTemplate;
    if (t != null && t.isEligibleForInvoiceSend) return t;
    return null;
  }

  /// Pick a document-capable template when sending invoices (template mode).
  void ensureInvoiceDocumentTemplate() {
    if (!canUseInvoiceTemplateMode) {
      invoiceSendMode.value = OsWhatsappHubSendMode.session;
      selectedTemplateName.value = null;
      bodyParameters.clear();
      headerParameters.clear();
      return;
    }
    if (invoiceSendMode.value == OsWhatsappHubSendMode.session) return;
    final list = invoiceSafeTemplates;
    if (list.isEmpty) return;
    final current = selectedTemplate;
    if (current != null && !current.hasCallPermissionRequest) return;
    selectTemplate(list.first.name);
  }

  void setCrmSendMode(String mode) {
    crmSendMode.value = mode;
    if (mode == OsWhatsappHubSendMode.session) {
      refreshSessionWindow();
    }
  }

  void setInvoiceSendMode(String mode) {
    if (mode == OsWhatsappHubSendMode.template && !canUseInvoiceTemplateMode) {
      invoiceSendMode.value = OsWhatsappHubSendMode.session;
      return;
    }
    invoiceSendMode.value = mode;
    if (mode == OsWhatsappHubSendMode.session) {
      _prefillInvoiceSessionMessage();
      refreshSessionWindow();
    } else {
      ensureInvoiceDocumentTemplate();
    }
  }

  OsWhatsappTemplateModel? get selectedTemplate {
    final name = selectedTemplateName.value;
    if (name == null) return null;
    for (final t in templates) {
      if (t.name == name) return t;
    }
    return null;
  }

  OsInvoiceModel? get selectedInvoice {
    final id = selectedInvoiceId.value;
    if (id == null) {
      final list = unpaidInvoices;
      return list.isNotEmpty ? list.first : null;
    }
    for (final inv in unpaidInvoices) {
      if (inv.id == id) return inv;
    }
    final list = unpaidInvoices;
    return list.isNotEmpty ? list.first : null;
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

  void selectClient(String? id) {
    selectedClientId.value = id;
    final client = clientById(id);
    if (client == null) return;
    recipientName.value = client.name?.trim() ?? '';
    recipientPhone.value = client.phone?.trim() ?? '';
    refreshSessionWindow();
  }

  void selectTemplate(String? name) {
    selectedTemplateName.value = name;
    final t = selectedTemplate;
    if (t == null) {
      bodyParameters.clear();
      headerParameters.clear();
      return;
    }
    if (t.hasCallPermissionRequest) {
      selectedTemplateName.value = null;
      bodyParameters.clear();
      headerParameters.clear();
      return;
    }
    bodyParameters.assignAll(List.filled(t.bodyPlaceholderCount, ''));
    headerParameters.assignAll(List.filled(t.headerTextPlaceholderCount, ''));
  }

  void selectInvoice(String? id) {
    selectedInvoiceId.value = id;
    if (id != null) _prefillFromInvoice(id);
  }

  Future<void> _prefillInvoiceSessionMessage() async {
    final inv = selectedInvoice;
    if (inv == null) return;
    var link = '';
    final paymentLink = await resolveOsInvoicePaymentLink(inv);
    if (paymentLink != null && paymentLink.isNotEmpty) link = paymentLink;
    final ref = OsFinanceFormat.invoiceRef(inv);
    final amount = OsFinanceFormat.money(inv.total);
    sessionMessageText.value = AppLocaleKeys.osInvoicesWhatsappBody.trParams({
      'ref': ref,
      'amount': amount,
      'link': link,
    });
  }

  Future<void> _prefillFromInvoice(String invoiceId) async {
    OsInvoiceModel? inv;
    for (final item in unpaidInvoices) {
      if (item.id == invoiceId) {
        inv = item;
        break;
      }
    }
    if (inv == null) return;

    if (!canUseInvoiceTemplateMode) {
      invoiceSendMode.value = OsWhatsappHubSendMode.session;
    } else {
      ensureInvoiceDocumentTemplate();
    }

    if (invoiceSendMode.value == OsWhatsappHubSendMode.session) {
      await _prefillInvoiceSessionMessage();
    }

    final client = osInvoiceClient(inv);
    if (client != null) {
      selectClient(client.id);
    }

    final ref = OsFinanceFormat.invoiceRef(inv);
    final amount = OsFinanceFormat.money(inv.total);
    var link = '';
    final paymentLink = await resolveOsInvoicePaymentLink(inv);
    if (paymentLink != null) link = paymentLink;

    _autoFillParams(
      clientName: client?.name ?? '',
      company: client?.company ?? '',
      invoiceRef: ref,
      amount: amount,
      paymentLink: link,
    );
  }

  void _autoFillParams({
    String clientName = '',
    String company = '',
    String invoiceRef = '',
    String amount = '',
    String paymentLink = '',
  }) {
    final filled = <String>[
      if (clientName.isNotEmpty) clientName,
      if (company.isNotEmpty) company,
      if (invoiceRef.isNotEmpty) invoiceRef,
      if (amount.isNotEmpty) amount,
      if (paymentLink.isNotEmpty) paymentLink,
    ];
    if (bodyParameters.isEmpty) return;
    for (var i = 0; i < bodyParameters.length && i < filled.length; i++) {
      bodyParameters[i] = filled[i];
    }
    bodyParameters.refresh();
  }

  /// PDF name shown in the WhatsApp-style preview when sending an invoice.
  String? get previewDocumentFilename {
    final inv = selectedInvoice;
    if (inv != null && selectedInvoiceId.value != null) {
      return osInvoicePdfFilename(inv);
    }
    final t = selectedTemplate;
    if (t == null || !t.hasDocumentHeader) return null;
    if (inv != null) return osInvoicePdfFilename(inv);
    return null;
  }

  bool get previewShowsFollowUpInvoicePdf {
    final inv = selectedInvoice;
    if (inv == null || selectedInvoiceId.value == null) return false;
    final t = selectedTemplate;
    if (t == null) return true;
    return !t.hasDocumentHeader;
  }

  String? get sessionPreviewDocumentFilename {
    final inv = selectedInvoice;
    if (inv != null && invoiceSendMode.value == OsWhatsappHubSendMode.session) {
      return osInvoicePdfFilename(inv);
    }
    return null;
  }

  String buildPreviewText() {
    final t = selectedTemplate;
    if (t == null) return '';
    var text = t.previewBodyText();
    for (var i = 0; i < bodyParameters.length; i++) {
      final idx = i + 1;
      text = text.replaceAll('{{$idx}}', bodyParameters[i]);
    }
    for (var i = 0; i < headerParameters.length; i++) {
      final idx = i + 1;
      text = text.replaceAll('{{$idx}}', headerParameters[i]);
    }
    return text;
  }

  bool get isApiReady {
    final status = OsWhatsappService.instance.cachedSettings;
    return status?.isReadyForSend ?? false;
  }

  Future<bool> sendCurrent({
    required String category,
    String? referenceId,
    String? documentBase64,
    String? documentFilename,
  }) async {
    if (!isApiReady) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubNotConfigured.tr,
      );
      return false;
    }

    final phone = recipientPhone.value.trim();
    if (phone.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubRecipientPhone.tr,
      );
      return false;
    }

    final template = selectedTemplate;
    if (template == null || template.name.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubSelectTemplate.tr,
      );
      return false;
    }

    if (category == OsWhatsappCategory.invoice &&
        template.hasCallPermissionRequest) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubErrorCallPermission.tr,
      );
      return false;
    }

    isSending.value = true;
    try {
      final preview = buildPreviewText();
      final result = await OsWhatsappService.instance.sendTemplate(
        toPhone: phone,
        templateName: template.name,
        languageCode: template.language.isEmpty ? 'ar' : template.language,
        bodyParameters: bodyParameters.toList(),
        headerParameters: headerParameters.toList(),
        referenceId: referenceId,
        recipientName: recipientName.value,
        category: category,
        preview: preview.isEmpty ? template.name : preview,
        documentBase64: documentBase64,
        documentFilename: documentFilename,
        templateHasDocumentHeader: template.hasDocumentHeader,
      );

      if (!result.success) {
        final detail = _formatWhatsappSendError(result);
        OsSnackbar.error(
          AppLocaleKeys.osMessagingHubTitle.tr,
          detail,
        );
        return false;
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
    } finally {
      isSending.value = false;
    }

    OsSnackbar.success(
      AppLocaleKeys.osMessagingHubTitle.tr,
      AppLocaleKeys.osMessagingHubSentSuccess.tr,
    );
    return true;
  }

  String _formatWhatsappSendError(OsWhatsappSendResult result) {
    return whatsappLogErrorForUi(result.errorMessage);
  }

  Future<bool> _sendSession({
    required String category,
    String? referenceId,
    String? documentBase64,
    String? documentFilename,
  }) async {
    if (!isApiReady) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubNotConfigured.tr,
      );
      return false;
    }

    final phone = recipientPhone.value.trim();
    if (phone.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubRecipientPhone.tr,
      );
      return false;
    }

    final text = sessionMessageText.value.trim();
    final hasDoc =
        documentBase64 != null && documentBase64.isNotEmpty;
    if (text.isEmpty && !hasDoc) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubSessionMessageRequired.tr,
      );
      return false;
    }

    await refreshSessionWindow();
    if (isSessionSendBlocked(OsWhatsappHubSendMode.session)) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        buildSessionWindowHintText(),
      );
      return false;
    }

    isSending.value = true;
    try {
      final preview = text.isNotEmpty
          ? text
          : (documentFilename ?? AppLocaleKeys.osMessagingHubPreviewDocument.tr);
      final result = await OsWhatsappService.instance.sendSession(
        toPhone: phone,
        text: text.isEmpty ? null : text,
        referenceId: referenceId,
        recipientName: recipientName.value,
        category: category,
        preview: preview,
        documentBase64: documentBase64,
        documentFilename: documentFilename,
      );

      if (!result.success) {
        OsSnackbar.error(
          AppLocaleKeys.osMessagingHubTitle.tr,
          _formatWhatsappSendError(result),
        );
        return false;
      }

      final clientId = selectedClientId.value;
      if (clientId != null &&
          clientId.isNotEmpty &&
          _crm != null &&
          Get.isRegistered<OsCrmController>()) {
        await _crm!.logActivity(
          clientId,
          OsCrmActivityType.whatsapp,
          preview,
        );
      }
    } finally {
      isSending.value = false;
    }

    OsSnackbar.success(
      AppLocaleKeys.osMessagingHubTitle.tr,
      AppLocaleKeys.osMessagingHubSentSuccess.tr,
    );
    return true;
  }

  Future<void> sendFromSendTab() async {
    if (crmSendMode.value == OsWhatsappHubSendMode.session ||
        crmSafeTemplates.isEmpty) {
      await _sendSession(category: OsWhatsappCategory.crm);
      return;
    }
    await sendCurrent(category: OsWhatsappCategory.crm);
  }

  Future<void> sendFromInvoiceTab() async {
    final inv = selectedInvoice;
    if (inv == null) return;

    if (invoiceSendMode.value == OsWhatsappHubSendMode.session ||
        !canUseInvoiceTemplateMode) {
      isSending.value = true;
      Uint8List? pdfBytes;
      try {
        pdfBytes = await generateOsInvoiceClientCopyPdfBytes(inv);
      } finally {
        isSending.value = false;
      }
      if (pdfBytes == null || pdfBytes.isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osMessagingHubTitle.tr,
          AppLocaleKeys.osMessagingHubInvoicePdfFailed.tr,
        );
        return;
      }
      if (sessionMessageText.value.trim().isEmpty) {
        await _prefillInvoiceSessionMessage();
      }
      await _sendSession(
        category: OsWhatsappCategory.invoice,
        referenceId: inv.id,
        documentBase64: base64Encode(pdfBytes),
        documentFilename: osInvoicePdfFilename(inv),
      );
      return;
    }

    if (selectedInvoiceSafeTemplate == null) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubSelectTemplate.tr,
      );
      return;
    }

    isSending.value = true;
    Uint8List? pdfBytes;
    try {
      pdfBytes = await generateOsInvoiceClientCopyPdfBytes(inv);
    } finally {
      isSending.value = false;
    }
    if (pdfBytes == null || pdfBytes.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osMessagingHubTitle.tr,
        AppLocaleKeys.osMessagingHubInvoicePdfFailed.tr,
      );
      return;
    }
    await sendCurrent(
      category: OsWhatsappCategory.invoice,
      referenceId: inv.id,
      documentBase64: base64Encode(pdfBytes),
      documentFilename: osInvoicePdfFilename(inv),
    );
  }
}
