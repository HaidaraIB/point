import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsBankAccountModel.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';
import 'package:point/Services/firestore/firestore_stream_utils.dart';
import 'package:point/Services/os_voucher_balance.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:uuid/uuid.dart';

/// Paired transfer edit payload (required when editing a TRANSFER voucher).
class OsTransferVoucherEdit {
  const OsTransferVoucherEdit({
    required this.sourceAccountId,
    required this.destAccountId,
    required this.amount,
    required this.date,
    required this.paymentDescription,
    required this.receiptDescription,
  });

  final String sourceAccountId;
  final String destAccountId;
  final double amount;
  final String date;
  final String paymentDescription;
  final String receiptDescription;
}

/// Outcome of [FirestoreOsFinanceApi.updateVoucher].
class OsVoucherUpdateResult {
  const OsVoucherUpdateResult({this.payrollRunIdToRefresh});

  final String? payrollRunIdToRefresh;
}

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
  static const quotationsCollection = 'os_quotations';
  static const bankAccountsCollection = 'os_bank_accounts';
  static const vouchersCollection = 'os_vouchers';
  static const expensesCollection = 'os_expenses';
  static const payslipsCollection = 'os_payslips';
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

  static Stream<List<OsQuotationModel>> streamQuotations() {
    final mapped = FirebaseFirestore.instance
        .collection(quotationsCollection)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.osQuotations)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsQuotationModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_quotations');
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

  /// Returns an existing invoice id linked to [quotationId], if any.
  static Future<String?> findInvoiceIdByQuotationId(String quotationId) async {
    final qid = quotationId.trim();
    if (qid.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(invoicesCollection)
          .where('quotationId', isEqualTo: qid)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    } catch (e, st) {
      appLog('findInvoiceIdByQuotationId failed: $e\n$st');
      return null;
    }
  }

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

  /// Deletes an invoice. If paid, reverses collection (debits account) and
  /// removes the linked INVOICE receipt voucher first.
  static Future<bool> deleteInvoice(String id) async {
    final invoiceId = id.trim();
    if (invoiceId.isEmpty) {
      throw OsFinanceException('os.invoices.error.missing_ids');
    }

    final firestore = FirebaseFirestore.instance;
    final invoiceRef =
        firestore.collection(invoicesCollection).doc(invoiceId);

    try {
      // Collect linked vouchers outside the transaction (query).
      final voucherSnap = await firestore
          .collection(vouchersCollection)
          .where('invoiceId', isEqualTo: invoiceId)
          .limit(FirestoreQueryLimits.osVouchers)
          .get();

      await firestore.runTransaction((tx) async {
        final invoiceSnap = await tx.get(invoiceRef);
        if (!invoiceSnap.exists) {
          throw OsFinanceException('os.invoices.error.missing_ids');
        }
        final current = OsInvoiceModel.fromJson(
          invoiceSnap.data()!,
          invoiceSnap.id,
        );

        if (current.isPaid) {
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
        }

        for (final d in voucherSnap.docs) {
          tx.delete(d.reference);
        }
        tx.delete(invoiceRef);
      });
      return true;
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('deleteInvoice failed: $e\n$st');
      return false;
    }
  }

  // --- Quotations ---

  static Future<bool> upsertQuotation(OsQuotationModel quotation) async {
    try {
      final isNew = quotation.id == null || quotation.id!.trim().isEmpty;
      final id = isNew ? newId() : quotation.id!;
      var displayNumber = quotation.displayNumber?.trim();
      if (isNew || displayNumber == null || displayNumber.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection(quotationsCollection)
            .limit(FirestoreQueryLimits.osQuotations)
            .get();
        displayNumber = OsFinanceFormat.nextQuotationDisplayNumber(
          snap.docs.map((d) => d.data()['displayNumber'] as String?),
        );
      }
      final toSave = quotation.copyWith(id: id, displayNumber: displayNumber);
      await FirebaseFirestore.instance
          .collection(quotationsCollection)
          .doc(id)
          .set(toSave.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('upsertQuotation failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> deleteQuotation(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection(quotationsCollection)
          .doc(id)
          .delete();
      return true;
    } catch (e, st) {
      appLog('deleteQuotation failed: $e\n$st');
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
        final payeePhone = current.clientPhone?.trim();
        final voucher = OsVoucherModel(
          id: voucherId,
          displayNumber: voucherDisplay,
          type: OsVoucherType.receipt,
          amount: current.total,
          date: formatDate(now),
          payeeOrPayer: current.clientName,
          payeePhone:
              payeePhone != null && payeePhone.isNotEmpty ? payeePhone : null,
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

  /// Patch contact fields on an existing voucher (no balance changes).
  static Future<bool> updateVoucherContact(OsVoucherModel voucher) async {
    final id = voucher.id?.trim() ?? '';
    if (id.isEmpty) return false;
    try {
      final data = <String, dynamic>{};
      final phone = voucher.payeePhone?.trim();
      if (phone != null && phone.isNotEmpty) {
        data['payeePhone'] = phone;
      }
      if (data.isEmpty) return true;
      await FirebaseFirestore.instance
          .collection(vouchersCollection)
          .doc(id)
          .update(data);
      return true;
    } catch (e, st) {
      appLog('updateVoucherContact failed: $e\n$st');
      return false;
    }
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> _findUniqueTransferPairDoc(
    OsVoucherModel voucher,
  ) async {
    final oppositeType = voucher.type == OsVoucherType.payment
        ? OsVoucherType.receipt
        : OsVoucherType.payment;
    final candidates = await FirebaseFirestore.instance
        .collection(vouchersCollection)
        .where('source', isEqualTo: OsVoucherSource.transfer)
        .where('date', isEqualTo: voucher.date)
        .where('amount', isEqualTo: voucher.amount)
        .limit(FirestoreQueryLimits.osVouchers)
        .get();

    final matches = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final d in candidates.docs) {
      if (d.id == voucher.id) continue;
      final other = OsVoucherModel.fromJson(d.data(), d.id);
      if (other.type == oppositeType) {
        matches.add(d);
      }
    }
    if (matches.isEmpty) return null;
    if (matches.length > 1) {
      throw OsFinanceException('os.vouchers.error.transfer_ambiguous');
    }
    return matches.first;
  }

  static OsVoucherModel _resolveTransferLegs({
    required OsVoucherModel voucher,
    required OsVoucherModel? pair,
  }) {
    if (voucher.type == OsVoucherType.payment) return voucher;
    if (pair != null && pair.type == OsVoucherType.payment) return pair;
    return voucher;
  }

  static OsVoucherModel _resolveTransferReceipt({
    required OsVoucherModel voucher,
    required OsVoucherModel? pair,
  }) {
    if (voucher.type == OsVoucherType.receipt) return voucher;
    if (pair != null && pair.type == OsVoucherType.receipt) return pair;
    return voucher;
  }

  /// Updates a posted voucher and applies the exact net balance delta in one
  /// transaction. Syncs linked invoice, expense, payroll, or transfer pair.
  static Future<OsVoucherUpdateResult> updateVoucher({
    required OsVoucherModel updated,
    OsTransferVoucherEdit? transfer,
  }) async {
    final voucherId = updated.id?.trim() ?? '';
    if (voucherId.isEmpty) {
      throw OsFinanceException('os.vouchers.error.missing_id');
    }
    if (updated.amount <= 0) {
      throw OsFinanceException('os.vouchers.error.invalid_amount');
    }

    final firestore = FirebaseFirestore.instance;
    final voucherRef = firestore.collection(vouchersCollection).doc(voucherId);
    final snap = await voucherRef.get();
    if (!snap.exists) {
      throw OsFinanceException('os.vouchers.error.not_found');
    }
    final current = OsVoucherModel.fromJson(snap.data()!, snap.id);
    final source = current.source?.trim() ?? '';

    if (!osVoucherTypeChangeAllowed(current) &&
        updated.type != current.type) {
      throw OsFinanceException('os.vouchers.error.type_locked');
    }

    if (source == OsVoucherSource.transfer) {
      if (transfer == null) {
        throw OsFinanceException('os.vouchers.error.transfer_ambiguous');
      }
      if (transfer.sourceAccountId.trim().isEmpty ||
          transfer.destAccountId.trim().isEmpty) {
        throw OsFinanceException('os.vouchers.error.account_required');
      }
      if (transfer.sourceAccountId.trim() == transfer.destAccountId.trim()) {
        throw OsFinanceException('os.accounts.transfer.error.same');
      }
      if (transfer.amount <= 0) {
        throw OsFinanceException('os.vouchers.error.invalid_amount');
      }
    } else {
      final accountId = updated.bankAccountId.trim();
      if (accountId.isEmpty) {
        throw OsFinanceException('os.vouchers.error.account_required');
      }
    }

    DocumentSnapshot<Map<String, dynamic>>? pairDoc;
    DocumentSnapshot<Map<String, dynamic>>? expenseDoc;
    DocumentSnapshot<Map<String, dynamic>>? invoiceDoc;
    DocumentSnapshot<Map<String, dynamic>>? payslipDoc;

    if (source == OsVoucherSource.transfer) {
      pairDoc = await _findUniqueTransferPairDoc(current);
      if (pairDoc == null) {
        throw OsFinanceException('os.vouchers.error.transfer_ambiguous');
      }
    } else if (source == OsVoucherSource.expense ||
        source == OsVoucherSource.payroll) {
      final expenseSnap = await firestore
          .collection(expensesCollection)
          .where('voucherId', isEqualTo: voucherId)
          .limit(1)
          .get();
      if (expenseSnap.docs.isNotEmpty) {
        expenseDoc = expenseSnap.docs.first;
      }
    } else if (source == OsVoucherSource.invoice ||
        (current.invoiceId != null && current.invoiceId!.trim().isNotEmpty)) {
      final invoiceId = current.invoiceId?.trim() ?? '';
      if (invoiceId.isNotEmpty) {
        final invoiceSnap =
            await firestore.collection(invoicesCollection).doc(invoiceId).get();
        if (invoiceSnap.exists) invoiceDoc = invoiceSnap;
      }
    }

    if (source == OsVoucherSource.payroll) {
      final payslipSnap = await firestore
          .collection(payslipsCollection)
          .where('voucherId', isEqualTo: voucherId)
          .limit(1)
          .get();
      if (payslipSnap.docs.isNotEmpty) {
        payslipDoc = payslipSnap.docs.first;
      }
    }

    String? payrollRunIdToRefresh;

    try {
      await firestore.runTransaction((tx) async {
        final freshSnap = await tx.get(voucherRef);
        if (!freshSnap.exists) {
          throw OsFinanceException('os.vouchers.error.not_found');
        }
        final fresh = OsVoucherModel.fromJson(freshSnap.data()!, freshSnap.id);

        if (fresh.amount != current.amount ||
            fresh.type != current.type ||
            fresh.bankAccountId != current.bankAccountId ||
            fresh.date != current.date) {
          // Allow concurrent metadata edits; re-sync from fresh for balance math.
        }

        OsVoucherModel? freshPair;
        if (source == OsVoucherSource.transfer) {
          final lockedPairDoc = pairDoc;
          if (lockedPairDoc == null) {
            throw OsFinanceException('os.vouchers.error.transfer_ambiguous');
          }
          final pairRef = lockedPairDoc.reference;
          final freshPairSnap = await tx.get(pairRef);
          if (!freshPairSnap.exists) {
            throw OsFinanceException('os.vouchers.error.transfer_ambiguous');
          }
          freshPair =
              OsVoucherModel.fromJson(freshPairSnap.data()!, freshPairSnap.id);
          final pair =
              OsVoucherModel.fromJson(lockedPairDoc.data()!, lockedPairDoc.id);
          if (freshPair.amount != pair.amount ||
              freshPair.date != pair.date ||
              freshPair.type != pair.type) {
            throw OsFinanceException('os.vouchers.error.transfer_ambiguous');
          }
        }

        final removeLegs = <OsVoucherBalanceLeg>[];
        final applyLegs = <OsVoucherBalanceLeg>[];
        final accountIdsToRead = <String>{};

        if (source == OsVoucherSource.transfer && transfer != null) {
          final oldPayment = _resolveTransferLegs(
            voucher: fresh,
            pair: freshPair,
          );
          final oldReceipt = _resolveTransferReceipt(
            voucher: fresh,
            pair: freshPair,
          );
          removeLegs.addAll([
            OsVoucherBalanceLeg.fromVoucher(oldPayment),
            OsVoucherBalanceLeg.fromVoucher(oldReceipt),
          ]);
          applyLegs.addAll([
            OsVoucherBalanceLeg(
              accountId: transfer.sourceAccountId,
              type: OsVoucherType.payment,
              amount: transfer.amount,
            ),
            OsVoucherBalanceLeg(
              accountId: transfer.destAccountId,
              type: OsVoucherType.receipt,
              amount: transfer.amount,
            ),
          ]);
          accountIdsToRead.addAll([
            oldPayment.bankAccountId,
            oldReceipt.bankAccountId,
            transfer.sourceAccountId,
            transfer.destAccountId,
          ]);
        } else {
          removeLegs.add(OsVoucherBalanceLeg.fromVoucher(fresh));
          var effectiveType = osVoucherTypeChangeAllowed(fresh)
              ? updated.type
              : fresh.type;
          if (source == OsVoucherSource.invoice ||
              (fresh.invoiceId != null && fresh.invoiceId!.trim().isNotEmpty)) {
            effectiveType = OsVoucherType.receipt;
          } else if (source == OsVoucherSource.expense ||
              source == OsVoucherSource.payroll) {
            effectiveType = OsVoucherType.payment;
          }
          applyLegs.add(
            OsVoucherBalanceLeg(
              accountId: updated.bankAccountId,
              type: effectiveType,
              amount: updated.amount,
            ),
          );
          accountIdsToRead.add(fresh.bankAccountId);
          accountIdsToRead.add(updated.bankAccountId);
        }

        final netDeltas = computeOsAccountNetDeltas(
          removeLegs: removeLegs,
          applyLegs: applyLegs,
        );

        final balances = <String, double>{};
        for (final accountId in accountIdsToRead) {
          final id = accountId.trim();
          if (id.isEmpty || balances.containsKey(id)) continue;
          final accountRef =
              firestore.collection(bankAccountsCollection).doc(id);
          final accountSnap = await tx.get(accountRef);
          if (!accountSnap.exists) {
            throw OsFinanceException('os.invoices.error.account_missing');
          }
          balances[id] = OsBankAccountModel.fromJson(
            accountSnap.data()!,
            accountSnap.id,
          ).balance;
        }

        final blocked = findOsInsufficientBalanceAccount(
          balancesByAccountId: balances,
          netDeltasByAccountId: netDeltas,
        );
        if (blocked != null) {
          throw OsFinanceException('os.accounts.transfer.error.insufficient');
        }

        for (final entry in netDeltas.entries) {
          final accountRef =
              firestore.collection(bankAccountsCollection).doc(entry.key);
          final accountSnap = await tx.get(accountRef);
          final account = OsBankAccountModel.fromJson(
            accountSnap.data()!,
            accountSnap.id,
          );
          tx.set(
            accountRef,
            account.copyWith(balance: account.balance + entry.value).toJson(),
            SetOptions(merge: true),
          );
        }

        if (source == OsVoucherSource.transfer && transfer != null) {
          final oldPayment = _resolveTransferLegs(
            voucher: fresh,
            pair: freshPair,
          );
          final oldReceipt = _resolveTransferReceipt(
            voucher: fresh,
            pair: freshPair,
          );

          final sourceRef =
              firestore.collection(bankAccountsCollection).doc(transfer.sourceAccountId);
          final destRef =
              firestore.collection(bankAccountsCollection).doc(transfer.destAccountId);
          final sourceSnap = await tx.get(sourceRef);
          final destSnap = await tx.get(destRef);
          final sourceName = OsBankAccountModel.fromJson(
            sourceSnap.data()!,
            sourceSnap.id,
          ).name;
          final destName = OsBankAccountModel.fromJson(
            destSnap.data()!,
            destSnap.id,
          ).name;

          tx.set(
            firestore.collection(vouchersCollection).doc(oldPayment.id),
            oldPayment
                .copyWith(
                  amount: transfer.amount,
                  date: transfer.date,
                  bankAccountId: transfer.sourceAccountId,
                  payeeOrPayer: destName,
                  description: transfer.paymentDescription,
                )
                .toJson(),
            SetOptions(merge: true),
          );
          tx.set(
            firestore.collection(vouchersCollection).doc(oldReceipt.id),
            oldReceipt
                .copyWith(
                  amount: transfer.amount,
                  date: transfer.date,
                  bankAccountId: transfer.destAccountId,
                  payeeOrPayer: sourceName,
                  description: transfer.receiptDescription,
                )
                .toJson(),
            SetOptions(merge: true),
          );
        } else {
          var effectiveType = osVoucherTypeChangeAllowed(fresh)
              ? updated.type
              : fresh.type;
          if (source == OsVoucherSource.invoice ||
              (fresh.invoiceId != null && fresh.invoiceId!.trim().isNotEmpty)) {
            effectiveType = OsVoucherType.receipt;
          } else if (source == OsVoucherSource.expense ||
              source == OsVoucherSource.payroll) {
            effectiveType = OsVoucherType.payment;
          }
          final toSave = fresh.copyWith(
            type: effectiveType,
            amount: updated.amount,
            date: updated.date,
            payeeOrPayer: updated.payeeOrPayer,
            payeePhone: updated.payeePhone,
            description: updated.description,
            bankAccountId: updated.bankAccountId.trim(),
          );
          tx.set(voucherRef, toSave.toJson(), SetOptions(merge: true));

          if (expenseDoc != null) {
            final expense = OsDailyExpenseModel.fromJson(
              expenseDoc.data()!,
              expenseDoc.id,
            );
            final payee = updated.payeeOrPayer.trim();
            final expensePayee = (expense.vendor?.trim().isNotEmpty ?? false)
                ? expense.copyWith(vendor: payee)
                : expense.copyWith(paidBy: payee);
            tx.set(
              expenseDoc.reference,
              expensePayee
                  .copyWith(
                    amount: updated.amount,
                    date: updated.date,
                    bankAccountId: updated.bankAccountId.trim(),
                  )
                  .toJson(),
              SetOptions(merge: true),
            );
          }

          if (invoiceDoc != null) {
            final invoice = OsInvoiceModel.fromJson(
              invoiceDoc.data()!,
              invoiceDoc.id,
            );
            final discount = invoice.discount < 0 ? 0.0 : invoice.discount;
            final newTotal = updated.amount;
            final newAmount = newTotal - invoice.vat + discount;
            tx.set(
              invoiceDoc.reference,
              invoice
                  .copyWith(
                    total: newTotal,
                    amount: newAmount,
                    bankAccountId: updated.bankAccountId.trim(),
                    clientName: updated.payeeOrPayer.trim(),
                  )
                  .toJson(),
              SetOptions(merge: true),
            );
          }

          if (payslipDoc != null) {
            final payslipData = Map<String, dynamic>.from(payslipDoc.data()!);
            payslipData['netPay'] = updated.amount;
            tx.set(payslipDoc.reference, payslipData, SetOptions(merge: true));
            payrollRunIdToRefresh = payslipData['runId'] as String?;
          }
        }
      });

      return OsVoucherUpdateResult(
        payrollRunIdToRefresh: () {
          final runId = payrollRunIdToRefresh?.trim() ?? '';
          return runId.isEmpty ? null : runId;
        }(),
      );
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('updateVoucher failed: $e\n$st');
      throw OsFinanceException('os.common.save_failed');
    }
  }

  /// Deletes a voucher and reverses its bank effect.
  /// System vouchers route through their parent (invoice / expense) or
  /// reverse a transfer pair once — never double-debit.
  static Future<bool> deleteVoucher(String id) async {
    final voucherId = id.trim();
    if (voucherId.isEmpty) {
      throw OsFinanceException('os.vouchers.error.missing_id');
    }

    final firestore = FirebaseFirestore.instance;
    final voucherRef =
        firestore.collection(vouchersCollection).doc(voucherId);

    try {
      final snap = await voucherRef.get();
      if (!snap.exists) {
        throw OsFinanceException('os.vouchers.error.not_found');
      }
      final voucher = OsVoucherModel.fromJson(snap.data()!, snap.id);
      final source = voucher.source?.trim() ?? '';

      if (source == OsVoucherSource.invoice ||
          (voucher.invoiceId != null && voucher.invoiceId!.trim().isNotEmpty)) {
        final invoiceId = voucher.invoiceId?.trim() ?? '';
        if (invoiceId.isEmpty) {
          throw OsFinanceException('os.vouchers.error.missing_id');
        }
        return await deleteInvoice(invoiceId);
      }

      if (source == OsVoucherSource.expense ||
          source == OsVoucherSource.payroll) {
        final expenseSnap = await firestore
            .collection(expensesCollection)
            .where('voucherId', isEqualTo: voucherId)
            .limit(1)
            .get();
        if (expenseSnap.docs.isNotEmpty) {
          return await deleteExpense(expenseSnap.docs.first.id);
        }
        // Orphan voucher — reverse balance only.
        return await _deleteVoucherReversingBalance(voucherId);
      }

      if (source == OsVoucherSource.transfer) {
        return await _deleteTransferPair(voucher);
      }

      // MANUAL / legacy empty source
      return await _deleteVoucherReversingBalance(voucherId);
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('deleteVoucher failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> _deleteVoucherReversingBalance(String voucherId) async {
    final firestore = FirebaseFirestore.instance;
    final voucherRef =
        firestore.collection(vouchersCollection).doc(voucherId);

    await firestore.runTransaction((tx) async {
      final snap = await tx.get(voucherRef);
      if (!snap.exists) {
        throw OsFinanceException('os.vouchers.error.not_found');
      }
      final voucher = OsVoucherModel.fromJson(snap.data()!, snap.id);
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
  }

  /// Undo a transfer: restore source +, dest − once, delete both audit vouchers.
  static Future<bool> _deleteTransferPair(OsVoucherModel voucher) async {
    final firestore = FirebaseFirestore.instance;
    final amount = voucher.amount;
    final date = voucher.date;
    final oppositeType = voucher.type == OsVoucherType.payment
        ? OsVoucherType.receipt
        : OsVoucherType.payment;

    final candidates = await firestore
        .collection(vouchersCollection)
        .where('source', isEqualTo: OsVoucherSource.transfer)
        .where('date', isEqualTo: date)
        .where('amount', isEqualTo: amount)
        .limit(FirestoreQueryLimits.osVouchers)
        .get();

    DocumentSnapshot<Map<String, dynamic>>? pairDoc;
    for (final d in candidates.docs) {
      if (d.id == voucher.id) continue;
      final other = OsVoucherModel.fromJson(d.data(), d.id);
      if (other.type == oppositeType) {
        pairDoc = d;
        break;
      }
    }

    final payment = voucher.type == OsVoucherType.payment
        ? voucher
        : (pairDoc != null
            ? OsVoucherModel.fromJson(pairDoc.data()!, pairDoc.id)
            : null);
    final receipt = voucher.type == OsVoucherType.receipt
        ? voucher
        : (pairDoc != null
            ? OsVoucherModel.fromJson(pairDoc.data()!, pairDoc.id)
            : null);

    if (payment == null || receipt == null) {
      // Incomplete pair — reverse this voucher alone.
      return _deleteVoucherReversingBalance(voucher.id!);
    }

    // Transfer adjusted balances once at create time (payment −source, receipt +dest).
    // Undo once: +source, −dest. Do not apply reverseDelta on each voucher.
    final sourceId = payment.bankAccountId.trim();
    final destId = receipt.bankAccountId.trim();

    await firestore.runTransaction((tx) async {
      final sourceRef =
          firestore.collection(bankAccountsCollection).doc(sourceId);
      final destRef =
          firestore.collection(bankAccountsCollection).doc(destId);
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
      final nextDest =
          (dest.balance - amount).clamp(0.0, double.infinity);
      tx.set(
        sourceRef,
        source.copyWith(balance: source.balance + amount).toJson(),
        SetOptions(merge: true),
      );
      tx.set(
        destRef,
        dest.copyWith(balance: nextDest).toJson(),
        SetOptions(merge: true),
      );
      tx.delete(firestore.collection(vouchersCollection).doc(payment.id));
      tx.delete(firestore.collection(vouchersCollection).doc(receipt.id));
    });
    return true;
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

  /// Updates expense fields and syncs the linked payment voucher when present.
  static Future<bool> updateExpense({
    required OsDailyExpenseModel expense,
    required String voucherDescription,
  }) async {
    final id = expense.id?.trim();
    if (id == null || id.isEmpty) return false;

    final firestore = FirebaseFirestore.instance;
    final expenseRef = firestore.collection(expensesCollection).doc(id);

    try {
      final existingSnap = await expenseRef.get();
      if (!existingSnap.exists) return false;
      final existing = OsDailyExpenseModel.fromJson(
        existingSnap.data()!,
        existingSnap.id,
      );
      final voucherId = existing.voucherId?.trim() ?? '';

      if (voucherId.isNotEmpty) {
        final voucherSnap =
            await firestore.collection(vouchersCollection).doc(voucherId).get();
        if (voucherSnap.exists) {
          final voucher =
              OsVoucherModel.fromJson(voucherSnap.data()!, voucherSnap.id);
          final payee = (expense.vendor?.trim().isNotEmpty ?? false)
              ? expense.vendor!.trim()
              : expense.paidBy;
          await updateVoucher(
            updated: voucher.copyWith(
              amount: expense.amount,
              date: expense.date,
              bankAccountId: expense.bankAccountId?.trim() ?? '',
              payeeOrPayer: payee,
              description: voucherDescription,
            ),
          );
        }
      }

      await expenseRef.set(expense.toJson(), SetOptions(merge: true));
      return true;
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('updateExpense failed: $e\n$st');
      return false;
    }
  }

  /// Deletes an expense and reverses / removes its linked payment voucher.
  static Future<bool> deleteExpense(String id) async {
    final expenseId = id.trim();
    if (expenseId.isEmpty) return false;

    final firestore = FirebaseFirestore.instance;
    final expenseRef =
        firestore.collection(expensesCollection).doc(expenseId);

    try {
      final expenseSnap = await expenseRef.get();
      // Idempotent: already gone counts as success (paid reverse / retries).
      if (!expenseSnap.exists) return true;
      final expense = OsDailyExpenseModel.fromJson(
        expenseSnap.data()!,
        expenseSnap.id,
      );
      final voucherId = expense.voucherId?.trim();

      if (voucherId != null && voucherId.isNotEmpty) {
        await firestore.runTransaction((tx) async {
          final voucherRef =
              firestore.collection(vouchersCollection).doc(voucherId);
          final voucherSnap = await tx.get(voucherRef);
          if (voucherSnap.exists) {
            final voucher = OsVoucherModel.fromJson(
              voucherSnap.data()!,
              voucherSnap.id,
            );
            final accountId = voucher.bankAccountId.trim();
            if (accountId.isNotEmpty) {
              final accountRef =
                  firestore.collection(bankAccountsCollection).doc(accountId);
              final accountSnap = await tx.get(accountRef);
              if (accountSnap.exists) {
                final account = OsBankAccountModel.fromJson(
                  accountSnap.data()!,
                  accountSnap.id,
                );
                final reverseDelta = voucher.type == OsVoucherType.payment
                    ? voucher.amount
                    : -voucher.amount;
                tx.set(
                  accountRef,
                  account
                      .copyWith(balance: account.balance + reverseDelta)
                      .toJson(),
                  SetOptions(merge: true),
                );
              }
            }
            tx.delete(voucherRef);
          }
          tx.delete(expenseRef);
        });
      } else {
        await expenseRef.delete();
      }
      return true;
    } on OsFinanceException {
      rethrow;
    } catch (e, st) {
      appLog('deleteExpense failed: $e\n$st');
      return false;
    }
  }
}
