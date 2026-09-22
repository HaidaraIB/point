import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/os_voucher_balance.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/os_whatsapp_field_values.dart';
import 'package:point/Utils/whatsapp_phone.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/whatsapp_phone_field.dart';

OsVoucherModel? findOsTransferPairVoucher(
  OsVoucherModel voucher,
  List<OsVoucherModel> all,
) {
  if (voucher.source?.trim() != OsVoucherSource.transfer) return null;
  final oppositeType = voucher.type == OsVoucherType.payment
      ? OsVoucherType.receipt
      : OsVoucherType.payment;
  final matches = all
      .where(
        (o) =>
            o.id != voucher.id &&
            o.source?.trim() == OsVoucherSource.transfer &&
            o.date == voucher.date &&
            o.amount == voucher.amount &&
            o.type == oppositeType,
      )
      .toList();
  if (matches.length != 1) return null;
  return matches.first;
}

Future<void> showOsVoucherEditDialog(
  BuildContext context, {
  required OsVoucherModel voucher,
}) async {
  final finance = Get.find<OsFinanceController>();
  final source = voucher.source?.trim() ?? '';

  if (source == OsVoucherSource.transfer) {
    final pair = findOsTransferPairVoucher(voucher, finance.vouchers.toList());
    if (pair == null) {
      OsSnackbar.error(
        AppLocaleKeys.osFinanceVouchers.tr,
        AppLocaleKeys.osVouchersErrorTransferAmbiguous.tr,
      );
      return;
    }
    await _showTransferEditDialog(context, voucher: voucher, pair: pair);
    return;
  }

  final linkedInvoice = osWhatsappInvoiceForVoucher(
    voucher,
    finance.invoices.toList(),
  );
  final linkedClient = linkedInvoice != null
      ? osInvoiceClient(linkedInvoice)
      : null;
  var payeePhone = osVoucherResolvedPayeePhone(
    voucher,
    linkedInvoice: linkedInvoice,
    client: linkedClient,
  );
  final payeeCtrl = TextEditingController(text: voucher.payeeOrPayer);
  final descCtrl = TextEditingController(
    text: OsFinanceFormat.displayDescription(voucher.description),
  );
  final amountCtrl = TextEditingController(
    text: voucher.amount == voucher.amount.roundToDouble()
        ? voucher.amount.toStringAsFixed(0)
        : voucher.amount.toString(),
  );
  var type = voucher.type;
  String? accountId = voucher.bankAccountId;
  var date = OsFinanceFormat.parseYmd(voucher.date) ?? DateTime.now();
  final typeLocked = !osVoucherTypeChangeAllowed(voucher);
  final showPayrollWarning = source == OsVoucherSource.payroll;

  final saved = await showOsFormDialog(
    context: context,
    title: AppLocaleKeys.osVouchersEditTitle.tr,
    titleIcon: Icons.edit_outlined,
    saveLabel: AppLocaleKeys.osCommonSave.tr,
    builder: (context, setLocal) {
      final payeeLabel = type == OsVoucherType.payment
          ? AppLocaleKeys.osVouchersPayeePayment.tr
          : AppLocaleKeys.osVouchersPayeeReceipt.tr;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showPayrollWarning) ...[
            Text(
              AppLocaleKeys.osVouchersPayrollEditWarning.tr,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: context.appTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            key: ValueKey(type),
            initialValue: type,
            isExpanded: true,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osVouchersType.tr,
            ),
            items: [
              DropdownMenuItem(
                value: OsVoucherType.receipt,
                child: Text(AppLocaleKeys.osVouchersTypeReceiptFull.tr),
              ),
              DropdownMenuItem(
                value: OsVoucherType.payment,
                child: Text(AppLocaleKeys.osVouchersTypePaymentFull.tr),
              ),
            ],
            onChanged: typeLocked
                ? null
                : (v) {
                    if (v != null) setLocal(() => type = v);
                  },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey(accountId),
            initialValue: accountId,
            isExpanded: true,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osVouchersAccount.tr,
            ),
            items: [
              for (final a in finance.bankAccounts)
                DropdownMenuItem(
                  value: a.id,
                  child: Text(a.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setLocal(() => accountId = v),
          ),
          const SizedBox(height: 14),
          osTypedTextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osVouchersAmountLabel.tr,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setLocal(() => date = picked);
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${AppLocaleKeys.osVouchersDate.tr}: ${OsFinanceFormat.ymd(date)}',
              ),
            ),
          ),
          const SizedBox(height: 14),
          osTypedTextField(
            controller: payeeCtrl,
            decoration: osFinanceFieldDecoration(
              payeeLabel,
              hint: AppLocaleKeys.osVouchersPayeeHint.tr,
            ),
          ),
          const SizedBox(height: 14),
          WhatsappPhoneField(
            key: ValueKey('payee-phone-$payeePhone'),
            initialNormalized:
                payeePhone.trim().isEmpty ? null : payeePhone.trim(),
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osVouchersPayeePhone.tr,
              hint: AppLocaleKeys.osVouchersPayeePhoneHint.tr,
            ),
            onChanged: (v) => payeePhone = v ?? '',
          ),
          const SizedBox(height: 14),
          osTypedTextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osVouchersDescription.tr,
              hint: AppLocaleKeys.osVouchersDescriptionHint.tr,
            ),
          ),
        ],
      );
    },
  );

  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
  final payee = payeeCtrl.text.trim();
  final desc = descCtrl.text.trim();
  final normalizedPhone = normalizeWhatsappPhone(payeePhone.trim());
  payeeCtrl.dispose();
  descCtrl.dispose();
  amountCtrl.dispose();

  if (saved != true) return;
  final resolvedAccountId = accountId?.trim() ?? '';
  if (resolvedAccountId.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osFinanceVouchers.tr,
      AppLocaleKeys.osVouchersErrorAccountRequired.tr,
    );
    return;
  }

  try {
    final ok = await finance.updateVoucher(
      voucher.copyWith(
        type: type,
        amount: amount,
        date: OsFinanceFormat.ymd(date),
        payeeOrPayer: payee,
        payeePhone: normalizedPhone,
        description: desc,
        bankAccountId: resolvedAccountId,
      ),
    );
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osFinanceVouchers.tr,
        AppLocaleKeys.osVouchersUpdated.tr,
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osFinanceVouchers.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
    }
  } on OsFinanceException catch (e) {
    OsSnackbar.error(AppLocaleKeys.osFinanceVouchers.tr, e.messageKey.tr);
  }
}

Future<void> _showTransferEditDialog(
  BuildContext context, {
  required OsVoucherModel voucher,
  required OsVoucherModel pair,
}) async {
  final finance = Get.find<OsFinanceController>();
  final payment = voucher.type == OsVoucherType.payment ? voucher : pair;
  final receipt = voucher.type == OsVoucherType.receipt ? voucher : pair;

  final amountCtrl = TextEditingController(
    text: payment.amount == payment.amount.roundToDouble()
        ? payment.amount.toStringAsFixed(0)
        : payment.amount.toString(),
  );
  final payDescCtrl = TextEditingController(
    text: OsFinanceFormat.displayDescription(payment.description),
  );
  final recDescCtrl = TextEditingController(
    text: OsFinanceFormat.displayDescription(receipt.description),
  );
  String? sourceId = payment.bankAccountId;
  String? destId = receipt.bankAccountId;
  var date = OsFinanceFormat.parseYmd(payment.date) ?? DateTime.now();

  final saved = await showOsFormDialog(
    context: context,
    title: AppLocaleKeys.osVouchersEditTitle.tr,
    titleIcon: Icons.swap_horiz,
    saveLabel: AppLocaleKeys.osCommonSave.tr,
    builder: (context, setLocal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('src-$sourceId'),
            initialValue: sourceId,
            isExpanded: true,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osAccountsTransferSource.tr,
            ),
            items: [
              for (final a in finance.bankAccounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setLocal(() => sourceId = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('dst-$destId'),
            initialValue: destId,
            isExpanded: true,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osAccountsTransferDest.tr,
            ),
            items: [
              for (final a in finance.bankAccounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setLocal(() => destId = v),
          ),
          const SizedBox(height: 14),
          osTypedTextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osAccountsTransferAmount.tr,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setLocal(() => date = picked);
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${AppLocaleKeys.osVouchersDate.tr}: ${OsFinanceFormat.ymd(date)}',
              ),
            ),
          ),
          const SizedBox(height: 14),
          osTypedTextField(
            controller: payDescCtrl,
            maxLines: 2,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osVouchersTransferPaymentDesc.tr,
            ),
          ),
          const SizedBox(height: 14),
          osTypedTextField(
            controller: recDescCtrl,
            maxLines: 2,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osVouchersTransferReceiptDesc.tr,
            ),
          ),
        ],
      );
    },
  );

  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
  final payDesc = payDescCtrl.text.trim();
  final recDesc = recDescCtrl.text.trim();
  amountCtrl.dispose();
  payDescCtrl.dispose();
  recDescCtrl.dispose();

  if (saved != true) return;
  final resolvedSourceId = sourceId?.trim() ?? '';
  final resolvedDestId = destId?.trim() ?? '';
  if (resolvedSourceId.isEmpty || resolvedDestId.isEmpty) return;

  try {
    final ok = await finance.updateVoucher(
      voucher,
      transfer: OsTransferVoucherEdit(
        sourceAccountId: resolvedSourceId,
        destAccountId: resolvedDestId,
        amount: amount,
        date: OsFinanceFormat.ymd(date),
        paymentDescription: payDesc,
        receiptDescription: recDesc,
      ),
    );
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osFinanceVouchers.tr,
        AppLocaleKeys.osVouchersUpdated.tr,
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osFinanceVouchers.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
    }
  } on OsFinanceException catch (e) {
    OsSnackbar.error(AppLocaleKeys.osFinanceVouchers.tr, e.messageKey.tr);
  }
}
