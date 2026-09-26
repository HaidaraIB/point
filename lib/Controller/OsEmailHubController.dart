import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/Utils/os_stream_binding.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/Os/EmailHub/os_email_payslip_options.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/Os/OsBankAccountModel.dart';
import 'package:point/Models/Os/OsEmailLogModel.dart';
import 'package:point/Models/Os/OsEmailSettings.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/OsPayslipBatchResult.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/os_email_enums.dart';
import 'package:point/Models/Os/os_hr_letter_enums.dart';
import 'package:point/Services/firestore/firestore_os_email_api.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/email/os_email_html_composer.dart';
import 'package:point/Services/os_email_hub_draft_persistence.dart';
import 'package:point/Services/os_email_hub_service.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/Quotations/os_quotation_share.dart';
import 'package:point/View/Os/os_finance_format.dart';

class OsEmailHubController extends GetxController {
  final settings = OsEmailSettings.defaults().obs;
  final logs = <OsEmailLogModel>[].obs;
  final isSending = false.obs;
  final isSavingSettings = false.obs;

  final invoiceRecipientEmail = ''.obs;
  final invoiceCustomNote = ''.obs;
  final selectedInvoiceId = RxnString();

  final quoteRecipientEmail = ''.obs;
  final quoteIntroMessage = ''.obs;
  final selectedQuoteId = RxnString();

  final selectedPayslipEmployeeId = RxnString();
  final payslipMonth = ''.obs;
  final payslipAllowances = 150000.0.obs;
  final payslipDeductions = 0.0.obs;
  final payslipBonusNote = ''.obs;
  final payslipPaymentMethod = ''.obs;
  final payslipRecipientEmail = ''.obs;

  final selectedAppreciationEmployeeId = RxnString();
  final appreciationType = OsAppreciationType.excellence.obs;
  final appreciationBonus = 250000.0.obs;
  final appreciationReason = ''.obs;
  final appreciationRecipientEmail = ''.obs;

  final selectedPenaltyEmployeeId = RxnString();
  final penaltySeverity = OsPenaltySeverity.firstWarning.obs;
  final penaltyReason = ''.obs;
  final penaltyDeductionAmount = 50000.0.obs;
  final penaltyGracePeriod = ''.obs;
  final penaltyRecipientEmail = ''.obs;

  final selectedContractId = RxnString();
  final contractRecipientEmail = ''.obs;

  final logsSearch = ''.obs;
  final logsCategoryFilter = 'ALL'.obs;

  @override
  void onInit() {
    super.onInit();
    _bindStreams();
    _restoreDraftOrDefaults();
  }

  Future<void> _restoreDraftOrDefaults() async {
    final draft = await OsEmailHubDraftPersistence.load();
    if (draft != null) {
      _applyDraft(draft);
    } else {
      _initDefaults();
    }
    primeSelectionsIfNeeded();
    ensurePayslipPaymentMethod();
  }

  Future<void> persistDraft() => OsEmailHubDraftPersistence.save(_draftToMap());

  Map<String, dynamic> _draftToMap() => {
        'invoiceRecipientEmail': invoiceRecipientEmail.value,
        'invoiceCustomNote': invoiceCustomNote.value,
        'selectedInvoiceId': selectedInvoiceId.value,
        'quoteRecipientEmail': quoteRecipientEmail.value,
        'quoteIntroMessage': quoteIntroMessage.value,
        'selectedQuoteId': selectedQuoteId.value,
        'selectedPayslipEmployeeId': selectedPayslipEmployeeId.value,
        'payslipMonth': payslipMonth.value,
        'payslipAllowances': payslipAllowances.value,
        'payslipDeductions': payslipDeductions.value,
        'payslipBonusNote': payslipBonusNote.value,
        'payslipPaymentMethod': payslipPaymentMethod.value,
        'payslipRecipientEmail': payslipRecipientEmail.value,
        'selectedAppreciationEmployeeId': selectedAppreciationEmployeeId.value,
        'appreciationType': appreciationType.value,
        'appreciationBonus': appreciationBonus.value,
        'appreciationReason': appreciationReason.value,
        'appreciationRecipientEmail': appreciationRecipientEmail.value,
        'selectedPenaltyEmployeeId': selectedPenaltyEmployeeId.value,
        'penaltySeverity': penaltySeverity.value,
        'penaltyReason': penaltyReason.value,
        'penaltyDeductionAmount': penaltyDeductionAmount.value,
        'penaltyGracePeriod': penaltyGracePeriod.value,
        'penaltyRecipientEmail': penaltyRecipientEmail.value,
        'selectedContractId': selectedContractId.value,
        'contractRecipientEmail': contractRecipientEmail.value,
        'logsSearch': logsSearch.value,
        'logsCategoryFilter': logsCategoryFilter.value,
      };

  void _applyDraft(Map<String, dynamic> map) {
    invoiceRecipientEmail.value =
        map['invoiceRecipientEmail'] as String? ?? '';
    invoiceCustomNote.value = map['invoiceCustomNote'] as String? ?? '';
    selectedInvoiceId.value = map['selectedInvoiceId'] as String?;

    quoteRecipientEmail.value = map['quoteRecipientEmail'] as String? ?? '';
    quoteIntroMessage.value = map['quoteIntroMessage'] as String? ?? '';
    selectedQuoteId.value = map['selectedQuoteId'] as String?;

    selectedPayslipEmployeeId.value =
        map['selectedPayslipEmployeeId'] as String?;
    payslipMonth.value = map['payslipMonth'] as String? ?? '';
    payslipAllowances.value =
        (map['payslipAllowances'] as num?)?.toDouble() ?? 150000;
    payslipDeductions.value =
        (map['payslipDeductions'] as num?)?.toDouble() ?? 0;
    payslipBonusNote.value = map['payslipBonusNote'] as String? ?? '';
    payslipPaymentMethod.value =
        map['payslipPaymentMethod'] as String? ?? '';
    payslipRecipientEmail.value =
        map['payslipRecipientEmail'] as String? ?? '';

    selectedAppreciationEmployeeId.value =
        map['selectedAppreciationEmployeeId'] as String?;
    final appreciationTypeRaw = map['appreciationType'] as String?;
    if (appreciationTypeRaw != null && appreciationTypeRaw.isNotEmpty) {
      appreciationType.value = appreciationTypeRaw;
    }
    appreciationBonus.value =
        (map['appreciationBonus'] as num?)?.toDouble() ?? 250000;
    appreciationReason.value = map['appreciationReason'] as String? ?? '';
    appreciationRecipientEmail.value =
        map['appreciationRecipientEmail'] as String? ?? '';

    selectedPenaltyEmployeeId.value =
        map['selectedPenaltyEmployeeId'] as String?;
    final penaltySeverityRaw = map['penaltySeverity'] as String?;
    if (penaltySeverityRaw != null && penaltySeverityRaw.isNotEmpty) {
      penaltySeverity.value = penaltySeverityRaw;
    }
    penaltyReason.value = map['penaltyReason'] as String? ?? '';
    penaltyDeductionAmount.value =
        (map['penaltyDeductionAmount'] as num?)?.toDouble() ?? 50000;
    penaltyGracePeriod.value = map['penaltyGracePeriod'] as String? ?? '';
    penaltyRecipientEmail.value =
        map['penaltyRecipientEmail'] as String? ?? '';

    selectedContractId.value = map['selectedContractId'] as String?;
    contractRecipientEmail.value =
        map['contractRecipientEmail'] as String? ?? '';

    logsSearch.value = map['logsSearch'] as String? ?? '';
    final logsFilter = map['logsCategoryFilter'] as String?;
    if (logsFilter != null && logsFilter.isNotEmpty) {
      logsCategoryFilter.value = logsFilter;
    }
  }

  void primeSelectionsIfNeeded() {
    final finance = _finance;
    if (finance != null) {
      if (selectedInvoiceId.value == null && finance.invoices.isNotEmpty) {
        selectInvoice(finance.invoices.first.id);
      }
      if (selectedQuoteId.value == null && finance.quotations.isNotEmpty) {
        selectQuote(finance.quotations.first.id);
      }
    }
    if (employees.isNotEmpty) {
      final firstId = employees.first.id;
      if (selectedPayslipEmployeeId.value == null) {
        selectPayslipEmployee(firstId);
      }
      if (selectedAppreciationEmployeeId.value == null) {
        selectAppreciationEmployee(firstId);
      }
      if (selectedPenaltyEmployeeId.value == null) {
        selectPenaltyEmployee(firstId);
      }
    }
    if (contracts.isNotEmpty && selectedContractId.value == null) {
      selectContract(contracts.first.id);
    }
    ensurePayslipPaymentMethod();
  }

  void rebindStreamsForPermissions() => _bindStreams();

  void _bindStreams() {
    final emp = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>().effectiveEmployee
        : null;
    final emailHub = OsPermissions.canAccessModule(emp, OsModuleIds.emailHub);

    bindOsListStream(
      logs,
      emailHub,
      FirestoreOsEmailApi.streamLogs(),
    );
    bindOsValueStream(
      settings,
      emailHub,
      FirestoreOsEmailApi.streamSettings(),
      OsEmailSettings.defaults(),
    );
    if (Get.isRegistered<OsFinanceController>()) {
      ever(Get.find<OsFinanceController>().bankAccounts, (_) {
        ensurePayslipPaymentMethod();
      });
    }
  }

  List<String> get payslipPaymentMethodOptionsList =>
      payslipPaymentMethodOptions(bankAccounts);

  void ensurePayslipPaymentMethod() {
    final options = payslipPaymentMethodOptionsList;
    if (options.isEmpty) {
      payslipPaymentMethod.value = '';
      return;
    }
    if (!options.contains(payslipPaymentMethod.value)) {
      payslipPaymentMethod.value = options.first;
    }
  }

  void _initDefaults() {
    invoiceCustomNote.value = AppLocaleKeys.osEmailHubInvoiceDefaultNote.tr;
    quoteIntroMessage.value = AppLocaleKeys.osEmailHubQuoteDefaultIntro.tr;
    payslipMonth.value = defaultPayslipMonth();
    payslipBonusNote.value = AppLocaleKeys.osEmailHubPayslipDefaultBonusNote.tr;
    payslipPaymentMethod.value =
        defaultPayslipPaymentMethod(bankAccounts) ?? '';
    appreciationReason.value =
        AppLocaleKeys.osEmailHubAppreciationDefaultReason.tr;
    penaltyReason.value = AppLocaleKeys.osEmailHubPenaltiesDefaultReason.tr;
    penaltyGracePeriod.value = AppLocaleKeys.osEmailHubPenaltiesDefaultGrace.tr;
  }

  OsFinanceController? get _finance {
    if (!Get.isRegistered<OsFinanceController>()) return null;
    return Get.find<OsFinanceController>();
  }

  List<OsInvoiceModel> get invoices => _finance?.invoices.toList() ?? const [];
  List<OsQuotationModel> get quotations =>
      _finance?.quotations.toList() ?? const [];
  List<OsBankAccountModel> get bankAccounts =>
      _finance?.bankAccounts.toList() ?? const [];
  List<EmployeeModel> get employees {
    if (!Get.isRegistered<HomeController>()) return const [];
    return Get.find<HomeController>().employees.toList();
  }

  List<ClientModel> get clients {
    if (!Get.isRegistered<HomeController>()) return const [];
    return Get.find<HomeController>().clients.toList();
  }

  List<OsLegalContractModel> get contracts {
    if (!Get.isRegistered<OsLegalContractsController>()) return const [];
    return Get.find<OsLegalContractsController>().contracts.toList();
  }

  OsLegalContractModel? get selectedContract {
    final id = selectedContractId.value;
    if (id == null) return contracts.isNotEmpty ? contracts.first : null;
    for (final c in contracts) {
      if (c.id == id) return c;
    }
    return contracts.isNotEmpty ? contracts.first : null;
  }

  String contractListLabel(OsLegalContractModel contract) {
    final number = contract.contractNumber.trim();
    final title = contract.title.trim();
    if (number.isEmpty) return title;
    if (title.isEmpty) return number;
    return '$number — $title';
  }

  void syncContractRecipient() {
    final contract = selectedContract;
    contractRecipientEmail.value = contract?.partyTwoEmail.trim() ?? '';
  }

  void selectContract(String? id) {
    selectedContractId.value = id;
    syncContractRecipient();
  }

  OsInvoiceModel? get selectedInvoice {
    final id = selectedInvoiceId.value;
    if (id == null) return invoices.isNotEmpty ? invoices.first : null;
    for (final inv in invoices) {
      if (inv.id == id) return inv;
    }
    return invoices.isNotEmpty ? invoices.first : null;
  }

  OsQuotationModel? get selectedQuote {
    final id = selectedQuoteId.value;
    if (id == null) return quotations.isNotEmpty ? quotations.first : null;
    for (final q in quotations) {
      if (q.id == id) return q;
    }
    return quotations.isNotEmpty ? quotations.first : null;
  }

  EmployeeModel? get selectedPayslipEmployee =>
      _employeeById(selectedPayslipEmployeeId.value);

  double payslipBasicSalary(EmployeeModel emp) => emp.salary ?? 0;

  double payslipNetPay(EmployeeModel emp) =>
      payslipBasicSalary(emp) +
      payslipAllowances.value -
      payslipDeductions.value;

  String invoiceListLabel(OsInvoiceModel inv) {
    final ref = OsFinanceFormat.invoiceRef(inv);
    final status = OsFinanceFormat.invoiceStatusLabel(inv.status);
    return '$ref — ${inv.clientName} (${OsFinanceFormat.money(inv.total)}) [$status]';
  }

  String quotationListLabel(OsQuotationModel q) {
    final ref = OsFinanceFormat.quotationRef(q);
    final status = OsFinanceFormat.quotationStatusLabel(q.status);
    return '$ref — ${q.clientName} (${OsFinanceFormat.money(q.total)}) [$status]';
  }

  String payslipEmployeeListLabel(EmployeeModel e) {
    final name = e.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    final pos = employeePositionLabel(e);
    final salary = OsFinanceFormat.money(payslipBasicSalary(e));
    return '$name — $pos ($salary)';
  }

  void syncInvoiceRecipient() {
    final inv = selectedInvoice;
    if (inv == null) return;
    invoiceRecipientEmail.value = osInvoiceRecipientEmail(inv);
  }

  void syncQuoteRecipient() {
    final quote = selectedQuote;
    if (quote == null) return;
    final email = quote.clientEmail?.trim() ?? '';
    if (email.isNotEmpty) {
      quoteRecipientEmail.value = email;
      return;
    }
    for (final c in clients) {
      final name = c.name?.trim() ?? '';
      if (name.isNotEmpty && name == quote.clientName.trim()) {
        quoteRecipientEmail.value = c.email?.trim() ?? '';
        return;
      }
    }
    quoteRecipientEmail.value = '';
  }

  void syncPayslipRecipient() {
    final emp = selectedPayslipEmployee;
    payslipRecipientEmail.value = emp?.email?.trim() ?? '';
  }

  void selectInvoice(String? id) {
    selectedInvoiceId.value = id;
    syncInvoiceRecipient();
  }

  void selectQuote(String? id) {
    selectedQuoteId.value = id;
    syncQuoteRecipient();
  }

  void selectPayslipEmployee(String? id) {
    selectedPayslipEmployeeId.value = id;
    syncPayslipRecipient();
  }

  EmployeeModel? get selectedAppreciationEmployee =>
      _employeeById(selectedAppreciationEmployeeId.value);

  EmployeeModel? get selectedPenaltyEmployee =>
      _employeeById(selectedPenaltyEmployeeId.value);

  EmployeeModel? _employeeById(String? id) {
    if (id == null) return employees.isNotEmpty ? employees.first : null;
    for (final e in employees) {
      if (e.id == id) return e;
    }
    return employees.isNotEmpty ? employees.first : null;
  }

  String employeePositionLabel(EmployeeModel e) {
    final title = e.jobTitle?.trim() ?? '';
    if (title.isNotEmpty) return title;
    return e.role.trim();
  }

  String employeeDisplayLabel(EmployeeModel e) {
    final name = e.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    final pos = employeePositionLabel(e);
    if (pos.isEmpty) return name;
    return '$name — $pos';
  }

  void syncAppreciationRecipient() {
    final emp = selectedAppreciationEmployee;
    appreciationRecipientEmail.value = emp?.email?.trim() ?? '';
  }

  void syncPenaltyRecipient() {
    final emp = selectedPenaltyEmployee;
    penaltyRecipientEmail.value = emp?.email?.trim() ?? '';
  }

  void selectAppreciationEmployee(String? id) {
    selectedAppreciationEmployeeId.value = id;
    syncAppreciationRecipient();
  }

  void selectPenaltyEmployee(String? id) {
    selectedPenaltyEmployeeId.value = id;
    syncPenaltyRecipient();
  }

  static String appreciationTypeLabel(String type) {
    switch (type) {
      case OsAppreciationType.excellence:
        return AppLocaleKeys.osEmailHubAppreciationTypeExcellence.tr;
      case OsAppreciationType.speed:
        return AppLocaleKeys.osEmailHubAppreciationTypeSpeed.tr;
      case OsAppreciationType.employeeOfMonth:
        return AppLocaleKeys.osEmailHubAppreciationTypeEmployeeOfMonth.tr;
      case OsAppreciationType.loyalty:
        return AppLocaleKeys.osEmailHubAppreciationTypeLoyalty.tr;
      default:
        return AppLocaleKeys.osEmailHubCategoryAppreciation.tr;
    }
  }

  String penaltySeverityLabel(String severity) {
    switch (severity) {
      case OsPenaltySeverity.notice:
        return AppLocaleKeys.osEmailHubPenaltiesSeverityNoticeShort.tr;
      case OsPenaltySeverity.firstWarning:
        return AppLocaleKeys.osEmailHubPenaltiesSeverityFirstWarningShort.tr;
      case OsPenaltySeverity.finalWarning:
        return AppLocaleKeys.osEmailHubPenaltiesSeverityFinalWarningShort.tr;
      case OsPenaltySeverity.salaryDeduction:
        return AppLocaleKeys.osEmailHubPenaltiesSeveritySalaryDeductionShort
            .trParams({
          'amount': OsFinanceFormat.money(penaltyDeductionAmount.value),
        });
      default:
        return AppLocaleKeys.osEmailHubCategoryPenalty.tr;
    }
  }

  List<OsEmailLogModel> get filteredLogs {
    final q = logsSearch.value.trim().toLowerCase();
    final cat = logsCategoryFilter.value;
    return logs.where((log) {
      if (cat != 'ALL' && log.type != cat) return false;
      if (q.isEmpty) return true;
      final hay = [
        log.recipientName,
        log.recipientEmail,
        log.subject,
        log.referenceId ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  String invoiceEmailSubject() {
    final inv = selectedInvoice;
    if (inv == null) return '';
    final ref = OsFinanceFormat.invoiceRef(inv);
    return AppLocaleKeys.osInvoicesEmailSubject.trParams({'ref': ref});
  }

  Future<String> invoiceEmailBody() async {
    final inv = selectedInvoice;
    if (inv == null) return '';
    final ref = OsFinanceFormat.invoiceRef(inv);
    var body = AppLocaleKeys.osInvoicesEmailBody.trParams({
      'client': inv.clientName,
      'ref': ref,
      'amount': OsFinanceFormat.money(inv.total),
      'due': inv.dueDate,
    });
    final note = invoiceCustomNote.value.trim();
    if (note.isNotEmpty) {
      body = '$body\n\n$note';
    }
    if (!inv.isPaid) {
      final link = await resolveOsInvoicePaymentLink(inv);
      if (link != null && link.isNotEmpty) {
        body =
            '$body\n\n${AppLocaleKeys.osEmailHubPaymentLink.trParams({'link': link})}';
      }
    }
    return body;
  }

  String quotationEmailSubject() {
    final quote = selectedQuote;
    if (quote == null) return '';
    final ref = OsFinanceFormat.quotationRef(quote);
    return AppLocaleKeys.osEmailHubQuoteSubject.trParams({'ref': ref});
  }

  String quotationEmailBody() {
    final quote = selectedQuote;
    if (quote == null) return '';
    final ref = OsFinanceFormat.quotationRef(quote);
    var body = AppLocaleKeys.osEmailHubQuoteBody.trParams({
      'client': quote.clientName,
      'ref': ref,
      'amount': OsFinanceFormat.money(quote.total),
      'expiry': quote.expiryDate,
    });
    final intro = quoteIntroMessage.value.trim();
    if (intro.isNotEmpty) {
      body = '$intro\n\n$body';
    }
    final link = osQuotationAcceptLink(quote);
    body = '$body\n\n${AppLocaleKeys.osEmailHubAcceptLink.trParams({'link': link})}';
    return body;
  }

  String payslipEmailSubject(EmployeeModel emp) {
    final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    return AppLocaleKeys.osEmailHubPayslipSubject.trParams({
      'period': payslipMonth.value.trim(),
      'name': name,
    });
  }

  String payslipEmailBody(EmployeeModel emp) => _payslipEmailBody(emp);

  String appreciationEmailSubject() {
    final emp = selectedAppreciationEmployee;
    if (emp == null) return '';
    final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    return AppLocaleKeys.osEmailHubAppreciationSubject.trParams({'name': name});
  }

  String appreciationEmailBody() {
    final emp = selectedAppreciationEmployee;
    if (emp == null) return '';
    final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    final position = employeePositionLabel(emp);
    final typeLabel = appreciationTypeLabel(appreciationType.value);
    var body = AppLocaleKeys.osEmailHubAppreciationBody.trParams({
      'name': name,
      'position': position,
      'type': typeLabel,
      'reason': appreciationReason.value.trim(),
    });
    final bonus = appreciationBonus.value;
    if (bonus > 0) {
      body =
          '$body\n\n${AppLocaleKeys.osEmailHubAppreciationBonusLine.trParams({
                'amount': OsFinanceFormat.money(bonus),
              })}';
    }
    return body;
  }

  String penaltyEmailSubject() {
    final emp = selectedPenaltyEmployee;
    if (emp == null) return '';
    final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    final severity = penaltySeverityLabel(penaltySeverity.value);
    return AppLocaleKeys.osEmailHubPenaltiesSubject.trParams({
      'severity': severity,
      'name': name,
    });
  }

  String penaltyEmailBody() {
    final emp = selectedPenaltyEmployee;
    if (emp == null) return '';
    final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    final severity = penaltySeverityLabel(penaltySeverity.value);
    var body = AppLocaleKeys.osEmailHubPenaltiesBody.trParams({
      'name': name,
      'severity': severity,
      'reason': penaltyReason.value.trim(),
      'grace': penaltyGracePeriod.value.trim(),
    });
    if (penaltySeverity.value == OsPenaltySeverity.salaryDeduction &&
        penaltyDeductionAmount.value > 0) {
      body =
          '$body\n\n${AppLocaleKeys.osEmailHubPenaltiesDeductionLine.trParams({
                'amount': OsFinanceFormat.money(penaltyDeductionAmount.value),
              })}';
    }
    return body;
  }

  Future<String> invoiceEmailHtml() async {
    final inv = selectedInvoice;
    if (inv == null) return '';
    return buildOsInvoiceEmailHtml(
      invoice: inv,
      settings: settings.value,
      customNote: invoiceCustomNote.value,
    );
  }

  Future<bool> sendInvoiceEmail() async {
    final inv = selectedInvoice;
    if (inv == null) return false;
    final email = invoiceRecipientEmail.value.trim();
    if (email.isEmpty) return false;

    isSending.value = true;
    try {
      final ref = OsFinanceFormat.invoiceRef(inv);
      final subject = invoiceEmailSubject();
      final html = await invoiceEmailHtml();

      return await OsEmailHubService.sendAndLog(
        type: OsEmailCategory.invoice,
        toEmail: email,
        recipientName: inv.clientName,
        subject: subject,
        content: html,
        settings: settings.value,
        referenceId: ref,
        attachmentsCount: 1,
      );
    } finally {
      isSending.value = false;
    }
  }

  String quotationEmailHtml() {
    final quote = selectedQuote;
    if (quote == null) return '';
    return OsEmailHtmlComposer.quotation(
      quote: quote,
      settings: settings.value,
      introMessage: quoteIntroMessage.value.trim(),
      acceptLink: osQuotationAcceptLink(quote),
    );
  }

  Future<bool> sendQuotationEmail() async {
    final quote = selectedQuote;
    if (quote == null) return false;
    final email = quoteRecipientEmail.value.trim();
    if (email.isEmpty) return false;

    isSending.value = true;
    try {
      final ref = OsFinanceFormat.quotationRef(quote);
      final subject = quotationEmailSubject();
      final html = quotationEmailHtml();

      return await OsEmailHubService.sendAndLog(
        type: OsEmailCategory.quotation,
        toEmail: email,
        recipientName: quote.clientName,
        subject: subject,
        content: html,
        settings: settings.value,
        referenceId: ref,
      );
    } finally {
      isSending.value = false;
    }
  }

  String payslipEmailHtml(EmployeeModel emp) {
    final allowancesLabel = payslipBonusNote.value.trim().isEmpty
        ? AppLocaleKeys.osEmailHubPayslipAllowances.tr
        : payslipBonusNote.value.trim();
    return OsEmailHtmlComposer.payslip(
      employee: emp,
      settings: settings.value,
      month: payslipMonth.value.trim(),
      basic: payslipBasicSalary(emp),
      allowances: payslipAllowances.value,
      deductions: payslipDeductions.value,
      allowancesLabel: allowancesLabel,
      paymentMethod: payslipPaymentMethod.value.trim(),
      positionLabel: employeePositionLabel(emp),
      note: payslipBonusNote.value.trim().isEmpty
          ? AppLocaleKeys.osEmailHubPayslipDefaultNote.tr
          : payslipBonusNote.value.trim(),
    );
  }

  String _payslipEmailBody(EmployeeModel emp) {
    final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
    final basic = payslipBasicSalary(emp);
    final net = payslipNetPay(emp);
    var body = AppLocaleKeys.osEmailHubPayslipBodyDetailed.trParams({
      'name': name,
      'month': payslipMonth.value.trim(),
      'basic': OsFinanceFormat.money(basic),
      'allowances': OsFinanceFormat.money(payslipAllowances.value),
      'deductions': OsFinanceFormat.money(payslipDeductions.value),
      'net': OsFinanceFormat.money(net),
      'method': payslipPaymentMethod.value.trim(),
    });
    final note = payslipBonusNote.value.trim();
    if (note.isNotEmpty) {
      body = '$body\n\n$note';
    }
    return body;
  }

  Future<bool> sendPayslipEmail() async {
    final emp = selectedPayslipEmployee;
    if (emp == null) return false;
    final email = payslipRecipientEmail.value.trim();
    if (email.isEmpty) return false;

    isSending.value = true;
    try {
      final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
      final subject = payslipEmailSubject(emp);
      return await OsEmailHubService.sendAndLog(
        type: OsEmailCategory.payslip,
        toEmail: email,
        recipientName: name,
        subject: subject,
        content: payslipEmailHtml(emp),
        settings: settings.value,
        referenceId: emp.id,
        attachmentsCount: 1,
      );
    } finally {
      isSending.value = false;
    }
  }

  int payslipBatchRecipientCount() {
    var count = 0;
    for (final emp in employees) {
      final email = emp.email?.trim() ?? '';
      if (email.isNotEmpty && GetUtils.isEmail(email)) count++;
    }
    return count;
  }

  Future<OsPayslipBatchResult> sendPayslipBatch() async {
    if (employees.isEmpty) return const OsPayslipBatchResult();
    isSending.value = true;
    var sent = 0;
    var skipped = 0;
    var failed = 0;
    try {
      for (final emp in employees) {
        final email = emp.email?.trim() ?? '';
        if (email.isEmpty || !GetUtils.isEmail(email)) {
          skipped++;
          continue;
        }
        final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
        final subject = payslipEmailSubject(emp);
        final ok = await OsEmailHubService.sendAndLog(
          type: OsEmailCategory.payslip,
          toEmail: email,
          recipientName: name,
          subject: subject,
          content: payslipEmailHtml(emp),
          settings: settings.value,
          referenceId: emp.id,
          attachmentsCount: 1,
        );
        if (ok) {
          sent++;
        } else {
          failed++;
        }
      }
      return OsPayslipBatchResult(
        sent: sent,
        skipped: skipped,
        failed: failed,
      );
    } finally {
      isSending.value = false;
    }
  }

  Future<bool> resendLog(OsEmailLogModel log) async {
    isSending.value = true;
    try {
      final trimmed = log.content.trimLeft().toLowerCase();
      final isHtml = trimmed.startsWith('<!doctype html') ||
          trimmed.startsWith('<html');
      return await OsEmailHubService.sendAndLog(
        type: log.type,
        toEmail: log.recipientEmail,
        recipientName: log.recipientName,
        subject: log.subject,
        content: log.content,
        settings: settings.value,
        referenceId: log.referenceId,
        attachmentsCount: log.attachmentsCount,
        includeSignature: false,
        isHtml: isHtml,
      );
    } finally {
      isSending.value = false;
    }
  }

  String appreciationEmailHtml() {
    final emp = selectedAppreciationEmployee;
    if (emp == null) return '';
    return OsEmailHtmlComposer.appreciation(
      employee: emp,
      settings: settings.value,
      typeLabel: appreciationTypeLabel(appreciationType.value),
      reason: appreciationReason.value.trim().isEmpty
          ? AppLocaleKeys.osEmailHubAppreciationDefaultReason.tr
          : appreciationReason.value.trim(),
      positionLabel: employeePositionLabel(emp),
      bonus: appreciationBonus.value,
    );
  }

  Future<bool> sendAppreciationEmail() async {
    final emp = selectedAppreciationEmployee;
    if (emp == null) return false;
    final email = appreciationRecipientEmail.value.trim();
    if (email.isEmpty) return false;

    isSending.value = true;
    try {
      final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
      final subject = appreciationEmailSubject();
      final html = appreciationEmailHtml();

      return await OsEmailHubService.sendAndLog(
        type: OsEmailCategory.appreciation,
        toEmail: email,
        recipientName: name,
        subject: subject,
        content: html,
        settings: settings.value,
        referenceId: emp.id,
      );
    } finally {
      isSending.value = false;
    }
  }

  String penaltyEmailHtml() {
    final emp = selectedPenaltyEmployee;
    if (emp == null) return '';
    final severity = penaltySeverity.value;
    return OsEmailHtmlComposer.penalty(
      employee: emp,
      settings: settings.value,
      severityLabel: penaltySeverityLabel(severity),
      severityBadge: OsEmailHtmlComposer.penaltySeverityBadge(
        severity,
        penaltyDeductionAmount.value,
      ),
      reason: penaltyReason.value.trim().isEmpty
          ? AppLocaleKeys.osEmailHubPenaltiesDefaultReason.tr
          : penaltyReason.value.trim(),
      gracePeriod: penaltyGracePeriod.value.trim().isEmpty
          ? AppLocaleKeys.osEmailHubPenaltiesDefaultGrace.tr
          : penaltyGracePeriod.value.trim(),
      deductionAmount: penaltyDeductionAmount.value,
      showDeduction: severity == OsPenaltySeverity.salaryDeduction,
    );
  }

  Future<bool> sendPenaltyEmail() async {
    final emp = selectedPenaltyEmployee;
    if (emp == null) return false;
    final email = penaltyRecipientEmail.value.trim();
    if (email.isEmpty) return false;

    isSending.value = true;
    try {
      final name = emp.name?.trim() ?? AppLocaleKeys.osCommonDash.tr;
      final subject = penaltyEmailSubject();
      final html = penaltyEmailHtml();

      return await OsEmailHubService.sendAndLog(
        type: OsEmailCategory.penalty,
        toEmail: email,
        recipientName: name,
        subject: subject,
        content: html,
        settings: settings.value,
        referenceId: emp.id,
      );
    } finally {
      isSending.value = false;
    }
  }

  String contractEmailSubject() {
    final contract = selectedContract;
    if (contract == null) return '';
    return AppLocaleKeys.osLegalContractEmailSubject.trParams({
      'title': contract.title,
      'number': contract.contractNumber,
    });
  }

  Future<String> contractEmailHtml() async {
    final contract = selectedContract;
    if (contract == null) return '';
    final start = FirestoreOsFinanceApi.formatDate(contract.startDate);
    final amount =
        osLegalContractMoneyLabel(contract.totalValue, contract.currency);
    return OsEmailHtmlComposer.contract(
      contract: contract,
      settings: settings.value,
      startDate: start,
      amount: amount,
    );
  }

  Future<bool> sendContractEmail() async {
    final contract = selectedContract;
    if (contract == null) return false;
    final email = contractRecipientEmail.value.trim();
    if (email.isEmpty) return false;

    isSending.value = true;
    try {
      final html = await contractEmailHtml();
      return await OsEmailHubService.sendAndLog(
        type: OsEmailCategory.contract,
        toEmail: email,
        recipientName: contract.targetName,
        subject: contractEmailSubject(),
        content: html,
        settings: settings.value,
        referenceId: contract.contractNumber,
        attachmentsCount: 1,
      );
    } finally {
      isSending.value = false;
    }
  }

  Future<bool> saveSettings(OsEmailSettings next) async {
    isSavingSettings.value = true;
    try {
      return await FirestoreOsEmailApi.saveSettings(next);
    } finally {
      isSavingSettings.value = false;
    }
  }

  Future<bool> deleteLog(String id) => FirestoreOsEmailApi.deleteLog(id);

  Future<bool> clearLogs() => FirestoreOsEmailApi.clearLogs();
}
