import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsQuotationModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';

class OsFinanceFormat {
  OsFinanceFormat._();

  /// Language-neutral sentinel stored when account number is blank.
  static const unsetAccountNumber = OsBankAccountType.unsetNumber;

  static final _iqd = NumberFormat('#,##0', 'en_US');
  static final _uuidPattern = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );
  static final _voucherNum = RegExp(r'^V-(\d+)$', caseSensitive: false);
  static final _invoiceNum = RegExp(r'^INV-0*(\d+)$', caseSensitive: false);
  static final _quotationNum =
      RegExp(r'^Q-(\d{4})-0*(\d+)$', caseSensitive: false);

  static String money(num value) {
    return '${_iqd.format(value)} ${AppLocaleKeys.osInvoicesCurrency.tr}';
  }

  static String moneyNumber(num value) => _iqd.format(value);

  static String accountNumberLabel(String? number) {
    final n = number?.trim() ?? '';
    if (n.isEmpty || n == unsetAccountNumber) {
      return AppLocaleKeys.osCommonNa.tr;
    }
    return n;
  }

  /// Prefer human `V-101` / `INV-001`; never show raw UUIDs.
  static String voucherRef(OsVoucherModel v) {
    final display = v.displayNumber?.trim();
    if (display != null && display.isNotEmpty) return display;
    return shortRef(v.id);
  }

  static String invoiceRef(OsInvoiceModel inv) {
    final display = inv.displayNumber?.trim();
    if (display != null && display.isNotEmpty) return display;
    return shortRef(inv.id);
  }

  static String quotationRef(OsQuotationModel q) {
    final display = q.displayNumber?.trim();
    if (display != null && display.isNotEmpty) return display;
    return shortRef(q.id);
  }

  /// Short audit fallback (last 8 hex chars).
  static String shortRef(String? id) {
    if (id == null || id.trim().isEmpty) {
      return AppLocaleKeys.osCommonDash.tr;
    }
    final trimmed = id.trim();
    if (_voucherNum.hasMatch(trimmed) ||
        _invoiceNum.hasMatch(trimmed) ||
        _quotationNum.hasMatch(trimmed)) {
      return trimmed.toUpperCase();
    }
    final compact = trimmed.replaceAll('-', '');
    if (compact.length <= 8) return compact.toUpperCase();
    return compact.substring(compact.length - 8).toUpperCase();
  }

  static String nextVoucherDisplayNumber(Iterable<String?> existing) {
    var maxN = 100;
    for (final raw in existing) {
      final m = _voucherNum.firstMatch((raw ?? '').trim());
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    return 'V-${maxN + 1}';
  }

  static String nextInvoiceDisplayNumber(Iterable<String?> existing) {
    var maxN = 0;
    for (final raw in existing) {
      final m = _invoiceNum.firstMatch((raw ?? '').trim());
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    final next = maxN + 1;
    return 'INV-${next.toString().padLeft(3, '0')}';
  }

  /// Human refs like `Q-2024-001` (point_os). Sequence resets per calendar year.
  static String nextQuotationDisplayNumber(
    Iterable<String?> existing, {
    DateTime? now,
  }) {
    final year = (now ?? DateTime.now()).year;
    var maxN = 0;
    for (final raw in existing) {
      final m = _quotationNum.firstMatch((raw ?? '').trim());
      if (m != null) {
        final y = int.tryParse(m.group(1)!) ?? 0;
        if (y != year) continue;
        final n = int.tryParse(m.group(2)!) ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    return 'Q-$year-${(maxN + 1).toString().padLeft(3, '0')}';
  }

  static String quotationStatusLabel(String status) {
    switch (status) {
      case OsQuotationStatus.approved:
        return AppLocaleKeys.osQuotationsStatusApproved.tr;
      case OsQuotationStatus.rejected:
        return AppLocaleKeys.osQuotationsStatusRejected.tr;
      default:
        return AppLocaleKeys.osQuotationsStatusPending.tr;
    }
  }

  /// Bright enough for dark-theme badges (indigo #4F46E5 is too dim on dark UI).
  static Color quotationStatusColor(String status) {
    switch (status) {
      case OsQuotationStatus.approved:
        return const Color(0xFF34D399);
      case OsQuotationStatus.rejected:
        return const Color(0xFFFB7185);
      default:
        return const Color(0xFFA5B4FC);
    }
  }

  /// Dark enough to sit on a white chip (e.g. quote preview brand band).
  static Color quotationStatusOnLight(String status) {
    switch (status) {
      case OsQuotationStatus.approved:
        return const Color(0xFF047857);
      case OsQuotationStatus.rejected:
        return const Color(0xFFBE123C);
      default:
        return const Color(0xFF3730A3);
    }
  }

  /// Strip legacy UUID noise from stored voucher descriptions for display.
  static String displayDescription(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.contains('collection') && _uuidPattern.hasMatch(trimmed)) {
      return AppLocaleKeys.osInvoicesCollectionDescShort.tr;
    }
    if (RegExp(r'^invoice\s+.+\s+collection$', caseSensitive: false)
        .hasMatch(trimmed)) {
      return AppLocaleKeys.osInvoicesCollectionDescShort.tr;
    }
    final cleaned = trimmed
        .replaceAll(_uuidPattern, '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'\s*[—\-]\s*$'), '')
        .trim();
    return cleaned;
  }

  static String ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime? parseYmd(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw.trim());
    } catch (_) {
      return null;
    }
  }

  static String invoiceStatusLabel(String status) {
    switch (status) {
      case OsInvoiceStatus.draft:
        return AppLocaleKeys.osInvoicesStatusDraft.tr;
      case OsInvoiceStatus.sent:
        return AppLocaleKeys.osInvoicesStatusSent.tr;
      case OsInvoiceStatus.overdue:
        return AppLocaleKeys.osInvoicesStatusOverdue.tr;
      case OsInvoiceStatus.paid:
        return AppLocaleKeys.osInvoicesStatusPaid.tr;
      default:
        return status;
    }
  }

  static Color invoiceStatusColor(String status) {
    switch (status) {
      case OsInvoiceStatus.paid:
        return Colors.green;
      case OsInvoiceStatus.overdue:
        return Colors.red;
      case OsInvoiceStatus.draft:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  static String accountTypeLabel(String type) {
    switch (type) {
      case OsBankAccountType.cash:
        return AppLocaleKeys.osAccountsTypeCash.tr;
      case OsBankAccountType.vault:
        return AppLocaleKeys.osAccountsTypeVault.tr;
      default:
        return AppLocaleKeys.osAccountsTypeBank.tr;
    }
  }

  static String voucherTypeLabel(String type) {
    return type == OsVoucherType.payment
        ? AppLocaleKeys.osVouchersTypePayment.tr
        : AppLocaleKeys.osVouchersTypeReceipt.tr;
  }

  static String paymentMethodLabel(String? method) {
    switch (method) {
      case OsPaymentMethod.cash:
        return AppLocaleKeys.osPrintPayCash.tr;
      case OsPaymentMethod.cheque:
        return AppLocaleKeys.osPrintPayCheque.tr;
      case OsPaymentMethod.card:
        return AppLocaleKeys.osPrintPayCard.tr;
      case OsPaymentMethod.other:
        return AppLocaleKeys.osPrintPayOther.tr;
      case OsPaymentMethod.bankTransfer:
      default:
        return AppLocaleKeys.osPrintPayBank.tr;
    }
  }
}
