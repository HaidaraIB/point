import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/Os/EmailHub/os_email_payslip_options.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/Os/OsBankAccountModel.dart';
import 'package:point/Models/Os/OsEmailLogModel.dart';
import 'package:point/Models/Os/OsEmailSettings.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsPayslipBatchResult.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/os_email_enums.dart';
import 'package:point/Models/Os/os_hr_letter_enums.dart';
import 'package:point/Services/firestore/firestore_os_email_api.dart';
import 'package:point/Services/os_email_hub_draft_persistence.dart';
import 'package:point/Services/os_email_hub_service.dart';
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
  final invoiceIncludeBankDetails = true.obs;
  final selectedInvoiceId = RxnString();
  final selectedBankAccountId = RxnString();

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
        'invoiceIncludeBankDetails': invoiceIncludeBankDetails.value,
        'selectedInvoiceId': selectedInvoiceId.value,
        'selectedBankAccountId': selectedBankAccountId.value,
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
        'logsSearch': logsSearch.value,
        'logsCategoryFilter': logsCategoryFilter.value,
      };

  void _applyDraft(Map<String, dynamic> map) {
    invoiceRecipientEmail.value =
        map['invoiceRecipientEmail'] as String? ?? '';
    invoiceCustomNote.value = map['invoiceCustomNote'] as String? ?? '';
    invoiceIncludeBankDetails.value =
        map['invoiceIncludeBankDetails'] as bool? ?? true;
    selectedInvoiceId.value = map['selectedInvoiceId'] as String?;
    selectedBankAccountId.value = map['selectedBankAccountId'] as String?;

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
    ensurePayslipPaymentMethod();
  }

  void _bindStreams() {
    settings.bindStream(FirestoreOsEmailApi.streamSettings());
    logs.bindStream(FirestoreOsEmailApi.streamLogs());
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

  OsBankAccountModel? get selectedBank {
    final id = selectedBankAccountId.value;
    if (id != null) {
      for (final b in bankAccounts) {
        if (b.id == id) return b;
      }
    }
    return bankAccounts.isNotEmpty ? bankAccounts.first : null;
  }

  void syncInvoiceRecipient() {
    final inv = selectedInvoice;
    if (inv == null) return;
    final email = inv.clientEmail?.trim() ?? '';
    if (email.isNotEmpty) {
      invoiceRecipientEmail.value = email;
      return;
    }
    final client = osInvoiceClient(inv);
    invoiceRecipientEmail.value = client?.email?.trim() ?? '';
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
    if (selectedBankAccountId.value == null && bankAccounts.isNotEmpty) {
      selectedBankAccountId.value = bankAccounts.first.id;
    }
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

  String invoiceEmailBody() {
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
    if (invoiceIncludeBankDetails.value) {
      final bank = selectedBank;
      if (bank != null) {
        body = '$body\n\n${AppLocaleKeys.osEmailHubBankDetails.trParams({
              'name': bank.name,
              'number': OsFinanceFormat.accountNumberLabel(bank.accountNumber),
            })}';
      }
    }
    final link = osInvoicePaymentLink(inv);
    body = '$body\n\n${AppLocaleKeys.osEmailHubPaymentLink.trParams({'link': link})}';
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

  Future<bool> sendInvoiceEmail() async {
    final inv = selectedInvoice;
    if (inv == null) return false;
    final email = invoiceRecipientEmail.value.trim();
    if (email.isEmpty) return false;

    isSending.value = true;
    try {
      final ref = OsFinanceFormat.invoiceRef(inv);
      final subject = invoiceEmailSubject();
      final body = invoiceEmailBody();

      return await OsEmailHubService.sendAndLog(
        type: OsEmailCategory.invoice,
        toEmail: email,
        recipientName: inv.clientName,
        subject: subject,
        content: body,
        settings: settings.value,
        referenceId: ref,
        attachmentsCount: 1,
      );
    } finally {
      isSending.value = false;
    }
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
      final body = quotationEmailBody();

      return await OsEmailHubService.sendAndLog(
        type: OsEmailCategory.quotation,
        toEmail: email,
        recipientName: quote.clientName,
        subject: subject,
        content: body,
        settings: settings.value,
        referenceId: ref,
      );
    } finally {
      isSending.value = false;
    }
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
        content: payslipEmailBody(emp),
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
          content: payslipEmailBody(emp),
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
      );
    } finally {
      isSending.value = false;
    }
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
      final body = appreciationEmailBody();

      return await OsEmailHubService.sendAndLog(
        type: OsEmailCategory.appreciation,
        toEmail: email,
        recipientName: name,
        subject: subject,
        content: body,
        settings: settings.value,
        referenceId: emp.id,
      );
    } finally {
      isSending.value = false;
    }
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
      final body = penaltyEmailBody();

      return await OsEmailHubService.sendAndLog(
        type: OsEmailCategory.penalty,
        toEmail: email,
        recipientName: name,
        subject: subject,
        content: body,
        settings: settings.value,
        referenceId: emp.id,
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
