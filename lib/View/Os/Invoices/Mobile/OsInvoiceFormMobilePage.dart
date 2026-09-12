import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/os_invoice_service_presets.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_invoice_stamp.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:uuid/uuid.dart';

class OsInvoiceFormMobilePage extends StatefulWidget {
  const OsInvoiceFormMobilePage({super.key, this.existing});

  final OsInvoiceModel? existing;

  @override
  State<OsInvoiceFormMobilePage> createState() =>
      _OsInvoiceFormMobilePageState();
}

class _OsInvoiceFormMobilePageState extends State<OsInvoiceFormMobilePage> {
  late String? _clientId;
  late DateTime _date;
  late DateTime _dueDate;
  late String _status;
  late double _taxRate;
  late String? _bankAccountId;
  late List<_MobileLine> _lines;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _clientId = e?.clientId;
    _date = OsFinanceFormat.parseYmd(e?.date) ?? now;
    _dueDate =
        OsFinanceFormat.parseYmd(e?.dueDate) ?? now.add(const Duration(days: 14));
    _status = e?.status ?? OsInvoiceStatus.sent;
    if (_status == OsInvoiceStatus.paid) _status = OsInvoiceStatus.sent;
    _taxRate = (e != null && e.vat > 0) ? 0.05 : 0;
    _bankAccountId = e?.bankAccountId;
    _lines = (e?.items.isNotEmpty == true)
        ? e!.items
            .map(
              (i) => _MobileLine(
                id: i.id,
                description: TextEditingController(text: i.description),
                qtyCtrl: TextEditingController(text: i.quantity.toString()),
                priceCtrl: TextEditingController(text: i.unitPrice.toString()),
              ),
            )
            .toList()
        : [_MobileLine.empty()];
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _subtotal =>
      _lines.fold<double>(0, (sum, l) => sum + l.lineTotal);
  double get _vat => (_subtotal * _taxRate).roundToDouble();
  double get _total => _subtotal + _vat;

  Future<void> _pickDate({required bool due}) async {
    final initial = due ? _dueDate : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (due) {
        _dueDate = picked;
      } else {
        _date = picked;
      }
    });
  }

  void _applyServicePreset(OsInvoiceServicePreset srv) {
    setState(() {
      final last = _lines.last;
      final blank = last.description.text.trim().isEmpty && last.unitPrice == 0;
      if (_lines.length == 1 && blank) {
        last.description.text = srv.name;
        last.priceCtrl.text = srv.basePrice.toStringAsFixed(0);
      } else {
        _lines.add(
          _MobileLine(
            id: const Uuid().v4(),
            description: TextEditingController(text: srv.name),
            qtyCtrl: TextEditingController(text: '1'),
            priceCtrl:
                TextEditingController(text: srv.basePrice.toStringAsFixed(0)),
          ),
        );
      }
    });
  }

  Future<void> _save() async {
    final clients = Get.find<HomeController>().clients;
    ClientModel? client;
    for (final c in clients) {
      if (c.id == _clientId) {
        client = c;
        break;
      }
    }
    if (client?.id == null) {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesErrorNoClient.tr,
      );
      return;
    }

    final items = <OsInvoiceItem>[];
    for (final l in _lines) {
      final desc = l.description.text.trim();
      if (desc.isEmpty && l.lineTotal == 0) continue;
      if (desc.isEmpty || l.quantity <= 0) {
        OsSnackbar.error(
          AppLocaleKeys.osInvoicesTitle.tr,
          AppLocaleKeys.osInvoicesErrorNoItems.tr,
        );
        return;
      }
      items.add(
        OsInvoiceItem(
          id: l.id,
          description: desc,
          quantity: l.quantity,
          unitPrice: l.unitPrice,
          total: l.lineTotal,
        ),
      );
    }
    if (items.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesErrorNoItems.tr,
      );
      return;
    }

    setState(() => _saving = true);
    final model = OsInvoiceModel(
      id: widget.existing?.id,
      displayNumber: widget.existing?.displayNumber,
      clientId: client!.id!,
      clientName: client.name?.trim().isNotEmpty == true
          ? client.name!.trim()
          : (client.email ?? client.id!),
      date: OsFinanceFormat.ymd(_date),
      dueDate: OsFinanceFormat.ymd(_dueDate),
      status: _status,
      amount: _subtotal,
      vat: _vat,
      total: _total,
      items: items,
      bankAccountId: _bankAccountId,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    final ok = await Get.find<OsFinanceController>().saveInvoice(model);
    setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osInvoicesSaved.tr,
      );
      Get.back();
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesTitle.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final clients = Get.find<HomeController>().clients;
    final finance = Get.find<OsFinanceController>();
    final stamp = Get.find<OsStampSettingsController>();

    return Scaffold(
      backgroundColor: theme.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          tooltip: AppLocaleKeys.osBackToHub.tr,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Get.back();
            } else {
              Get.offNamed('/os');
            }
          },
        ),
        title: Text(
          widget.existing == null
              ? AppLocaleKeys.osInvoicesAdd.tr
              : AppLocaleKeys.osInvoicesEdit.tr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(_clientId),
            initialValue:
                _clientId != null && clients.any((c) => c.id == _clientId)
                    ? _clientId
                    : null,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesClient.tr,
            ),
            items: [
              for (final c in clients)
                if (c.id != null)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name ?? c.email ?? c.id!),
                  ),
            ],
            onChanged: (v) => setState(() => _clientId = v),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _pickDate(due: false),
            child: Text(
              '${AppLocaleKeys.osInvoicesDate.tr}: ${OsFinanceFormat.ymd(_date)}',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _pickDate(due: true),
            child: Text(
              '${AppLocaleKeys.osInvoicesDueDate.tr}: ${OsFinanceFormat.ymd(_dueDate)}',
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final accounts = finance.bankAccounts.toList();
            return DropdownButtonFormField<String?>(
              key: ValueKey(_bankAccountId),
              initialValue: _bankAccountId != null &&
                      accounts.any((a) => a.id == _bankAccountId)
                  ? _bankAccountId
                  : null,
              decoration: osFinanceFieldDecoration(
                AppLocaleKeys.osInvoicesCollectionAccount.tr,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(AppLocaleKeys.osInvoicesAccountAuto.tr),
                ),
                for (final a in accounts)
                  DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(
                      '${a.name} (${OsFinanceFormat.money(a.balance)})',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _bankAccountId = v),
            );
          }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_status),
            initialValue: OsInvoiceStatus.editable.contains(_status)
                ? _status
                : OsInvoiceStatus.sent,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesStatus.tr,
            ),
            items: [
              for (final s in OsInvoiceStatus.editable)
                DropdownMenuItem(
                  value: s,
                  child: Text(OsFinanceFormat.invoiceStatusLabel(s)),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _status = v);
            },
          ),
          const SizedBox(height: 16),
          Text(
            AppLocaleKeys.osInvoicesServiceChips.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.accentText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final srv in osInvoiceServicePresets)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(
                    '${srv.name} (${OsFinanceFormat.money(srv.basePrice)})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _applyServicePreset(srv),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                AppLocaleKeys.osInvoicesItems.tr,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                osInvoiceItemsCountLabel(_lines.length),
                style: TextStyle(fontSize: 12, color: theme.accentText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _lines.length; i++) ...[
            TextField(
              controller: _lines[i].description,
              decoration: osFinanceFieldDecoration(
                AppLocaleKeys.osInvoicesItemDesc.tr,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lines[i].qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: osFinanceFieldDecoration(
                      AppLocaleKeys.osInvoicesQty.tr,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lines[i].priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: osFinanceFieldDecoration(
                      AppLocaleKeys.osInvoicesUnitPrice.tr,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  onPressed: _lines.length <= 1
                      ? null
                      : () {
                          setState(() {
                            _lines[i].dispose();
                            _lines.removeAt(i);
                          });
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextButton.icon(
            onPressed: () => setState(() => _lines.add(_MobileLine.empty())),
            icon: const Icon(Icons.add),
            label: Text(AppLocaleKeys.osInvoicesAddItem.tr),
          ),
          const SizedBox(height: 12),
          SegmentedButton<double>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(AppLocaleKeys.osInvoicesTaxExempt.tr),
              ),
              ButtonSegment(
                value: 0.05,
                label: Text(AppLocaleKeys.osInvoicesTaxStamp.tr),
              ),
            ],
            selected: {_taxRate},
            onSelectionChanged: (s) => setState(() => _taxRate = s.first),
          ),
          const SizedBox(height: 16),
          Text(
            '${AppLocaleKeys.osInvoicesAmount.tr}: ${OsFinanceFormat.money(_subtotal)}',
          ),
          Text(
            '${AppLocaleKeys.osInvoicesVat.tr}: ${OsFinanceFormat.money(_vat)}',
          ),
          Text(
            '${AppLocaleKeys.osInvoicesTotal.tr}: ${OsFinanceFormat.money(_total)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: theme.accentText,
            ),
          ),
          Obx(() {
            if (!stamp.stampEnabled.value) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  Text(
                    AppLocaleKeys.osInvoicesStampPreview.tr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: theme.accentText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const OsInvoiceStamp(compact: true),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(AppLocaleKeys.osInvoicesSaveFull.tr),
          ),
        ],
      ),
    );
  }
}

class _MobileLine {
  _MobileLine({
    required this.id,
    required this.description,
    required this.qtyCtrl,
    required this.priceCtrl,
  });

  factory _MobileLine.empty() => _MobileLine(
        id: const Uuid().v4(),
        description: TextEditingController(),
        qtyCtrl: TextEditingController(text: '1'),
        priceCtrl: TextEditingController(text: '0'),
      );

  final String id;
  final TextEditingController description;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  double get quantity => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(priceCtrl.text.trim()) ?? 0;
  double get lineTotal => quantity * unitPrice;

  void dispose() {
    description.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
