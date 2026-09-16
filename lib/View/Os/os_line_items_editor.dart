import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Models/Os/OsServiceModel.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Invoices/os_invoice_share.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:uuid/uuid.dart';

/// Mutable draft row for the shared OS line-items editor.
class OsLineDraft {
  OsLineDraft({
    required this.id,
    required this.description,
    required this.qtyCtrl,
    required this.priceCtrl,
    this.serviceId,
    this.serviceMarketingDescription,
  });

  factory OsLineDraft.empty() => OsLineDraft(
        id: const Uuid().v4(),
        description: TextEditingController(),
        qtyCtrl: TextEditingController(text: '1'),
        priceCtrl: TextEditingController(text: '0'),
      );

  factory OsLineDraft.fromItem(OsLineItem item) => OsLineDraft(
        id: item.id.isEmpty ? const Uuid().v4() : item.id,
        description: TextEditingController(text: item.description),
        qtyCtrl: TextEditingController(text: item.quantity.toString()),
        priceCtrl: TextEditingController(text: item.unitPrice.toString()),
        serviceId: item.serviceId,
        serviceMarketingDescription: item.serviceMarketingDescription,
      );

  final String id;
  final TextEditingController description;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  String? serviceId;
  String? serviceMarketingDescription;

  double get quantity => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(priceCtrl.text.trim()) ?? 0;
  double get lineTotal => quantity * unitPrice;

  void dispose() {
    description.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

/// Controller for shared invoice/quotation line editing (tax + rows).
class OsLineItemsController extends ChangeNotifier {
  OsLineItemsController({
    List<OsLineItem>? initialItems,
    double initialTaxRate = 0,
  }) : _taxRate = initialTaxRate {
    if (initialItems != null && initialItems.isNotEmpty) {
      _lines = initialItems.map(OsLineDraft.fromItem).toList();
    } else {
      _lines = [OsLineDraft.empty()];
    }
  }

  late List<OsLineDraft> _lines;
  double _taxRate;

  List<OsLineDraft> get lines => _lines;
  double get taxRate => _taxRate;

  double get subtotal =>
      _lines.fold<double>(0, (sum, l) => sum + l.lineTotal);
  double get vat => (subtotal * _taxRate).roundToDouble();
  double get total => subtotal + vat;

  set taxRate(double value) {
    _taxRate = value;
    notifyListeners();
  }

  void addEmptyLine() {
    _lines.add(OsLineDraft.empty());
    notifyListeners();
  }

  void removeLine(int index) {
    if (_lines.length <= 1) return;
    _lines[index].dispose();
    _lines.removeAt(index);
    notifyListeners();
  }

  void applyService(OsServiceModel srv) {
    final marketing = srv.marketingDescription?.trim();
    final last = _lines.last;
    final blank =
        last.description.text.trim().isEmpty && last.unitPrice == 0;
    if (_lines.length == 1 && blank) {
      last.description.text = srv.name;
      last.priceCtrl.text = srv.basePrice.toStringAsFixed(0);
      last.serviceId = srv.id;
      last.serviceMarketingDescription = marketing;
    } else {
      _lines.add(
        OsLineDraft(
          id: const Uuid().v4(),
          description: TextEditingController(text: srv.name),
          qtyCtrl: TextEditingController(text: '1'),
          priceCtrl:
              TextEditingController(text: srv.basePrice.toStringAsFixed(0)),
          serviceId: srv.id,
          serviceMarketingDescription: marketing,
        ),
      );
    }
    notifyListeners();
  }

  String? _marketingForDraft(OsLineDraft line) {
    final snap = line.serviceMarketingDescription?.trim();
    if (snap != null && snap.isNotEmpty) return snap;
    final sid = line.serviceId?.trim();
    if (sid == null || sid.isEmpty || !Get.isRegistered<OsFinanceController>()) {
      return null;
    }
    final svc = Get.find<OsFinanceController>().serviceById(sid);
    final marketing = svc?.marketingDescription?.trim();
    if (marketing == null || marketing.isEmpty) return null;
    return marketing;
  }

  void onLineChanged() => notifyListeners();

  /// Builds validated items, or null if invalid / empty.
  List<OsLineItem>? buildItems() {
    final items = <OsLineItem>[];
    for (final l in _lines) {
      final desc = l.description.text.trim();
      if (desc.isEmpty && l.lineTotal == 0) continue;
      if (desc.isEmpty || l.quantity <= 0) return null;
      items.add(
        OsLineItem(
          id: l.id,
          description: desc,
          quantity: l.quantity,
          unitPrice: l.unitPrice,
          total: l.lineTotal,
          serviceId: l.serviceId,
          serviceMarketingDescription: _marketingForDraft(l),
        ),
      );
    }
    if (items.isEmpty) return null;
    return items;
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }
}

/// Shared line-items editor used by invoice and quotation forms.
class OsLineItemsEditor extends StatelessWidget {
  const OsLineItemsEditor({
    super.key,
    required this.controller,
    this.compact = false,
    this.titleKey,
  });

  final OsLineItemsController controller;

  /// Mobile-friendly stacked layout when true.
  final bool compact;

  /// Section title translation key. Defaults to invoice items label.
  final String? titleKey;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              final services = Get.isRegistered<OsFinanceController>()
                  ? Get.find<OsFinanceController>().services.toList()
                  : const <OsServiceModel>[];
              if (services.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.accentText.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.accentText.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            for (final srv in services)
                              ActionChip(
                                avatar: const Icon(Icons.add, size: 16),
                                label: Text(
                                  '${srv.name} (${OsFinanceFormat.money(srv.basePrice)})',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () => controller.applyService(srv),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              );
            }),
            Row(
              children: [
                Text(
                  (titleKey ?? AppLocaleKeys.osInvoicesItems).tr,
                  style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(width: 8),
                if (compact)
                  Text(
                    osInvoiceItemsCountLabel(controller.lines.length),
                    style: TextStyle(fontSize: 12, color: theme.accentText),
                  )
                else
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      osInvoiceItemsCountLabel(controller.lines.length),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < controller.lines.length; i++) ...[
              if (compact)
                _CompactLineRow(
                  controller: controller,
                  index: i,
                )
              else
                _DesktopLineRow(
                  controller: controller,
                  index: i,
                ),
              SizedBox(height: compact ? 12 : 12),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: controller.addEmptyLine,
                icon: Icon(Icons.add, size: compact ? 24 : 20),
                label: Text(AppLocaleKeys.osInvoicesAddItem.tr),
              ),
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
              selected: {controller.taxRate},
              onSelectionChanged: (s) => controller.taxRate = s.first,
            ),
            const SizedBox(height: 16),
            if (compact) ...[
              Text(
                '${AppLocaleKeys.osInvoicesAmount.tr}: ${OsFinanceFormat.money(controller.subtotal)}',
              ),
              Text(
                '${AppLocaleKeys.osInvoicesVat.tr}: ${OsFinanceFormat.money(controller.vat)}',
              ),
              Text(
                '${AppLocaleKeys.osInvoicesTotal.tr}: ${OsFinanceFormat.money(controller.total)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: theme.accentText,
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.panelTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppLocaleKeys.osInvoicesAmount.tr}: ${OsFinanceFormat.money(controller.subtotal)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppLocaleKeys.osInvoicesVat.tr}: ${OsFinanceFormat.money(controller.vat)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppLocaleKeys.osInvoicesTotal.tr}: ${OsFinanceFormat.money(controller.total)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.accentText,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DesktopLineRow extends StatelessWidget {
  const _DesktopLineRow({
    required this.controller,
    required this.index,
  });

  final OsLineItemsController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final line = controller.lines[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: TextField(
            controller: line.description,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesItemDesc.tr,
            ),
            onChanged: (_) => controller.onLineChanged(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: line.qtyCtrl,
            keyboardType: TextInputType.number,
            decoration:
                osFinanceFieldDecoration(AppLocaleKeys.osInvoicesQty.tr),
            onChanged: (_) => controller.onLineChanged(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: line.priceCtrl,
            keyboardType: TextInputType.number,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osInvoicesUnitPrice.tr,
            ),
            onChanged: (_) => controller.onLineChanged(),
          ),
        ),
        IconButton(
          onPressed: controller.lines.length <= 1
              ? null
              : () => controller.removeLine(index),
          icon: const Icon(Icons.delete_outline, size: 22),
        ),
      ],
    );
  }
}

class _CompactLineRow extends StatelessWidget {
  const _CompactLineRow({
    required this.controller,
    required this.index,
  });

  final OsLineItemsController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final line = controller.lines[index];
    return Column(
      children: [
        TextField(
          controller: line.description,
          decoration: osFinanceFieldDecoration(
            AppLocaleKeys.osInvoicesItemDesc.tr,
          ),
          onChanged: (_) => controller.onLineChanged(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: line.qtyCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    osFinanceFieldDecoration(AppLocaleKeys.osInvoicesQty.tr),
                onChanged: (_) => controller.onLineChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: line.priceCtrl,
                keyboardType: TextInputType.number,
                decoration: osFinanceFieldDecoration(
                  AppLocaleKeys.osInvoicesUnitPrice.tr,
                ),
                onChanged: (_) => controller.onLineChanged(),
              ),
            ),
            IconButton(
              onPressed: controller.lines.length <= 1
                  ? null
                  : () => controller.removeLine(index),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ],
    );
  }
}
