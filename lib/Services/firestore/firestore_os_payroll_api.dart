import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/Models/Os/OsEmployeeAdvanceModel.dart';
import 'package:point/Models/Os/OsEmployeeContractModel.dart';
import 'package:point/Models/Os/OsPayrollRunModel.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Models/Os/os_expense_constants.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Models/Os/os_payroll_enums.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';
import 'package:point/Services/firestore/firestore_stream_utils.dart';
import 'package:point/Utils/app_log.dart';
import 'package:uuid/uuid.dart';

class OsPayrollException implements Exception {
  OsPayrollException(this.messageKey);
  final String messageKey;

  @override
  String toString() => messageKey;
}

/// Firestore API for Point OS payroll (runs, payslips, contracts, advances).
class FirestoreOsPayrollApi {
  FirestoreOsPayrollApi._();

  static const payrollRunsCollection = 'os_payroll_runs';
  static const payslipsCollection = 'os_payslips';
  static const contractsCollection = 'os_employee_contracts';
  static const advancesCollection = 'os_employee_advances';
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  static String currentPeriod([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}';
  }

  static double computeNetPay({
    required double basicSalary,
    double allowances = 0,
    double deductions = 0,
    double socialSecurity = 0,
    double advanceDeduction = 0,
  }) {
    return basicSalary +
        allowances -
        deductions -
        socialSecurity -
        advanceDeduction;
  }

  // --- Streams ---

  static Stream<List<OsPayrollRunModel>> streamPayrollRuns() {
    final mapped = FirebaseFirestore.instance
        .collection(payrollRunsCollection)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.osPayrollRuns)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsPayrollRunModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_payroll_runs');
  }

  static Stream<List<OsPayslipModel>> streamPayslips() {
    final mapped = FirebaseFirestore.instance
        .collection(payslipsCollection)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.osPayslips)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsPayslipModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_payslips');
  }

  static Stream<List<OsEmployeeContractModel>> streamContracts() {
    final mapped = FirebaseFirestore.instance
        .collection(contractsCollection)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.osContracts)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsEmployeeContractModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_employee_contracts');
  }

  static Stream<List<OsEmployeeAdvanceModel>> streamAdvances() {
    final mapped = FirebaseFirestore.instance
        .collection(advancesCollection)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.osAdvances)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsEmployeeAdvanceModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_employee_advances');
  }

  // --- Display numbers ---

  static Future<String> nextPayslipDisplayNumber(String period) async {
    final snap = await FirebaseFirestore.instance
        .collection(payslipsCollection)
        .where('period', isEqualTo: period)
        .limit(FirestoreQueryLimits.osPayslips)
        .get();
    var maxN = 0;
    final prefix = 'SLIP-$period-';
    for (final d in snap.docs) {
      final raw = d.data()['displayNumber'] as String? ?? '';
      if (!raw.startsWith(prefix)) continue;
      final n = int.tryParse(raw.substring(prefix.length)) ?? 0;
      if (n > maxN) maxN = n;
    }
    return '$prefix${(maxN + 1).toString().padLeft(2, '0')}';
  }

  static Future<String> nextContractDisplayNumber() async {
    final snap = await FirebaseFirestore.instance
        .collection(contractsCollection)
        .limit(FirestoreQueryLimits.osContracts)
        .get();
    var maxN = 0;
    for (final d in snap.docs) {
      final raw = d.data()['displayNumber'] as String? ?? '';
      final m = RegExp(r'CON-(\d+)', caseSensitive: false).firstMatch(raw);
      if (m == null) continue;
      final n = int.tryParse(m.group(1)!) ?? 0;
      if (n > maxN) maxN = n;
    }
    return 'CON-${(maxN + 1).toString().padLeft(2, '0')}';
  }

  // --- Payroll runs ---

  static Future<OsPayrollRunModel?> ensureRunForPeriod(String period) async {
    try {
      final existing = await FirebaseFirestore.instance
          .collection(payrollRunsCollection)
          .where('period', isEqualTo: period)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        final d = existing.docs.first;
        return OsPayrollRunModel.fromJson(d.data(), d.id);
      }
      final id = newId();
      final run = OsPayrollRunModel(
        id: id,
        period: period,
        status: OsPayrollRunStatus.draft,
        createdAt: DateTime.now(),
      );
      await FirebaseFirestore.instance
          .collection(payrollRunsCollection)
          .doc(id)
          .set(run.toJson(), SetOptions(merge: true));
      return run;
    } catch (e, st) {
      appLog('ensureRunForPeriod failed: $e\n$st');
      return null;
    }
  }

  static Future<bool> upsertPayrollRun(OsPayrollRunModel run) async {
    try {
      final id = (run.id == null || run.id!.trim().isEmpty) ? newId() : run.id!;
      final toSave = run.copyWith(id: id);
      await FirebaseFirestore.instance
          .collection(payrollRunsCollection)
          .doc(id)
          .set(toSave.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('upsertPayrollRun failed: $e\n$st');
      return false;
    }
  }

  static Future<void> refreshRunTotals(String runId) async {
    try {
      final slips = await FirebaseFirestore.instance
          .collection(payslipsCollection)
          .where('runId', isEqualTo: runId)
          .limit(FirestoreQueryLimits.osPayslips)
          .get();
      var gross = 0.0;
      var deductions = 0.0;
      var net = 0.0;
      var paidCount = 0;
      for (final d in slips.docs) {
        final s = OsPayslipModel.fromJson(d.data(), d.id);
        gross += s.totalEarnings;
        deductions += s.totalDeductions;
        net += s.netPay;
        if (s.isPaid) paidCount++;
      }
      final count = slips.docs.length;
      String status = OsPayrollRunStatus.draft;
      if (count > 0 && paidCount == count) {
        status = OsPayrollRunStatus.completed;
      } else if (paidCount > 0) {
        status = OsPayrollRunStatus.partial;
      }
      await FirebaseFirestore.instance
          .collection(payrollRunsCollection)
          .doc(runId)
          .set({
        'totalGross': gross,
        'totalDeductions': deductions,
        'totalNet': net,
        'employeeCount': count,
        'status': status,
      }, SetOptions(merge: true));
    } catch (e, st) {
      appLog('refreshRunTotals failed: $e\n$st');
    }
  }

  // --- Payslips ---

  static Future<bool> upsertPayslip(OsPayslipModel slip) async {
    try {
      final id =
          (slip.id == null || slip.id!.trim().isEmpty) ? newId() : slip.id!;
      var display = slip.displayNumber;
      if (display == null || display.trim().isEmpty) {
        display = await nextPayslipDisplayNumber(slip.period);
      }
      final toSave = slip.copyWith(id: id, displayNumber: display);
      await FirebaseFirestore.instance
          .collection(payslipsCollection)
          .doc(id)
          .set(toSave.toJson(), SetOptions(merge: true));
      final runId = toSave.runId;
      if (runId != null && runId.isNotEmpty) {
        await refreshRunTotals(runId);
      }
      return true;
    } catch (e, st) {
      appLog('upsertPayslip failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> deletePayslip(String id) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection(payslipsCollection).doc(id);
      final snap = await ref.get();
      if (!snap.exists) return false;
      final slip = OsPayslipModel.fromJson(snap.data()!, snap.id);

      if (slip.isPaid) {
        final expenseId = slip.expenseId?.trim();
        final voucherId = slip.voucherId?.trim();
        var reversed = false;
        if (expenseId != null && expenseId.isNotEmpty) {
          reversed = await FirestoreOsFinanceApi.deleteExpense(expenseId);
        }
        if (!reversed && voucherId != null && voucherId.isNotEmpty) {
          reversed = await FirestoreOsFinanceApi.deleteVoucher(voucherId);
        }
        // Paid slips must reverse ledger before the doc is removed.
        if ((expenseId != null && expenseId.isNotEmpty) ||
            (voucherId != null && voucherId.isNotEmpty)) {
          if (!reversed) return false;
        }

        final ded = slip.advanceDeduction;
        final advId = slip.advanceId?.trim();
        if (ded > 0 && advId != null && advId.isNotEmpty) {
          await undoAdvanceRepayment(advanceId: advId, amount: ded);
        }
      }

      await ref.delete();
      final runId = slip.runId;
      if (runId != null && runId.isNotEmpty) {
        await refreshRunTotals(runId);
      }
      return true;
    } on OsFinanceException {
      rethrow;
    } on OsPayrollException {
      rethrow;
    } catch (e, st) {
      appLog('deletePayslip failed: $e\n$st');
      return false;
    }
  }

  /// Undo a prior [applyAdvanceRepayment] (subtract from paidAmount).
  static Future<bool> undoAdvanceRepayment({
    required String advanceId,
    required double amount,
  }) async {
    if (amount <= 0) return true;
    try {
      final ref = FirebaseFirestore.instance
          .collection(advancesCollection)
          .doc(advanceId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final adv = OsEmployeeAdvanceModel.fromJson(snap.data()!, snap.id);
        final newPaid =
            (adv.paidAmount - amount).clamp(0, adv.totalAmount).toDouble();
        final remaining =
            (adv.totalAmount - newPaid).clamp(0, double.infinity).toDouble();
        final status = remaining <= 0
            ? OsEmployeeAdvanceStatus.settled
            : OsEmployeeAdvanceStatus.active;
        tx.set(
          ref,
          adv
              .copyWith(
                paidAmount: newPaid,
                remainingAmount: remaining,
                status: status,
              )
              .toJson(),
          SetOptions(merge: true),
        );
      });
      return true;
    } catch (e, st) {
      appLog('undoAdvanceRepayment failed: $e\n$st');
      return false;
    }
  }

  /// Deletes all payslips in a run (reversing paid ones), then the run doc.
  static Future<bool> deletePayrollRun(String runId) async {
    final id = runId.trim();
    if (id.isEmpty) return false;
    try {
      final slips = await FirebaseFirestore.instance
          .collection(payslipsCollection)
          .where('runId', isEqualTo: id)
          .limit(FirestoreQueryLimits.osPayslips)
          .get();
      for (final d in slips.docs) {
        final ok = await deletePayslip(d.id);
        if (!ok) return false;
      }
      await FirebaseFirestore.instance
          .collection(payrollRunsCollection)
          .doc(id)
          .delete();
      return true;
    } on OsFinanceException {
      rethrow;
    } on OsPayrollException {
      rethrow;
    } catch (e, st) {
      appLog('deletePayrollRun failed: $e\n$st');
      return false;
    }
  }

  /// Disburses a pending payslip: posts payroll expense (+ voucher), marks paid,
  /// and applies advance installment repayment when [advanceDeduction] > 0.
  static Future<bool> disbursePayslip({
    required OsPayslipModel payslip,
    required String bankAccountId,
    required String expenseTitle,
    required String voucherDescription,
    String? advanceId,
    String paidBy = '',
  }) async {
    final slipId = payslip.id?.trim();
    if (slipId == null || slipId.isEmpty) {
      throw OsPayrollException(AppLocaleKeys.osPayrollErrorMissingId);
    }
    if (payslip.isPaid) {
      throw OsPayrollException(AppLocaleKeys.osPayrollErrorAlreadyPaid);
    }
    final accountId = bankAccountId.trim();
    if (accountId.isEmpty) {
      throw OsPayrollException(AppLocaleKeys.osPayrollErrorNoAccount);
    }
    if (payslip.netPay <= 0) {
      throw OsPayrollException(AppLocaleKeys.osPayrollErrorInvalidAmount);
    }

    try {
      final now = DateTime.now();
      final date = FirestoreOsFinanceApi.formatDate(now);
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final ref = payslip.displayNumber ?? slipId;

      final savedExpense = await FirestoreOsFinanceApi.createExpense(
        expense: OsDailyExpenseModel(
          title: expenseTitle,
          amount: payslip.netPay,
          category: AppLocaleKeys.osExpensesCatPayroll,
          date: date,
          time: time,
          paymentMethod: OsExpensePaymentMethod.bankTransfer,
          bankAccountId: accountId,
          branchId: payslip.branchId,
          paidBy: paidBy.isEmpty
              ? AppLocaleKeys.osExpensesPaidByAccountant
              : paidBy,
          vendor: payslip.employeeName,
          notes: ref,
          status: OsExpenseStatus.approved,
          createdAt: now,
        ),
        voucherDescription: voucherDescription,
        voucherSource: OsVoucherSource.payroll,
      );
      if (savedExpense == null) return false;

      await FirebaseFirestore.instance
          .collection(payslipsCollection)
          .doc(slipId)
          .set({
        'status': OsPayslipStatus.paid,
        'paidAt': Timestamp.fromDate(now),
        'expenseId': savedExpense.id,
        'voucherId': savedExpense.voucherId,
        if (advanceId != null && advanceId.trim().isNotEmpty)
          'advanceId': advanceId.trim(),
      }, SetOptions(merge: true));

      final ded = payslip.advanceDeduction;
      if (ded > 0 && advanceId != null && advanceId.trim().isNotEmpty) {
        await applyAdvanceRepayment(
          advanceId: advanceId.trim(),
          amount: ded,
        );
      }

      final runId = payslip.runId;
      if (runId != null && runId.isNotEmpty) {
        await refreshRunTotals(runId);
      }
      return true;
    } on OsFinanceException {
      rethrow;
    } on OsPayrollException {
      rethrow;
    } catch (e, st) {
      appLog('disbursePayslip failed: $e\n$st');
      return false;
    }
  }

  // --- Contracts ---

  static Future<bool> upsertContract(OsEmployeeContractModel contract) async {
    try {
      final id = (contract.id == null || contract.id!.trim().isEmpty)
          ? newId()
          : contract.id!;
      var display = contract.displayNumber;
      if (display == null || display.trim().isEmpty) {
        display = await nextContractDisplayNumber();
      }
      final toSave = contract.copyWith(id: id, displayNumber: display);
      await FirebaseFirestore.instance
          .collection(contractsCollection)
          .doc(id)
          .set(toSave.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('upsertContract failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> deleteContract(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection(contractsCollection)
          .doc(id)
          .delete();
      return true;
    } catch (e, st) {
      appLog('deleteContract failed: $e\n$st');
      return false;
    }
  }

  // --- Advances ---

  static Future<bool> upsertAdvance(OsEmployeeAdvanceModel advance) async {
    try {
      final id = (advance.id == null || advance.id!.trim().isEmpty)
          ? newId()
          : advance.id!;
      final remaining =
          (advance.totalAmount - advance.paidAmount).clamp(0, double.infinity);
      final status = remaining <= 0
          ? OsEmployeeAdvanceStatus.settled
          : OsEmployeeAdvanceStatus.active;
      final toSave = advance.copyWith(
        id: id,
        remainingAmount: remaining.toDouble(),
        status: status,
      );
      await FirebaseFirestore.instance
          .collection(advancesCollection)
          .doc(id)
          .set(toSave.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('upsertAdvance failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> applyAdvanceRepayment({
    required String advanceId,
    required double amount,
  }) async {
    if (amount <= 0) return true;
    try {
      final ref = FirebaseFirestore.instance
          .collection(advancesCollection)
          .doc(advanceId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw OsPayrollException(AppLocaleKeys.osAdvancesErrorNotFound);
        }
        final adv = OsEmployeeAdvanceModel.fromJson(
          snap.data()!,
          snap.id,
        );
        final newPaid = adv.paidAmount + amount;
        final remaining =
            (adv.totalAmount - newPaid).clamp(0, double.infinity).toDouble();
        final status = remaining <= 0
            ? OsEmployeeAdvanceStatus.settled
            : OsEmployeeAdvanceStatus.active;
        tx.set(
          ref,
          adv
              .copyWith(
                paidAmount: newPaid > adv.totalAmount
                    ? adv.totalAmount
                    : newPaid,
                remainingAmount: remaining,
                status: status,
              )
              .toJson(),
          SetOptions(merge: true),
        );
      });
      return true;
    } on OsPayrollException {
      rethrow;
    } catch (e, st) {
      appLog('applyAdvanceRepayment failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> writeOffAdvance(String id) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection(advancesCollection).doc(id);
      final snap = await ref.get();
      if (!snap.exists) {
        throw OsPayrollException(AppLocaleKeys.osAdvancesErrorNotFound);
      }
      final adv = OsEmployeeAdvanceModel.fromJson(snap.data()!, snap.id);
      await ref.set(
        adv
            .copyWith(
              paidAmount: adv.totalAmount,
              remainingAmount: 0,
              status: OsEmployeeAdvanceStatus.settled,
            )
            .toJson(),
        SetOptions(merge: true),
      );
      return true;
    } on OsPayrollException {
      rethrow;
    } catch (e, st) {
      appLog('writeOffAdvance failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> deleteAdvance(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection(advancesCollection)
          .doc(id)
          .delete();
      return true;
    } catch (e, st) {
      appLog('deleteAdvance failed: $e\n$st');
      return false;
    }
  }

  /// Suggested advance deduction for an employee in the current payroll cycle.
  static double suggestedAdvanceDeduction(
    List<OsEmployeeAdvanceModel> advances,
    String employeeId,
  ) {
    final active = advances.where(
      (a) =>
          a.employeeId == employeeId &&
          a.isActive &&
          a.remainingAmount > 0,
    );
    if (active.isEmpty) return 0;
    // Prefer the oldest active advance (lowest createdAt).
    final sorted = active.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final a = sorted.first;
    final installment =
        a.monthlyInstallment > 0 ? a.monthlyInstallment : a.remainingAmount;
    return installment < a.remainingAmount ? installment : a.remainingAmount;
  }

  static String? activeAdvanceIdForEmployee(
    List<OsEmployeeAdvanceModel> advances,
    String employeeId,
  ) {
    final active = advances.where(
      (a) =>
          a.employeeId == employeeId &&
          a.isActive &&
          a.remainingAmount > 0,
    );
    if (active.isEmpty) return null;
    final sorted = active.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted.first.id;
  }
}
