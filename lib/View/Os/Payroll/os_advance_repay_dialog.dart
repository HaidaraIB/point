import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsEmployeeAdvanceModel.dart';
import 'package:point/Services/firestore/firestore_os_payroll_api.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

Future<void> showOsAdvanceRepayDialog(
  BuildContext context,
  OsEmployeeAdvanceModel advance,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OsAdvanceRepayDialog(advance: advance),
  );
}

class _OsAdvanceRepayDialog extends StatefulWidget {
  const _OsAdvanceRepayDialog({required this.advance});

  final OsEmployeeAdvanceModel advance;

  @override
  State<_OsAdvanceRepayDialog> createState() => _OsAdvanceRepayDialogState();
}

class _OsAdvanceRepayDialogState extends State<_OsAdvanceRepayDialog> {
  final _amountCtrl = TextEditingController();
  var _saving = false;

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
    final id = widget.advance.id;
    if (id == null) return;
    final amount = double.tryParse(
          _amountCtrl.text.trim().replaceAll(',', ''),
        ) ??
        0;
    final remaining = widget.advance.remainingAmount;
    if (amount <= 0 || amount > remaining) {
      OsSnackbar.error(
        AppLocaleKeys.osAdvancesRepayDialogTitle.tr,
        AppLocaleKeys.osAdvancesErrorRepayAmount.tr,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ok = await Get.find<OsPayrollController>().repayAdvance(
        advanceId: id,
        amount: amount,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          OsSnackbar.success(
            AppLocaleKeys.osAdvancesTitle.tr,
            AppLocaleKeys.osAdvancesRepaid.tr,
          );
        });
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osAdvancesTitle.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
      }
    } on OsPayrollException catch (e) {
      OsSnackbar.error(AppLocaleKeys.osAdvancesTitle.tr, e.messageKey.tr);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = OsFinanceFormat.money(widget.advance.remainingAmount);

    return OsDialogFrame(
      title: AppLocaleKeys.osAdvancesRepayDialogTitle.tr,
      closeEnabled: !_saving,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(AppLocaleKeys.osAdvancesEmployee.tr),
          Text(
            widget.advance.employeeName,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.appTheme.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          _label(AppLocaleKeys.osAdvancesRemaining.tr),
          Text(
            remaining,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.appTheme.accentText,
            ),
          ),
          const SizedBox(height: 16),
          _label(AppLocaleKeys.osAdvancesRepayAmount.tr),
          osTypedTextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: osDialogFieldDecoration(
              context,
              hint: '0',
              suffixText: AppLocaleKeys.osInvoicesCurrency.tr,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleKeys.osAdvancesRepayHint.trParams({'amount': remaining}),
            style: TextStyle(
              fontSize: 12,
              color: context.appTheme.mutedText,
            ),
          ),
          const SizedBox(height: 24),
          OsFormDialogActions(
            saveLabel: AppLocaleKeys.osAdvancesRepay.tr,
            saving: _saving,
            onSave: _save,
            onCancel: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
