import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/firestore/firestore_os_payroll_api.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

Future<void> showOsPayrollAdjustDialog(
  BuildContext context,
  EmployeeModel emp,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OsPayrollAdjustDialog(emp: emp),
  );
}

class _OsPayrollAdjustDialog extends StatefulWidget {
  const _OsPayrollAdjustDialog({required this.emp});

  final EmployeeModel emp;

  @override
  State<_OsPayrollAdjustDialog> createState() => _OsPayrollAdjustDialogState();
}

class _OsPayrollAdjustDialogState extends State<_OsPayrollAdjustDialog> {
  late final TextEditingController _allowancesCtrl;
  late final TextEditingController _deductionsCtrl;
  late final TextEditingController _socialCtrl;

  String get _empId => widget.emp.id ?? '';

  double _parse(TextEditingController ctrl) =>
      double.tryParse(ctrl.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    final payroll = Get.find<OsPayrollController>();
    final slip = payroll.payslipForEmployee(
      payroll.selectedPeriod.value,
      _empId,
    );
    final allowances = payroll.draftAllowances.containsKey(_empId)
        ? payroll.draftAllowanceOf(_empId)
        : (slip?.allowances ?? 0);
    final deductions = payroll.draftDeductions.containsKey(_empId)
        ? payroll.draftDeductionOf(_empId)
        : (slip?.deductions ?? 0);
    final social = payroll.draftSocialSecurity.containsKey(_empId)
        ? payroll.draftSocialOf(_empId)
        : (slip?.socialSecurity ?? 0);
    _allowancesCtrl = TextEditingController(text: _fmt(allowances));
    _deductionsCtrl = TextEditingController(text: _fmt(deductions));
    _socialCtrl = TextEditingController(text: _fmt(social));
  }

  String _fmt(double v) => v.toStringAsFixed(0);

  @override
  void dispose() {
    _allowancesCtrl.dispose();
    _deductionsCtrl.dispose();
    _socialCtrl.dispose();
    super.dispose();
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.appTheme.secondaryText,
        ),
      ),
    );
  }

  Widget _amountField(TextEditingController ctrl) {
    return osTypedTextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      decoration: osDialogFieldDecoration(
        context,
        suffixText: AppLocaleKeys.osInvoicesCurrency.tr,
      ),
    );
  }

  Widget _readonlyValue(String value) {
    final theme = context.appTheme;
    return InputDecorator(
      decoration: osDialogFieldDecoration(context),
      child: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: theme.primaryText,
        ),
      ),
    );
  }

  void _save() {
    final payroll = Get.find<OsPayrollController>();
    payroll.setDraftAllowances(_empId, _parse(_allowancesCtrl));
    payroll.setDraftDeductions(_empId, _parse(_deductionsCtrl));
    payroll.setDraftSocialSecurity(_empId, _parse(_socialCtrl));
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OsSnackbar.success(
        AppLocaleKeys.osPayrollTitle.tr,
        AppLocaleKeys.osPayrollAdjustSaved.tr,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final payroll = Get.find<OsPayrollController>();
    final basic = widget.emp.salary ?? 0;
    final advance = payroll.suggestedAdvanceFor(_empId);
    final net = FirestoreOsPayrollApi.computeNetPay(
      basicSalary: basic,
      allowances: _parse(_allowancesCtrl),
      deductions: _parse(_deductionsCtrl),
      socialSecurity: _parse(_socialCtrl),
      advanceDeduction: advance,
    );

    return OsDialogFrame(
      title: AppLocaleKeys.osPayrollAdjustTitle.tr,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(AppLocaleKeys.osPayrollColEmployee.tr),
          _readonlyValue(widget.emp.name ?? ''),
          const SizedBox(height: 16),
          _label(AppLocaleKeys.osPayrollColBasic.tr),
          _readonlyValue(OsFinanceFormat.money(basic)),
          if (advance > 0) ...[
            const SizedBox(height: 16),
            _label(AppLocaleKeys.osPayrollColAdvance.tr),
            _readonlyValue(OsFinanceFormat.money(advance)),
          ],
          const SizedBox(height: 16),
          _label(AppLocaleKeys.osPayrollColAllowances.tr),
          _amountField(_allowancesCtrl),
          const SizedBox(height: 16),
          _label(AppLocaleKeys.osPayrollColDeductions.tr),
          _amountField(_deductionsCtrl),
          const SizedBox(height: 16),
          _label(AppLocaleKeys.osPayrollColSocial.tr),
          _amountField(_socialCtrl),
          const SizedBox(height: 16),
          _label(AppLocaleKeys.osPayrollAdjustNetPreview.tr),
          _readonlyValue(OsFinanceFormat.money(net)),
          const SizedBox(height: 24),
          OsFormDialogActions(
            saveLabel: AppLocaleKeys.osCommonSave.tr,
            onSave: _save,
            onCancel: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
