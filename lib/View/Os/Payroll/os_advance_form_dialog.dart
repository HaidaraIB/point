import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/Os/OsEmployeeAdvanceModel.dart';
import 'package:point/Models/Os/os_payroll_enums.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

Future<void> showOsAdvanceFormDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _OsAdvanceFormDialog(),
  );
}

class _OsAdvanceFormDialog extends StatefulWidget {
  const _OsAdvanceFormDialog();

  @override
  State<_OsAdvanceFormDialog> createState() => _OsAdvanceFormDialogState();
}

class _OsAdvanceFormDialogState extends State<_OsAdvanceFormDialog> {
  final _amountCtrl = TextEditingController();
  late String? _employeeId;
  var _saving = false;

  List<EmployeeModel> get _emps {
    return Get.find<OsPayrollController>()
        .employees
        .where((e) => (e.id ?? '').isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final emps = _emps;
    _employeeId = emps.isEmpty ? null : emps.first.id;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
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

  Future<void> _save() async {
    final payroll = Get.find<OsPayrollController>();
    final empId = _employeeId;
    if (empId == null || empId.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osAdvancesDialogTitle.tr,
        AppLocaleKeys.osAdvancesErrorEmployee.tr,
      );
      return;
    }
    final amount = double.tryParse(
          _amountCtrl.text.trim().replaceAll(',', ''),
        ) ??
        0;
    if (amount <= 0) {
      OsSnackbar.error(
        AppLocaleKeys.osAdvancesDialogTitle.tr,
        AppLocaleKeys.osAdvancesErrorAmount.tr,
      );
      return;
    }
    EmployeeModel? emp;
    for (final e in payroll.employees) {
      if (e.id == empId) {
        emp = e;
        break;
      }
    }
    if (emp == null) return;

    final installment = amount < 100000 ? amount : 100000.0;

    setState(() => _saving = true);
    try {
      final ok = await payroll.saveAdvance(
        OsEmployeeAdvanceModel(
          employeeId: empId,
          employeeName: emp.name ?? '',
          totalAmount: amount,
          monthlyInstallment: installment,
          paidAmount: 0,
          remainingAmount: amount,
          status: OsEmployeeAdvanceStatus.active,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          OsSnackbar.success(
            AppLocaleKeys.osAdvancesTitle.tr,
            AppLocaleKeys.osAdvancesSaved.tr,
          );
        });
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osAdvancesTitle.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emps = _emps;
    final currency = AppLocaleKeys.osInvoicesCurrency.tr;

    return OsDialogFrame(
      title: AppLocaleKeys.osAdvancesDialogTitle.tr,
      icon: Icons.account_balance_wallet_outlined,
      closeEnabled: !_saving,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(AppLocaleKeys.osAdvancesEmployee.tr),
          DropdownButtonFormField<String>(
            initialValue:
                emps.any((e) => e.id == _employeeId) ? _employeeId : null,
            decoration: osDialogFieldDecoration(context),
            items: emps
                .map(
                  (e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(
                      e.name ?? e.id ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _employeeId = v),
          ),
          const SizedBox(height: 16),
          _label(AppLocaleKeys.osAdvancesAmount.tr),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: osDialogFieldDecoration(
              context,
              hint: '0',
              suffixText: currency,
            ),
          ),
          const SizedBox(height: 24),
          OsFormDialogActions(
            saveLabel: AppLocaleKeys.osAdvancesSave.tr,
            saveColor: AppColors.primary,
            saving: _saving,
            onSave: _save,
            onCancel: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
