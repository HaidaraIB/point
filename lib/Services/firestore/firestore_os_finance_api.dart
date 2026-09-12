import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsBankAccountModel.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';
import 'package:point/Services/firestore/firestore_stream_utils.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:uuid/uuid.dart';

class OsFinanceException implements Exception {
  OsFinanceException(this.messageKey);
  final String messageKey;

  @override
  String toString() => messageKey;
}

/// Firestore API for Point OS finance (invoices, bank accounts, vouchers).
class FirestoreOsFinanceApi {
  FirestoreOsFinanceApi._();

  static const invoicesCollection = 'os_invoices';
  static const bankAccountsCollection = 'os_bank_accounts';
  static const vouchersCollection = 'os_vouchers';
  static const expensesCollection = 'os_expenses';
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  static String formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static Future<String> _nextVoucherDisplayNumber() async {
    final snap = await FirebaseFirestore.instance
        .collection(vouchersCollection)
        .limit(FirestoreQueryLimits.osVouchers)
        .get();
    return OsFinanceFormat.nextVoucherDisplayNumber(
      snap.docs.map((d) => d.data()['displayNumber'] as String?),
    );
  }

  // --- Streams ---

  static Stream<List<OsInvoiceModel>> streamInvoices() {
    final mapped = FirebaseFirestore.instance
        .collection(invoicesCollection)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.osInvoices)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsInvoiceModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_invoices');
  }

  static Stream<List<OsBankAccountModel>> streamBankAccounts() {
    final mapped = FirebaseFirestore.instance
        .collection(bankAccountsCollection)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.osBankAccounts)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsBankAccountModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_bank_accounts');
  }

  static Stream<List<OsVoucherModel>> streamVouchers() {
    final mapped = FirebaseFirestore.instance
        .collection(vouchersCollection)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.osVouchers)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsVoucherModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_vouchers');
  }

  static Stream<List<OsDailyExpenseModel>> streamExpenses() {
    final mapped = FirebaseFirestore.instance
        .collection(expensesCollection)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.osExpenses)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsDailyExpenseModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_expenses');
  }

  // --- Invoices ---

  static Future<bool> upsertInvoice(OsInvoiceModel invoice) async {
    try {
      final isNew = invoice.id == null || invoice.id!.trim().isEmpty;
      final id = isNew ? newId() : invoice.id!;
      var displayNumber = invoice.displayNumber?.trim();
      if (isNew || displayNumber == null || displayNumber.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection(invoicesCollection)
            .limit(FirestoreQueryLimits.osInvoices)
            .get();
        displayNumber = OsFinanceFormat.nextInvoiceDisplayNumber(
          snap.docs.map((d) => d.data()['displayNumber'] as String?),
        );
      }
      final toSave = invoice.copyWith(id: id, displayNumber: displayNumber);
      await FirebaseFirestore.instance
          .collection(invoicesCollection)
          .doc(id)
          .set(toSave.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('upsertInvoice failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> deleteInvoice(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection(invoicesCollection)
          .doc(id)
          .delete();
      return true;
    } catch (e, st) {
      appLog('deleteInvoice failed: $e\n$st');
      return false;
    }
  }

  /// Mark paid: credits bank account and creates a RECEIPT voucher.
  /// Undo via [unmarkInvoicePaid] (status change away from PAID).
  static Future<bool> markInvoicePaid({
    required OsInvoiceModel invoice,
    required String bankAccountId,
    required String voucherDescription,
  }) async {
    final invoiceId = invoice.id?.trim() ?? '';
    final accountId = bankAccountId.trim();
    if (invoiceId.isEmpty || accountId.isEmpty) {
      throw OsFinanceException('os.invoices.error.missing_ids');
    }
    if (invoice.isPaid) {
      throw OsFinanceException('os.invoices.error.already_paid');
    }

    final firestore = FirebaseFirestore.instance;
    final invoiceRef = firestore.collection(invoicesCollection).doc(invoiceId);
    final accountRef =
        firestore.collection(bankAccountsCollection).doc(accountId);
    final voucherId = newId();
    final voucherRef =
        firestore.collection(vouchersCollection).doc(voucherId);
    final voucherDisplay = await _nextVoucherDisplayNumber();

    try {
      await firestore.runTransaction((tx) async {
        final accountSnap = await tx.get(accountRef);
        if (!accountSnap.exists) {
          throw OsFinanceException('os.invoices.error.account_missing');
        }
        final account = OsBankAccountModel.fromJson(
          accountSnap.data()!,
          accountSnap.id,
        );
        final invoiceSnap = await tx.get(invoiceRef);
        if (!invoiceSnap.exists) {
          throw OsFinanceException('os.invoices.error.missing_ids');
        }
        final current = OsInvoiceModel.fromJson(
          invoiceSnap.data()!,
          invoiceSnap.id,
        );
        if (current.isPaid) {
          throw OsFinanceException('os.invoices.error.already_paid');
        }

        final updatedInvoice = current.copyWith(
          status: OsInvoiceStatus.paid,
          bankAccountId: accountId,
        );
        tx.set(invoiceRef, updatedInvoice.toJson(), SetOptions(merge: true));

        tx.set(
          accountRef,
          account
              .copyWith(balance: account.balance + current.total)
              .toJson(),
          SetOptions(merge: true),
        );

        final now = DateTime.now();
        final voucher = OsVoucherModel(
          id: voucherId,
          displayNumber: voucherDisplay,
          type: OsVoucherType.receipt,
          amount: current.total,
          date: formatDate(now),
          payeeOrPayer: current.clientName,
          description: voucherDescription,
          bankAccountId: accountId,
          status: OsVoucherStatus.completed,
          invoiceId: invoiceId,
          source: OsVoucherSource.invoice,
          createdAt: now,
        );
        tx.set(voucherRef, voucher.toJson());
      });
      return true;
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('markInvoicePaid failed: $e\n$st');
      return false;
    }
  }

  /// Undo paid (point_os status change away from PAID): debit collection
  /// account, set new non-paid status. Leaves the receipt voucher in place.
  static Future<bool> unmarkInvoicePaid({
    required OsInvoiceModel invoice,
    required String newStatus,
  }) async {
    final invoiceId = invoice.id?.trim() ?? '';
    if (invoiceId.isEmpty) {
      throw OsFinanceException('os.invoices.error.missing_ids');
    }
    if (!invoice.isPaid) {
      throw OsFinanceException('os.invoices.error.not_paid');
    }
    if (!OsInvoiceStatus.editable.contains(newStatus)) {
      throw OsFinanceException('os.invoices.error.invalid_status');
    }

    final firestore = FirebaseFirestore.instance;
    final invoiceRef = firestore.collection(invoicesCollection).doc(invoiceId);

    try {
      await firestore.runTransaction((tx) async {
        final invoiceSnap = await tx.get(invoiceRef);
        if (!invoiceSnap.exists) {
          throw OsFinanceException('os.invoices.error.missing_ids');
        }
        final current = OsInvoiceModel.fromJson(
          invoiceSnap.data()!,
          invoiceSnap.id,
        );
        if (!current.isPaid) {
          throw OsFinanceException('os.invoices.error.not_paid');
        }

        final accountId = current.bankAccountId?.trim() ?? '';
        if (accountId.isNotEmpty) {
          final accountRef =
              firestore.collection(bankAccountsCollection).doc(accountId);
          final accountSnap = await tx.get(accountRef);
          if (accountSnap.exists) {
            final account = OsBankAccountModel.fromJson(
              accountSnap.data()!,
              accountSnap.id,
            );
            final nextBalance =
                (account.balance - current.total).clamp(0.0, double.infinity);
            tx.set(
              accountRef,
              account.copyWith(balance: nextBalance).toJson(),
              SetOptions(merge: true),
            );
          }
        }

        tx.set(
          invoiceRef,
          current.copyWith(status: newStatus).toJson(),
          SetOptions(merge: true),
        );
      });
      return true;
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('unmarkInvoicePaid failed: $e\n$st');
      return false;
    }
  }

  // --- Bank accounts ---

  static Future<bool> upsertBankAccount(OsBankAccountModel account) async {
    try {
      final id = (account.id == null || account.id!.trim().isEmpty)
          ? newId()
          : account.id!;
      final toSave = account.copyWith(id: id);
      await FirebaseFirestore.instance
          .collection(bankAccountsCollection)
          .doc(id)
          .set(toSave.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('upsertBankAccount failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> deleteBankAccount(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection(bankAccountsCollection)
          .doc(id)
          .delete();
      return true;
    } catch (e, st) {
      appLog('deleteBankAccount failed: $e\n$st');
      return false;
    }
  }

  // --- Vouchers ---

  /// Creates a voucher and adjusts the linked bank account balance.
  static Future<bool> createVoucher(OsVoucherModel voucher) async {
    final accountId = voucher.bankAccountId.trim();
    if (accountId.isEmpty) {
      throw OsFinanceException('os.vouchers.error.account_required');
    }
    if (voucher.amount <= 0) {
      throw OsFinanceException('os.vouchers.error.invalid_amount');
    }

    final firestore = FirebaseFirestore.instance;
    final id = (voucher.id == null || voucher.id!.trim().isEmpty)
        ? newId()
        : voucher.id!;
    final voucherRef = firestore.collection(vouchersCollection).doc(id);
    final accountRef =
        firestore.collection(bankAccountsCollection).doc(accountId);
    final displayNumber = (voucher.displayNumber?.trim().isNotEmpty ?? false)
        ? voucher.displayNumber!.trim()
        : await _nextVoucherDisplayNumber();

    try {
      await firestore.runTransaction((tx) async {
        final accountSnap = await tx.get(accountRef);
        if (!accountSnap.exists) {
          throw OsFinanceException('os.invoices.error.account_missing');
        }
        final account = OsBankAccountModel.fromJson(
          accountSnap.data()!,
          accountSnap.id,
        );

        final delta = voucher.type == OsVoucherType.payment
            ? -voucher.amount
            : voucher.amount;

        final toSave = voucher.copyWith(
          id: id,
          displayNumber: displayNumber,
          status: OsVoucherStatus.completed,
          source: (voucher.source?.trim().isNotEmpty ?? false)
              ? voucher.source!.trim()
              : OsVoucherSource.manual,
        );
        tx.set(voucherRef, toSave.toJson());
        tx.set(
          accountRef,
          account.copyWith(balance: account.balance + delta).toJson(),
          SetOptions(merge: true),
        );
      });
      return true;
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('createVoucher failed: $e\n$st');
      return false;
    }
  }

  /// Deletes a manually issued voucher and reverses its bank-account effect.
  static Future<bool> deleteVoucher(String id) async {
    final voucherId = id.trim();
    if (voucherId.isEmpty) {
      throw OsFinanceException('os.vouchers.error.missing_id');
    }

    final firestore = FirebaseFirestore.instance;
    final voucherRef =
        firestore.collection(vouchersCollection).doc(voucherId);

    try {
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(voucherRef);
        if (!snap.exists) {
          throw OsFinanceException('os.vouchers.error.not_found');
        }
        final voucher = OsVoucherModel.fromJson(snap.data()!, snap.id);
        if (!voucher.isManuallyDeletable) {
          throw OsFinanceException('os.vouchers.error.not_manual');
        }

        final accountId = voucher.bankAccountId.trim();
        if (accountId.isEmpty) {
          throw OsFinanceException('os.vouchers.error.account_required');
        }
        final accountRef =
            firestore.collection(bankAccountsCollection).doc(accountId);
        final accountSnap = await tx.get(accountRef);
        if (!accountSnap.exists) {
          throw OsFinanceException('os.invoices.error.account_missing');
        }
        final account = OsBankAccountModel.fromJson(
          accountSnap.data()!,
          accountSnap.id,
        );

        // Reverse the createVoucher delta.
        final reverseDelta = voucher.type == OsVoucherType.payment
            ? voucher.amount
            : -voucher.amount;

        tx.set(
          accountRef,
          account.copyWith(balance: account.balance + reverseDelta).toJson(),
          SetOptions(merge: true),
        );
        tx.delete(voucherRef);
      });
      return true;
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('deleteVoucher failed: $e\n$st');
      return false;
    }
  }

  /// Moves funds between two accounts and logs paired PAYMENT/RECEIPT vouchers.
  /// Balance is adjusted once in this transaction (vouchers are audit-only).
  static Future<bool> transferBetweenAccounts({
    required String sourceAccountId,
    required String destAccountId,
    required double amount,
    required String paymentDescription,
    required String receiptDescription,
  }) async {
    final sourceId = sourceAccountId.trim();
    final destId = destAccountId.trim();
    if (sourceId.isEmpty || destId.isEmpty) {
      throw OsFinanceException('os.vouchers.error.account_required');
    }
    if (sourceId == destId) {
      throw OsFinanceException('os.accounts.transfer.error.same');
    }
    if (amount <= 0) {
      throw OsFinanceException('os.vouchers.error.invalid_amount');
    }

    final firestore = FirebaseFirestore.instance;
    final sourceRef =
        firestore.collection(bankAccountsCollection).doc(sourceId);
    final destRef = firestore.collection(bankAccountsCollection).doc(destId);
    final paymentId = newId();
    final receiptId = newId();
    final paymentRef =
        firestore.collection(vouchersCollection).doc(paymentId);
    final receiptRef =
        firestore.collection(vouchersCollection).doc(receiptId);
    final paymentDisplay = await _nextVoucherDisplayNumber();
    // Allocate second number from the first to avoid collision without re-query.
    final paymentN =
        int.tryParse(paymentDisplay.replaceFirst(RegExp(r'^V-', caseSensitive: false), '')) ??
            101;
    final receiptDisplay = 'V-${paymentN + 1}';

    try {
      await firestore.runTransaction((tx) async {
        final sourceSnap = await tx.get(sourceRef);
        final destSnap = await tx.get(destRef);
        if (!sourceSnap.exists || !destSnap.exists) {
          throw OsFinanceException('os.invoices.error.account_missing');
        }
        final source = OsBankAccountModel.fromJson(
          sourceSnap.data()!,
          sourceSnap.id,
        );
        final dest = OsBankAccountModel.fromJson(
          destSnap.data()!,
          destSnap.id,
        );
        if (source.balance < amount) {
          throw OsFinanceException('os.accounts.transfer.error.insufficient');
        }

        final now = DateTime.now();
        final date = formatDate(now);

        tx.set(
          sourceRef,
          source.copyWith(balance: source.balance - amount).toJson(),
          SetOptions(merge: true),
        );
        tx.set(
          destRef,
          dest.copyWith(balance: dest.balance + amount).toJson(),
          SetOptions(merge: true),
        );

        tx.set(
          paymentRef,
          OsVoucherModel(
            id: paymentId,
            displayNumber: paymentDisplay,
            type: OsVoucherType.payment,
            amount: amount,
            date: date,
            payeeOrPayer: dest.name,
            description: paymentDescription,
            bankAccountId: sourceId,
            status: OsVoucherStatus.completed,
            source: OsVoucherSource.transfer,
            createdAt: now,
          ).toJson(),
        );
        tx.set(
          receiptRef,
          OsVoucherModel(
            id: receiptId,
            displayNumber: receiptDisplay,
            type: OsVoucherType.receipt,
            amount: amount,
            date: date,
            payeeOrPayer: source.name,
            description: receiptDescription,
            bankAccountId: destId,
            status: OsVoucherStatus.completed,
            source: OsVoucherSource.transfer,
            createdAt: now,
          ).toJson(),
        );
      });
      return true;
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('transferBetweenAccounts failed: $e\n$st');
      return false;
    }
  }

  // --- Daily expenses ---

  /// Creates an expense; if [bankAccountId] is set, also posts a PAYMENT voucher.
  /// Returns the saved expense (with id / voucherId) or null on failure.
  static Future<OsDailyExpenseModel?> createExpense({
    required OsDailyExpenseModel expense,
    required String voucherDescription,
    String voucherSource = OsVoucherSource.expense,
  }) async {
    try {
      final id = (expense.id == null || expense.id!.trim().isEmpty)
          ? newId()
          : expense.id!;
      String? voucherId = expense.voucherId;
      final accountId = expense.bankAccountId?.trim();

      if (accountId != null && accountId.isNotEmpty) {
        voucherId = newId();
        final payee = (expense.vendor?.trim().isNotEmpty ?? false)
            ? expense.vendor!.trim()
            : expense.paidBy;
        final ok = await createVoucher(
          OsVoucherModel(
            id: voucherId,
            type: OsVoucherType.payment,
            amount: expense.amount,
            date: expense.date,
            payeeOrPayer: payee,
            description: voucherDescription,
            bankAccountId: accountId,
            source: voucherSource,
            createdAt: DateTime.now(),
          ),
        );
        if (!ok) return null;
      }

      final toSave = expense.copyWith(id: id, voucherId: voucherId);
      await FirebaseFirestore.instance
          .collection(expensesCollection)
          .doc(id)
          .set(toSave.toJson(), SetOptions(merge: true));
      return toSave;
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('createExpense failed: $e\n$st');
      return null;
    }
  }

  /// Updates expense fields only (no bank reverse — matches point_os).
  static Future<bool> updateExpense(OsDailyExpenseModel expense) async {
    final id = expense.id?.trim();
    if (id == null || id.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection(expensesCollection)
          .doc(id)
          .set(expense.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('updateExpense failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> deleteExpense(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection(expensesCollection)
          .doc(id)
          .delete();
      return true;
    } catch (e, st) {
      appLog('deleteExpense failed: $e\n$st');
      return false;
    }
  }
}
