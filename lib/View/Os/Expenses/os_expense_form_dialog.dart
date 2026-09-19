import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsDailyExpenseModel.dart';
import 'package:point/Models/Os/os_expense_constants.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Expenses/os_expense_camera.dart';
import 'package:point/View/Os/Expenses/os_expense_receipt_upload.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Mobile/Shared/VideoCart.dart';
import 'package:point/View/Shared/safe_network_image.dart';

Future<void> showOsExpenseFormDialog(
  BuildContext context, {
  OsDailyExpenseModel? existing,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OsExpenseFormDialog(existing: existing),
  );
}

class _OsExpenseFormDialog extends StatefulWidget {
  const _OsExpenseFormDialog({this.existing});

  final OsDailyExpenseModel? existing;

  @override
  State<_OsExpenseFormDialog> createState() => _OsExpenseFormDialogState();
}

class _OsExpenseFormDialogState extends State<_OsExpenseFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _vendorCtrl;
  late final TextEditingController _receiptNoCtrl;
  late final TextEditingController _notesCtrl;

  late String _category;
  late String _paymentMethod;
  late String? _bankAccountId;
  late String _branchId;
  late String _paidBy;
  late String _date;
  late String _time;
  String? _receiptUrl;
  Uint8List? _pendingBytes;
  var _saving = false;

  final _moneyFmt = NumberFormat('#,##0', 'en_US');
  late final List<String> _paidByOptions;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final finance = Get.find<OsFinanceController>();
    final home = Get.find<HomeController>();
    final now = DateTime.now();

    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _amountCtrl = TextEditingController(
      text: existing != null && existing.amount > 0
          ? existing.amount.toStringAsFixed(0)
          : '',
    );
    _vendorCtrl = TextEditingController(text: existing?.vendor ?? '');
    _receiptNoCtrl =
        TextEditingController(text: existing?.receiptNumber ?? '');
    _notesCtrl = TextEditingController(text: existing?.notes ?? '');

    _category = existing?.category ?? OsExpenseCategories.all.first;
    _paymentMethod =
        existing?.paymentMethod ?? OsExpensePaymentMethod.cash;
    _bankAccountId = existing?.bankAccountId ??
        (finance.bankAccounts.isNotEmpty ? finance.bankAccounts.first.id : null);
    _branchId = existing?.branchId ?? finance.defaultBranchId ?? '';
    _paidBy = existing?.paidBy ??
        (home.employees.isNotEmpty
            ? (home.employees.first.name?.trim() ?? '')
            : OsExpensePaidByExtras.accountant);
    if (_paidBy.isEmpty) _paidBy = OsExpensePaidByExtras.accountant;
    _date = existing?.date ?? FirestoreOsFinanceApi.formatDate(now);
    _time = existing?.time ??
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _receiptUrl = existing?.receiptImageUrl;

    _paidByOptions = [
      ...home.employees
          .map((e) => e.name?.trim() ?? '')
          .where((n) => n.isNotEmpty),
      ...OsExpensePaidByExtras.all,
    ];
    if (!_paidByOptions.contains(_paidBy)) {
      _paidByOptions.insert(0, _paidBy);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _vendorCtrl.dispose();
    _receiptNoCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint, Widget? suffix}) {
    final theme = context.appTheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: theme.inputFill,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _responsiveRow({
    required bool narrow,
    required List<Widget> children,
  }) {
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    );
  }

  Future<void> _pickGallery() async {
    final file = await OsExpenseReceiptUpload.pick(
      source: ImageSource.gallery,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pendingBytes = bytes;
      _receiptUrl = null;
    });
  }

  Future<void> _pickCamera() async {
    final bytes = await captureOsExpenseCamera(context);
    if (bytes == null || !mounted) return;
    setState(() {
      _pendingBytes = bytes;
      _receiptUrl = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (title.isEmpty || amount <= 0) {
      OsSnackbar.error(
        AppLocaleKeys.osExpensesTitle.tr,
        AppLocaleKeys.osExpensesErrorTitleAmount.tr,
      );
      return;
    }

    setState(() => _saving = true);
    final finance = Get.find<OsFinanceController>();
    try {
      final id = widget.existing?.id ?? FirestoreOsFinanceApi.newId();
      var imageUrl = _receiptUrl;
      if (_pendingBytes != null) {
        imageUrl = await OsExpenseReceiptUpload.upload(
          expenseId: id,
          bytes: _pendingBytes!,
        );
        if (imageUrl == null) {
          if (!mounted) return;
          OsSnackbar.error(
            AppLocaleKeys.osExpensesTitle.tr,
            AppLocaleKeys.osExpensesReceiptUploadFailed.tr,
          );
          return;
        }
      }

      final model = OsDailyExpenseModel(
        id: id,
        title: title,
        amount: amount,
        category: _category,
        date: _date,
        time: _time,
        paymentMethod: _paymentMethod,
        bankAccountId: _bankAccountId,
        branchId: _branchId,
        paidBy: _paidBy,
        vendor: _vendorCtrl.text.trim().isEmpty
            ? null
            : _vendorCtrl.text.trim(),
        receiptNumber: _receiptNoCtrl.text.trim().isEmpty
            ? null
            : _receiptNoCtrl.text.trim(),
        receiptImageUrl: imageUrl,
        notes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        status: OsExpenseStatus.approved,
        voucherId: widget.existing?.voucherId,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      final ok = _isEdit
          ? await finance.updateExpense(model)
          : await finance.createExpense(model);
      if (!mounted) return;
      if (ok) {
        OsSnackbar.success(
          AppLocaleKeys.osExpensesTitle.tr,
          AppLocaleKeys.osExpensesSaved.tr,
        );
        Navigator.pop(context);
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osExpensesTitle.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
      }
    } on OsFinanceException catch (e) {
      OsSnackbar.error(
        AppLocaleKeys.osExpensesTitle.tr,
        e.messageKey.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dashedBox({
    required Color borderColor,
    required Color bg,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    required String hint,
    required VoidCallback onTap,
  }) {
    final theme = context.appTheme;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: borderColor, radius: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconFg, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: theme.mutedText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final finance = Get.find<OsFinanceController>();
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final currency = AppLocaleKeys.osInvoicesCurrency.tr;
    final hasReceipt =
        _pendingBytes != null || (_receiptUrl != null && _receiptUrl!.isNotEmpty);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 28,
        vertical: 20,
      ),
      backgroundColor: theme.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit
                              ? AppLocaleKeys.osExpensesEdit.tr
                              : AppLocaleKeys.osExpensesAdd.tr,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: theme.primaryText,
                          ),
                        ),
                        Text(
                          AppLocaleKeys.osExpensesFormSubtitle.tr,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.mutedText),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: AppLocaleKeys.osExpensesAmountIqd.tr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryText,
                        ),
                        children: const [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: Color(0xFFF43F5E)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    osTypedTextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: theme.primaryText,
                      ),
                      decoration: _dec(
                        '',
                        hint: AppLocaleKeys.osExpensesAmountHint.tr,
                        suffix: Padding(
                          padding: const EdgeInsets.only(right: 12, top: 14),
                          child: Text(
                            currency,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: theme.mutedText,
                            ),
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          AppLocaleKeys.osExpensesQuickAdd.tr,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.mutedText,
                          ),
                        ),
                        for (final v in const [
                          5000,
                          10000,
                          25000,
                          50000,
                          100000,
                        ])
                          ActionChip(
                            label: Text('+${_moneyFmt.format(v)}'),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryText,
                            ),
                            backgroundColor: theme.inputFill,
                            side: BorderSide(color: theme.border),
                            onPressed: () {
                              final cur =
                                  double.tryParse(_amountCtrl.text.trim()) ??
                                      0;
                              _amountCtrl.text =
                                  (cur + v).toStringAsFixed(0);
                              setState(() {});
                            },
                          ),
                        ActionChip(
                          label: Text(AppLocaleKeys.osExpensesQuickClear.tr),
                          labelStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF43F5E),
                          ),
                          backgroundColor:
                              const Color(0xFFF43F5E).withValues(alpha: 0.12),
                          side: BorderSide.none,
                          onPressed: () {
                            _amountCtrl.clear();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        text: AppLocaleKeys.osExpensesTitleField.tr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryText,
                        ),
                        children: const [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: Color(0xFFF43F5E)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    osTypedTextField(
                      controller: _titleCtrl,
                      decoration: _dec(
                        '',
                        hint: AppLocaleKeys.osExpensesTitleHint.tr,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _responsiveRow(
                      narrow: narrow,
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(_category),
                          initialValue: _category,
                          isExpanded: true,
                          decoration: _dec(
                            AppLocaleKeys.osExpensesCategory.tr,
                          ),
                          items: [
                            for (final c in OsExpenseCategories.all)
                              DropdownMenuItem(
                                value: c,
                                child: Text(c.tr, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _category = v);
                          },
                        ),
                        osTypedTextField(
                          controller: _vendorCtrl,
                          decoration: _dec(
                            AppLocaleKeys.osExpensesVendor.tr,
                            hint: AppLocaleKeys.osExpensesVendorHint.tr,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _responsiveRow(
                      narrow: narrow,
                      children: [
                        osTypedTextField(
                          controller: _receiptNoCtrl,
                          decoration: _dec(
                            AppLocaleKeys.osExpensesReceiptNumber.tr,
                            hint: AppLocaleKeys.osExpensesReceiptHint.tr,
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.tryParse(_date) ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (picked == null) return;
                            setState(() {
                              _date =
                                  FirestoreOsFinanceApi.formatDate(picked);
                            });
                          },
                          child: InputDecorator(
                            decoration: _dec(
                              AppLocaleKeys.osExpensesDate.tr,
                              suffix: const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                              ),
                            ),
                            child: Text(_date),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            final parts = _time.split(':');
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: int.tryParse(parts.first) ?? 12,
                                minute: parts.length > 1
                                    ? (int.tryParse(parts[1]) ?? 0)
                                    : 0,
                              ),
                            );
                            if (picked == null) return;
                            setState(() {
                              _time =
                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                            });
                          },
                          child: InputDecorator(
                            decoration: _dec(
                              AppLocaleKeys.osExpensesTime.tr,
                              suffix: const Icon(
                                Icons.schedule_outlined,
                                size: 16,
                              ),
                            ),
                            child: Text(_time),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _responsiveRow(
                      narrow: narrow,
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(_paymentMethod),
                          initialValue: _paymentMethod,
                          isExpanded: true,
                          decoration: _dec(
                            AppLocaleKeys.osExpensesPaymentMethod.tr,
                          ),
                          items: [
                            for (final m in OsExpensePaymentMethod.all)
                              DropdownMenuItem(
                                value: m,
                                child: Text(
                                  OsExpensePaymentMethod.labelKey(m).tr,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _paymentMethod = v);
                          },
                        ),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_paidBy),
                          initialValue: _paidByOptions.contains(_paidBy)
                              ? _paidBy
                              : _paidByOptions.first,
                          isExpanded: true,
                          decoration: _dec(
                            AppLocaleKeys.osExpensesPaidByLabel.tr,
                          ),
                          items: [
                            for (final p in _paidByOptions)
                              DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p.startsWith('os.') ? p.tr : p,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _paidBy = v);
                          },
                        ),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_branchId),
                          initialValue: _branchId.isEmpty
                              ? null
                              : _branchId,
                          isExpanded: true,
                          decoration: _dec(
                            AppLocaleKeys.osExpensesBranchLinked.tr,
                          ),
                          items: [
                            for (final b in finance.branches)
                              if (b.id != null && b.id!.isNotEmpty)
                                DropdownMenuItem(
                                  value: b.id,
                                  child: Text(
                                    b.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            if (_branchId.isNotEmpty &&
                                finance.branchById(_branchId) == null)
                              DropdownMenuItem(
                                value: _branchId,
                                child: Text(
                                  _branchId,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _branchId = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(height: 1, color: theme.border),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 16,
                          color: theme.accentText,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            AppLocaleKeys.osExpensesReceiptRequired.tr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                        if (hasReceipt)
                          Text(
                            AppLocaleKeys.osExpensesReceiptSaved.tr,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (hasReceipt)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.inputFill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _pendingBytes != null
                                  ? Image.memory(
                                      _pendingBytes!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    )
                                  : InkWell(
                                      onTap: () {
                                        final url = _receiptUrl?.trim();
                                        if (url == null || url.isEmpty) {
                                          return;
                                        }
                                        Get.to(
                                          () => ImagePreviewPage(url: url),
                                        );
                                      },
                                      child: SafeNetworkImage(
                                        _receiptUrl!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocaleKeys.osExpensesReceiptStored.tr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: theme.primaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppLocaleKeys
                                        .osExpensesReceiptStoredHint.tr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.mutedText,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _pickCamera,
                                        icon: const Icon(
                                          Icons.camera_alt_outlined,
                                          size: 14,
                                        ),
                                        label: Text(
                                          AppLocaleKeys
                                              .osExpensesReceiptRetake.tr,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => setState(() {
                                          _pendingBytes = null;
                                          _receiptUrl = null;
                                        }),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 14,
                                          color: Color(0xFFF43F5E),
                                        ),
                                        label: Text(
                                          AppLocaleKeys
                                              .osExpensesReceiptRemove.tr,
                                          style: const TextStyle(
                                            color: Color(0xFFF43F5E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _responsiveRow(
                        narrow: narrow,
                        children: [
                          _dashedBox(
                            borderColor:
                                AppColors.primary.withValues(alpha: 0.7),
                            bg: AppColors.primary.withValues(alpha: 0.08),
                            icon: Icons.camera_alt,
                            iconBg: AppColors.primary,
                            iconFg: Colors.white,
                            title: AppLocaleKeys.osExpensesCameraCapture.tr,
                            hint: AppLocaleKeys.osExpensesCameraHint.tr,
                            onTap: _pickCamera,
                          ),
                          _dashedBox(
                            borderColor: theme.border,
                            bg: theme.inputFill.withValues(alpha: 0.5),
                            icon: Icons.image_outlined,
                            iconBg: theme.unselected,
                            iconFg: theme.primaryText,
                            title: AppLocaleKeys.osExpensesGalleryUpload.tr,
                            hint: AppLocaleKeys.osExpensesGalleryHint.tr,
                            onTap: _pickGallery,
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    osTypedTextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: _dec(
                        AppLocaleKeys.osExpensesNotes.tr,
                        hint: AppLocaleKeys.osExpensesNotesHint.tr,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: theme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primaryText,
                      side: BorderSide(color: theme.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocaleKeys.osCommonCancel.tr),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(AppLocaleKeys.osExpensesSaveFull.tr),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
