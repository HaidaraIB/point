import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsBankAccountModel.dart';
import 'package:point/Models/Os/OsBranchModel.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/OsServiceModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/firestore/firestore_os_branches_api.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/firestore/firestore_os_payroll_api.dart';
import 'package:point/Services/firestore/firestore_os_services_api.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/Utils/os_stream_binding.dart';
import 'package:point/View/Os/os_finance_format.dart';

class OsFinanceController extends GetxController {
  final invoices = <OsInvoiceModel>[].obs;
  final quotations = <OsQuotationModel>[].obs;
  final bankAccounts = <OsBankAccountModel>[].obs;
  final vouchers = <OsVoucherModel>[].obs;
  final expenses = <OsDailyExpenseModel>[].obs;
  final branches = <OsBranchModel>[].obs;
  final services = <OsServiceModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _bindStreams();
    _seedOsCatalog();
  }

  Future<void> _seedOsCatalog() async {
    if (!Get.isRegistered<HomeController>()) return;
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessOsSettings(emp)) return;
    await Future.wait([
      FirestoreOsBranchesApi.ensureSeeded(),
      FirestoreOsServicesApi.ensureSeeded(),
    ]);
  }

  void rebindStreamsForPermissions() => _bindStreams();

  void _bindStreams() {
    final emp = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>().effectiveEmployee
        : null;

    bindOsListStream(
      invoices,
      OsPermissions.canAccessModule(emp, OsModuleIds.invoices),
      FirestoreOsFinanceApi.streamInvoices(),
    );
    bindOsListStream(
      quotations,
      OsPermissions.canAccessModule(emp, OsModuleIds.quotations),
      FirestoreOsFinanceApi.streamQuotations(),
    );
    bindOsListStream(
      bankAccounts,
      OsPermissions.needsBankAccountsRead(emp),
      FirestoreOsFinanceApi.streamBankAccounts(),
    );
    bindOsListStream(
      vouchers,
      OsPermissions.canAccessModule(emp, OsModuleIds.finance),
      FirestoreOsFinanceApi.streamVouchers(),
    );
    bindOsListStream(
      expenses,
      OsPermissions.canAccessModule(emp, OsModuleIds.expenses),
      FirestoreOsFinanceApi.streamExpenses(),
    );
    bindOsListStream(
      branches,
      OsPermissions.needsBranchesRead(emp),
      FirestoreOsBranchesApi.streamBranches(),
    );
    bindOsListStream(
      services,
      OsPermissions.needsServicesRead(emp),
      FirestoreOsServicesApi.streamServices(),
    );
  }

  double get totalInvoiced =>
      invoices.fold<double>(0, (sum, i) => sum + i.total);

  double get totalLiquidity =>
      bankAccounts.fold<double>(0, (sum, a) => sum + a.balance);

  /// Estimated incoming: unpaid invoice totals (money still expected).
  double get totalIncoming => invoices
      .where((i) => !i.isPaid)
      .fold<double>(0, (sum, i) => sum + i.total);

  double get totalOutgoing => vouchers
      .where((v) => v.type == OsVoucherType.payment)
      .fold<double>(0, (sum, v) => sum + v.amount);

  OsBankAccountModel? accountById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in bankAccounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  OsBranchModel? branchById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final b in branches) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Display name for a branch id; falls back to the raw id.
  String branchName(String? id) {
    if (id == null || id.isEmpty) return '';
    return branchById(id)?.name ?? id;
  }

  /// Prefer first active branch; otherwise first overall (for expense defaults).
  String? get defaultBranchId {
    for (final b in branches) {
      if (b.isActive && (b.id?.isNotEmpty ?? false)) return b.id;
    }
    for (final b in branches) {
      if (b.id?.isNotEmpty ?? false) return b.id;
    }
    return null;
  }

  OsServiceModel? serviceById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final s in services) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<bool> saveBranch(OsBranchModel branch) async {
    isLoading.value = true;
    try {
      return await FirestoreOsBranchesApi.upsertBranch(branch);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteBranch(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsBranchesApi.deleteBranch(id);
    } on OsBranchesException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveService(OsServiceModel service) async {
    isLoading.value = true;
    try {
      return await FirestoreOsServicesApi.upsertService(service);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteService(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsServicesApi.deleteService(id);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveInvoice(OsInvoiceModel invoice) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.upsertInvoice(invoice);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteInvoice(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.deleteInvoice(id);
    } on OsFinanceException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveQuotation(OsQuotationModel quotation) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.upsertQuotation(quotation);
    } finally {
      isLoading.value = false;
    }
  }

  /// Creates a draft invoice from an approved quotation (idempotent per quote).
  /// Returns the new or existing invoice id, or null on failure.
  Future<String?> createInvoiceFromQuotation(OsQuotationModel quote) async {
    final quoteId = quote.id?.trim() ?? '';
    if (quoteId.isEmpty) {
      throw OsFinanceException(AppLocaleKeys.osQuotationsConvertMissing);
    }
    if (quote.status != OsQuotationStatus.approved) {
      throw OsFinanceException(AppLocaleKeys.osQuotationsConvertNeedApproved);
    }

    for (final inv in invoices) {
      if (inv.quotationId == quoteId && (inv.id?.isNotEmpty ?? false)) {
        return inv.id;
      }
    }

    isLoading.value = true;
    try {
      final existingId =
          await FirestoreOsFinanceApi.findInvoiceIdByQuotationId(quoteId);
      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }

      final now = DateTime.now();
      final today = OsFinanceFormat.ymd(now);
      final due = OsFinanceFormat.ymd(now.add(const Duration(days: 14)));

      var items = List<OsLineItem>.from(quote.items);
      if (items.isEmpty) {
        final unit = quote.amount > 0 ? quote.amount : quote.total;
        if (unit > 0) {
          items = [
            OsLineItem(
              id: FirestoreOsFinanceApi.newId(),
              description: AppLocaleKeys.osInvoicesItemsFallback.tr,
              quantity: 1,
              unitPrice: unit,
              total: unit,
            ),
          ];
        }
      }

      final invoiceId = FirestoreOsFinanceApi.newId();
      final invoice = OsInvoiceModel(
        id: invoiceId,
        clientId: quote.clientId,
        clientName: quote.clientName,
        clientPhone: quote.clientPhone,
        clientEmail: quote.clientEmail,
        clientAddress: quote.clientAddress,
        date: today,
        dueDate: due,
        status: OsInvoiceStatus.draft,
        amount: quote.amount > 0
            ? quote.amount
            : items.fold<double>(0, (s, i) => s + i.total),
        discount: quote.discount,
        vat: quote.vat,
        total: quote.total,
        items: items,
        notes: quote.notes,
        quotationId: quoteId,
        createdAt: now,
      );

      final ok = await FirestoreOsFinanceApi.upsertInvoice(invoice);
      if (!ok) return null;
      return invoiceId;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteQuotation(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.deleteQuotation(id);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> setQuotationStatus(
    OsQuotationModel quotation,
    String status,
  ) async {
    if (status == quotation.status) return true;
    if (!OsQuotationStatus.all.contains(status)) return false;
    return saveQuotation(quotation.copyWith(status: status));
  }

  Future<bool> markInvoicePaid({
    required OsInvoiceModel invoice,
    required String bankAccountId,
  }) async {
    isLoading.value = true;
    try {
      final ok = await FirestoreOsFinanceApi.markInvoicePaid(
        invoice: invoice,
        bankAccountId: bankAccountId,
        voucherDescription: AppLocaleKeys.osInvoicesCollectionDesc.trParams({
          'client': invoice.clientName,
        }),
      );
      if (ok) {
        final clientId = invoice.clientId.trim();
        if (clientId.isNotEmpty) {
          try {
            await NotificationService.notifyClientInvoicePaid(
              clientId: clientId,
              invoiceRef: OsFinanceFormat.invoiceRef(invoice),
              amountLabel: OsFinanceFormat.money(invoice.total),
            );
          } catch (e, s) {
            appLog(
              'markInvoicePaid client notify failed: $e',
              error: e,
              stackTrace: s,
            );
          }
        }
      }
      return ok;
    } on OsFinanceException catch (e) {
      appLog('markInvoicePaid rejected: ${e.messageKey}');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Undo PAID → [newStatus] (point_os): debit linked account; keep receipt voucher.
  Future<bool> unmarkInvoicePaid({
    required OsInvoiceModel invoice,
    required String newStatus,
  }) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.unmarkInvoicePaid(
        invoice: invoice,
        newStatus: newStatus,
      );
    } on OsFinanceException catch (e) {
      appLog('unmarkInvoicePaid rejected: ${e.messageKey}');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveBankAccount(OsBankAccountModel account) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.upsertBankAccount(account);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteBankAccount(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.deleteBankAccount(id);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createVoucher(OsVoucherModel voucher) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.createVoucher(voucher);
    } on OsFinanceException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveVoucher(OsVoucherModel voucher) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.updateVoucherContact(voucher);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateVoucher(
    OsVoucherModel voucher, {
    OsTransferVoucherEdit? transfer,
  }) async {
    isLoading.value = true;
    try {
      final result = await FirestoreOsFinanceApi.updateVoucher(
        updated: voucher,
        transfer: transfer,
      );
      final runId = result.payrollRunIdToRefresh;
      if (runId != null && runId.isNotEmpty) {
        await FirestoreOsPayrollApi.refreshRunTotals(runId);
      }
      return true;
    } on OsFinanceException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteVoucher(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.deleteVoucher(id);
    } on OsFinanceException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> transferBetweenAccounts({
    required String sourceAccountId,
    required String destAccountId,
    required double amount,
    required String paymentDescription,
    required String receiptDescription,
  }) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.transferBetweenAccounts(
        sourceAccountId: sourceAccountId,
        destAccountId: destAccountId,
        amount: amount,
        paymentDescription: paymentDescription,
        receiptDescription: receiptDescription,
      );
    } on OsFinanceException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createExpense(OsDailyExpenseModel expense) async {
    isLoading.value = true;
    try {
      final vendor = expense.vendor?.trim() ?? '';
      final desc = AppLocaleKeys.osExpensesVoucherDesc.trParams({
        'title': expense.title,
        'vendor': vendor.isEmpty ? '' : ' ($vendor)',
      });
      final saved = await FirestoreOsFinanceApi.createExpense(
        expense: expense,
        voucherDescription: desc,
      );
      return saved != null;
    } on OsFinanceException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateExpense(OsDailyExpenseModel expense) async {
    isLoading.value = true;
    try {
      final vendor = expense.vendor?.trim() ?? '';
      final desc = AppLocaleKeys.osExpensesVoucherDesc.trParams({
        'title': expense.title,
        'vendor': vendor.isEmpty ? '' : ' ($vendor)',
      });
      return await FirestoreOsFinanceApi.updateExpense(
        expense: expense,
        voucherDescription: desc,
      );
    } on OsFinanceException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.deleteExpense(id);
    } on OsFinanceException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }
}
