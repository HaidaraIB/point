import 'package:flutter/material.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/os_finance_format.dart';

class OsColoredStatusLabel extends StatelessWidget {
  const OsColoredStatusLabel({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.showDot = true,
  });

  final String label;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class OsFinanceStatusBadge extends StatelessWidget {
  const OsFinanceStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 11,
  });

  final String label;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}

List<DropdownMenuItem<String>> osInvoiceStatusDropdownItems([
  Iterable<String>? statuses,
]) {
  final values = statuses ?? OsInvoiceStatus.all;
  return [
    for (final s in values)
      DropdownMenuItem(
        value: s,
        child: OsColoredStatusLabel(
          label: OsFinanceFormat.invoiceStatusLabel(s),
          color: OsFinanceFormat.invoiceStatusColor(s),
        ),
      ),
  ];
}

List<Widget> osInvoiceStatusSelectedItems([
  Iterable<String>? statuses,
]) {
  final values = statuses ?? OsInvoiceStatus.all;
  return [
    for (final s in values)
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OsColoredStatusLabel(
          label: OsFinanceFormat.invoiceStatusLabel(s),
          color: OsFinanceFormat.invoiceStatusColor(s),
        ),
      ),
  ];
}

List<DropdownMenuItem<String>> osQuotationStatusDropdownItems() {
  return [
    for (final s in OsQuotationStatus.all)
      DropdownMenuItem(
        value: s,
        child: OsColoredStatusLabel(
          label: OsFinanceFormat.quotationStatusLabel(s),
          color: OsFinanceFormat.quotationStatusColor(s),
        ),
      ),
  ];
}

List<DropdownMenuItem<String>> osLegalContractStatusDropdownItems() {
  return [
    for (final s in OsLegalContractStatus.filterOrdered)
      DropdownMenuItem(
        value: s,
        child: OsColoredStatusLabel(
          label: osLegalContractStatusLabel(s),
          color: osLegalContractStatusColor(s),
        ),
      ),
  ];
}

List<Widget> osLegalContractStatusSelectedItems() {
  return [
    for (final s in OsLegalContractStatus.filterOrdered)
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OsColoredStatusLabel(
          label: osLegalContractStatusLabel(s),
          color: osLegalContractStatusColor(s),
          fontSize: 12,
        ),
      ),
  ];
}
