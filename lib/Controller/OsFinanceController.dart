import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsBankAccountModel.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Utils/app_log.dart';

class OsFinanceController extends GetxController {
  final invoices = <OsInvoiceModel>[].obs;
  final bankAccounts = <OsBankAccountModel>[].obs;
  final vouchers = <OsVoucherModel>[].obs;
  final expenses = <OsDailyExpenseModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _bindStreams();
  }

  void _bindStreams() {
    invoices.bindStream(FirestoreOsFinanceApi.streamInvoices());
    bankAccounts.bindStream(FirestoreOsFinanceApi.streamBankAccounts());
    vouchers.bindStream(FirestoreOsFinanceApi.streamVouchers());
    expenses.bindStream(FirestoreOsFinanceApi.streamExpenses());
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
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> markInvoicePaid({
    required OsInvoiceModel invoice,
    required String bankAccountId,
  }) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.markInvoicePaid(
        invoice: invoice,
        bankAccountId: bankAccountId,
        voucherDescription: AppLocaleKeys.osInvoicesCollectionDesc.trParams({
          'client': invoice.clientName,
        }),
      );
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
      return await FirestoreOsFinanceApi.createExpense(
        expense: expense,
        voucherDescription: desc,
      );
    } on OsFinanceException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateExpense(OsDailyExpenseModel expense) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.updateExpense(expense);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsFinanceApi.deleteExpense(id);
    } finally {
      isLoading.value = false;
    }
  }
}
