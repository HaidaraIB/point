import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/Os/OsEmployeeContractModel.dart';
import 'package:point/Models/Os/os_payroll_enums.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

Future<void> showOsContractFormDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _OsContractFormDialog(),
  );
}

class _OsContractFormDialog extends StatefulWidget {
  const _OsContractFormDialog();

  @override
  State<_OsContractFormDialog> createState() => _OsContractFormDialogState();
}

class _OsContractFormDialogState extends State<_OsContractFormDialog> {
  late final TextEditingController _typeCtrl;
  late String? _employeeId;
  late String _endDate;
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
    _typeCtrl = TextEditingController(
      text: AppLocaleKeys.osContractsTypeHint.tr,
    );
    final emps = _emps;
    _employeeId = emps.isEmpty ? null : emps.first.id;
    final now = DateTime.now();
    _endDate = FirestoreOsFinanceApi.formatDate(
      DateTime(now.year + 1, now.month, now.day),
    );
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
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

  Future<void> _pickEndDate() async {
    final initial = DateTime.tryParse(_endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _endDate = FirestoreOsFinanceApi.formatDate(picked));
  }

  Future<void> _save() async {
    final payroll = Get.find<OsPayrollController>();
    final empId = _employeeId;
    if (empId == null || empId.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osContractsDialogTitle.tr,
        AppLocaleKeys.osContractsErrorEmployee.tr,
      );
      return;
    }
    final type = _typeCtrl.text.trim();
    if (type.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osContractsDialogTitle.tr,
        AppLocaleKeys.osContractsErrorType.tr,
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

    setState(() => _saving = true);
    try {
      final ok = await payroll.saveContract(
        OsEmployeeContractModel(
          employeeId: empId,
          employeeName: emp.name ?? '',
          type: type,
          startDate: FirestoreOsFinanceApi.formatDate(DateTime.now()),
          endDate: _endDate,
          status: OsEmployeeContractStatus.active,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          OsSnackbar.success(
            AppLocaleKeys.osContractsTitle.tr,
            AppLocaleKeys.osContractsSaved.tr,
          );
        });
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osContractsTitle.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final emps = _emps;

    return OsDialogFrame(
      title: AppLocaleKeys.osContractsDialogTitle.tr,
      icon: Icons.description_outlined,
      closeEnabled: !_saving,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(AppLocaleKeys.osContractsEmployee.tr),
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
          _label(AppLocaleKeys.osContractsType.tr),
          TextField(
            controller: _typeCtrl,
            decoration: osDialogFieldDecoration(
              context,
              hint: AppLocaleKeys.osContractsTypeHint.tr,
            ),
          ),
          const SizedBox(height: 16),
          _label(AppLocaleKeys.osContractsEnd.tr),
          InkWell(
            onTap: _pickEndDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: osDialogFieldDecoration(
                context,
                prefixIcon: Icon(
                  Icons.event_outlined,
                  size: 20,
                  color: theme.mutedText,
                ),
              ),
              child: Text(
                _endDate,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 24),
          OsFormDialogActions(
            saveLabel: AppLocaleKeys.osContractsSave.tr,
            saving: _saving,
            onSave: _save,
            onCancel: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
