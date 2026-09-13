import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/Os/OsEmployeeAdvanceModel.dart';
import 'package:point/Models/Os/OsEmployeeContractModel.dart';
import 'package:point/Models/Os/OsPayrollRunModel.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Models/Os/os_payroll_enums.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/firestore/firestore_os_payroll_api.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/View/Os/os_finance_format.dart';

class OsPayrollController extends GetxController {
  final runs = <OsPayrollRunModel>[].obs;
  final payslips = <OsPayslipModel>[].obs;
  final contracts = <OsEmployeeContractModel>[].obs;
  final advances = <OsEmployeeAdvanceModel>[].obs;
  final isLoading = false.obs;

  /// Selected payroll period `YYYY-MM`.
  final selectedPeriod = FirestoreOsPayrollApi.currentPeriod().obs;

  /// In-memory draft adjustments keyed by employeeId for the active run tab.
  final draftAllowances = <String, double>{}.obs;
  final draftDeductions = <String, double>{}.obs;
  final draftSocialSecurity = <String, double>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _bindStreams();
  }

  void _bindStreams() {
    runs.bindStream(FirestoreOsPayrollApi.streamPayrollRuns());
    payslips.bindStream(FirestoreOsPayrollApi.streamPayslips());
    contracts.bindStream(FirestoreOsPayrollApi.streamContracts());
    advances.bindStream(FirestoreOsPayrollApi.streamAdvances());
  }

  List<EmployeeModel> get employees {
    if (!Get.isRegistered<HomeController>()) return const [];
    return Get.find<HomeController>().employees.toList();
  }

  OsFinanceController? get _finance {
    if (!Get.isRegistered<OsFinanceController>()) return null;
    return Get.find<OsFinanceController>();
  }

  OsPayrollRunModel? runForPeriod(String period) {
    for (final r in runs) {
      if (r.period == period) return r;
    }
    return null;
  }

  List<OsPayslipModel> payslipsForPeriod(String period) =>
      payslips.where((p) => p.period == period).toList();

  OsPayslipModel? payslipForEmployee(String period, String employeeId) {
    for (final p in payslips) {
      if (p.period == period && p.employeeId == employeeId) return p;
    }
    return null;
  }

  void setDraftAllowances(String employeeId, double value) {
    draftAllowances[employeeId] = value;
    draftAllowances.refresh();
  }

  void setDraftDeductions(String employeeId, double value) {
    draftDeductions[employeeId] = value;
    draftDeductions.refresh();
  }

  void setDraftSocialSecurity(String employeeId, double value) {
    draftSocialSecurity[employeeId] = value;
    draftSocialSecurity.refresh();
  }

  double draftAllowanceOf(String employeeId) =>
      draftAllowances[employeeId] ?? 0;
  double draftDeductionOf(String employeeId) =>
      draftDeductions[employeeId] ?? 0;
  double draftSocialOf(String employeeId) =>
      draftSocialSecurity[employeeId] ?? 0;

  double suggestedAdvanceFor(String employeeId) =>
      FirestoreOsPayrollApi.suggestedAdvanceDeduction(
        advances.toList(),
        employeeId,
      );

  double netForEmployee(EmployeeModel emp) {
    final id = emp.id ?? '';
    final basic = emp.salary ?? 0;
    final advance = suggestedAdvanceFor(id);
    return FirestoreOsPayrollApi.computeNetPay(
      basicSalary: basic,
      allowances: draftAllowanceOf(id),
      deductions: draftDeductionOf(id),
      socialSecurity: draftSocialOf(id),
      advanceDeduction: advance,
    );
  }

  /// Live payslip preview (saved slip if present, otherwise draft + employee data).
  OsPayslipModel previewPayslip(EmployeeModel emp) {
    final empId = emp.id ?? '';
    final period = selectedPeriod.value;
    final existing = payslipForEmployee(period, empId);
    if (existing != null) return existing;

    final basic = emp.salary ?? 0;
    final allowances = draftAllowanceOf(empId);
    final deductions = draftDeductionOf(empId);
    final social = draftSocialOf(empId);
    final advance = suggestedAdvanceFor(empId);
    final net = FirestoreOsPayrollApi.computeNetPay(
      basicSalary: basic,
      allowances: allowances,
      deductions: deductions,
      socialSecurity: social,
      advanceDeduction: advance,
    );
    return OsPayslipModel(
      period: period,
      employeeId: empId,
      employeeName: emp.name ?? '',
      jobTitle: emp.jobTitle,
      branchId: emp.branchId,
      hireDate: emp.hireDate,
      basicSalary: basic,
      allowances: allowances,
      deductions: deductions,
      socialSecurity: social,
      advanceDeduction: advance,
      netPay: net,
      status: OsPayslipStatus.pending,
      displayNumber: null,
      createdAt: DateTime.now(),
    );
  }

  Future<OsPayrollRunModel?> ensureCurrentRun() async {
    isLoading.value = true;
    try {
      return await FirestoreOsPayrollApi.ensureRunForPeriod(
        selectedPeriod.value,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Creates or updates a PENDING payslip from the current draft for [emp].
  Future<bool> generatePayslip(EmployeeModel emp) async {
    final empId = emp.id?.trim() ?? '';
    if (empId.isEmpty) return false;
    final basic = emp.salary ?? 0;
    if (basic <= 0) {
      throw OsPayrollException(AppLocaleKeys.osPayrollErrorNoSalary);
    }

    isLoading.value = true;
    try {
      final period = selectedPeriod.value;
      final run = await FirestoreOsPayrollApi.ensureRunForPeriod(period);
      if (run == null) return false;

      final existing = payslipForEmployee(period, empId);
      if (existing != null && existing.isPaid) {
        throw OsPayrollException(AppLocaleKeys.osPayrollErrorAlreadyPaid);
      }

      final allowances = draftAllowanceOf(empId);
      final deductions = draftDeductionOf(empId);
      final social = draftSocialOf(empId);
      final advance = suggestedAdvanceFor(empId);
      final net = FirestoreOsPayrollApi.computeNetPay(
        basicSalary: basic,
        allowances: allowances,
        deductions: deductions,
        socialSecurity: social,
        advanceDeduction: advance,
      );

      final slip = OsPayslipModel(
        id: existing?.id,
        runId: run.id,
        period: period,
        employeeId: empId,
        employeeName: emp.name ?? '',
        jobTitle: emp.jobTitle,
        branchId: emp.branchId,
        hireDate: emp.hireDate,
        basicSalary: basic,
        allowances: allowances,
        deductions: deductions,
        socialSecurity: social,
        advanceDeduction: advance,
        netPay: net,
        status: OsPayslipStatus.pending,
        displayNumber: existing?.displayNumber,
        createdAt: existing?.createdAt ?? DateTime.now(),
      );
      final ok = await FirestoreOsPayrollApi.upsertPayslip(slip);
      if (ok) {
        try {
          await NotificationService.notifyEmployeePayslipReady(
            employeeId: empId,
            period: period,
            netPayLabel: OsFinanceFormat.money(net),
          );
        } catch (e, s) {
          appLog(
            'generatePayslip employee notify failed: $e',
            error: e,
            stackTrace: s,
          );
        }
      }
      return ok;
    } on OsPayrollException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> disbursePayslip({
    required OsPayslipModel payslip,
    required String bankAccountId,
  }) async {
    isLoading.value = true;
    try {
      // Ensure finance streams are warm (bank debit path).
      _finance;
      final ref = payslip.displayNumber ?? payslip.id ?? '';
      final advanceId = FirestoreOsPayrollApi.activeAdvanceIdForEmployee(
        advances.toList(),
        payslip.employeeId,
      );
      final ok = await FirestoreOsPayrollApi.disbursePayslip(
        payslip: payslip,
        bankAccountId: bankAccountId,
        expenseTitle: AppLocaleKeys.osPayrollExpenseTitle.trParams({
          'name': payslip.employeeName,
          'period': payslip.period,
        }),
        voucherDescription: AppLocaleKeys.osPayrollExpenseVoucherDesc.trParams({
          'name': payslip.employeeName,
          'ref': ref,
          'period': payslip.period,
        }),
        advanceId: payslip.advanceDeduction > 0 ? advanceId : null,
      );
      if (ok) {
        try {
          await NotificationService.notifyEmployeePayslipPaid(
            employeeId: payslip.employeeId,
            period: payslip.period,
            netPayLabel: OsFinanceFormat.money(payslip.netPay),
            advanceDeductionLabel: payslip.advanceDeduction > 0
                ? OsFinanceFormat.money(payslip.advanceDeduction)
                : null,
          );
        } catch (e, s) {
          appLog(
            'disbursePayslip employee notify failed: $e',
            error: e,
            stackTrace: s,
          );
        }
      }
      return ok;
    } on OsPayrollException catch (e) {
      appLog('disbursePayslip rejected: ${e.messageKey}');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deletePayslip(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsPayrollApi.deletePayslip(id);
    } on OsPayrollException {
      rethrow;
    } on OsFinanceException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deletePayrollRun(String runId) async {
    isLoading.value = true;
    try {
      return await FirestoreOsPayrollApi.deletePayrollRun(runId);
    } on OsPayrollException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveContract(OsEmployeeContractModel contract) async {
    isLoading.value = true;
    try {
      return await FirestoreOsPayrollApi.upsertContract(contract);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteContract(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsPayrollApi.deleteContract(id);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveAdvance(OsEmployeeAdvanceModel advance) async {
    final isNew = advance.id == null || advance.id!.trim().isEmpty;
    isLoading.value = true;
    try {
      final ok = await FirestoreOsPayrollApi.upsertAdvance(advance);
      if (ok && isNew) {
        try {
          await NotificationService.notifyEmployeeAdvanceRecorded(
            employeeId: advance.employeeId,
            amountLabel: OsFinanceFormat.money(advance.totalAmount),
          );
        } catch (e, s) {
          appLog(
            'saveAdvance employee notify failed: $e',
            error: e,
            stackTrace: s,
          );
        }
      }
      return ok;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> repayAdvance({
    required String advanceId,
    required double amount,
  }) async {
    isLoading.value = true;
    try {
      return await FirestoreOsPayrollApi.applyAdvanceRepayment(
        advanceId: advanceId,
        amount: amount,
      );
    } on OsPayrollException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> writeOffAdvance(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsPayrollApi.writeOffAdvance(id);
    } on OsPayrollException {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteAdvance(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsPayrollApi.deleteAdvance(id);
    } finally {
      isLoading.value = false;
    }
  }
}
