import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Models/Os/os_finance_enums.dart';

class OsInvoiceModel {
  final String? id;
  /// Human-readable ref like `INV-001` (point_os style).
  final String? displayNumber;
  final String clientId;
  final String clientName;
  /// Snapshotted client contact (as issued).
  final String? clientPhone;
  final String? clientEmail;
  final String? clientAddress;
  final String? clientTaxNumber;
  final String date;
  final String dueDate;
  final String status;
  final double amount;
  final double discount;
  final double vat;
  final double total;
  final List<OsLineItem> items;
  final String? bankAccountId;
  /// See [OsPaymentMethod].
  final String? paymentMethod;
  final String? notes;
  /// Source quotation when created via quote → invoice.
  final String? quotationId;
  /// PayTabs hosted-page session fields (server-written, legacy).
  final String? paytabsCartId;
  final String? paytabsTranRef;
  final String? paytabsRedirectUrl;
  final double? paytabsSessionAmount;
  /// Generic card payment session fields (server-written).
  final String? cardProvider;
  final String? cardPaymentUrl;
  final double? cardSessionAmount;
  final String? cardProviderRef;
  final String? alqasehOrderId;
  final String? payLinkToken;
  final String? qicardRequestId;
  final String? qicardPaymentId;
  final DateTime createdAt;

  const OsInvoiceModel({
    this.id,
    this.displayNumber,
    required this.clientId,
    required this.clientName,
    this.clientPhone,
    this.clientEmail,
    this.clientAddress,
    this.clientTaxNumber,
    required this.date,
    required this.dueDate,
    this.status = OsInvoiceStatus.sent,
    required this.amount,
    this.discount = 0,
    required this.vat,
    required this.total,
    this.items = const [],
    this.bankAccountId,
    this.paymentMethod,
    this.notes,
    this.quotationId,
    this.paytabsCartId,
    this.paytabsTranRef,
    this.paytabsRedirectUrl,
    this.paytabsSessionAmount,
    this.cardProvider,
    this.cardPaymentUrl,
    this.cardSessionAmount,
    this.cardProviderRef,
    this.alqasehOrderId,
    this.payLinkToken,
    this.qicardRequestId,
    this.qicardPaymentId,
    required this.createdAt,
  });

  bool get isPaid => status == OsInvoiceStatus.paid;

  /// `amount - discount + vat` (clamped discount).
  static double computeTotal({
    required double amount,
    required double discount,
    required double vat,
  }) {
    final d = discount < 0 ? 0.0 : discount;
    return amount - d + vat;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory OsInvoiceModel.fromJson(Map<String, dynamic> json, String docId) {
    return OsInvoiceModel(
      id: json['id'] as String? ?? docId,
      displayNumber: json['displayNumber'] as String?,
      clientId: json['clientId'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      clientPhone: json['clientPhone'] as String?,
      clientEmail: json['clientEmail'] as String?,
      clientAddress: json['clientAddress'] as String?,
      clientTaxNumber: json['clientTaxNumber'] as String?,
      date: json['date'] as String? ?? '',
      dueDate: json['dueDate'] as String? ?? '',
      status: json['status'] as String? ?? OsInvoiceStatus.sent,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      vat: (json['vat'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      items: OsLineItem.listFromJson(json['items']),
      bankAccountId: json['bankAccountId'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      notes: json['notes'] as String?,
      quotationId: json['quotationId'] as String?,
      paytabsCartId: json['paytabsCartId'] as String?,
      paytabsTranRef: json['paytabsTranRef'] as String?,
      paytabsRedirectUrl: json['paytabsRedirectUrl'] as String?,
      paytabsSessionAmount: (json['paytabsSessionAmount'] as num?)?.toDouble(),
      cardProvider: json['cardProvider'] as String?,
      cardPaymentUrl: json['cardPaymentUrl'] as String?,
      cardSessionAmount: (json['cardSessionAmount'] as num?)?.toDouble(),
      cardProviderRef: json['cardProviderRef'] as String?,
      alqasehOrderId: json['alqasehOrderId'] as String?,
      payLinkToken: json['payLinkToken'] as String?,
      qicardRequestId: json['qicardRequestId'] as String?,
      qicardPaymentId: json['qicardPaymentId'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (displayNumber != null) 'displayNumber': displayNumber,
        'clientId': clientId,
        'clientName': clientName,
        if (clientPhone != null) 'clientPhone': clientPhone,
        if (clientEmail != null) 'clientEmail': clientEmail,
        if (clientAddress != null) 'clientAddress': clientAddress,
        if (clientTaxNumber != null) 'clientTaxNumber': clientTaxNumber,
        'date': date,
        'dueDate': dueDate,
        'status': status,
        'amount': amount,
        'discount': discount,
        'vat': vat,
        'total': total,
        'items': items.map((e) => e.toJson()).toList(),
        'bankAccountId': bankAccountId,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (notes != null) 'notes': notes,
        if (quotationId != null && quotationId!.isNotEmpty)
          'quotationId': quotationId,
        if (paytabsCartId != null) 'paytabsCartId': paytabsCartId,
        if (paytabsTranRef != null) 'paytabsTranRef': paytabsTranRef,
        if (paytabsRedirectUrl != null) 'paytabsRedirectUrl': paytabsRedirectUrl,
        if (paytabsSessionAmount != null)
          'paytabsSessionAmount': paytabsSessionAmount,
        if (cardProvider != null) 'cardProvider': cardProvider,
        if (cardPaymentUrl != null) 'cardPaymentUrl': cardPaymentUrl,
        if (cardSessionAmount != null) 'cardSessionAmount': cardSessionAmount,
        if (cardProviderRef != null) 'cardProviderRef': cardProviderRef,
        if (alqasehOrderId != null) 'alqasehOrderId': alqasehOrderId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsInvoiceModel copyWith({
    String? id,
    String? displayNumber,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? clientEmail,
    String? clientAddress,
    String? clientTaxNumber,
    String? date,
    String? dueDate,
    String? status,
    double? amount,
    double? discount,
    double? vat,
    double? total,
    List<OsLineItem>? items,
    String? bankAccountId,
    bool clearBankAccountId = false,
    String? paymentMethod,
    String? notes,
    String? quotationId,
    bool clearQuotationId = false,
    String? paytabsCartId,
    String? paytabsTranRef,
    String? paytabsRedirectUrl,
    double? paytabsSessionAmount,
    String? cardProvider,
    String? cardPaymentUrl,
    double? cardSessionAmount,
    String? cardProviderRef,
    String? alqasehOrderId,
    String? payLinkToken,
    String? qicardRequestId,
    String? qicardPaymentId,
    DateTime? createdAt,
  }) {
    return OsInvoiceModel(
      id: id ?? this.id,
      displayNumber: displayNumber ?? this.displayNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      clientAddress: clientAddress ?? this.clientAddress,
      clientTaxNumber: clientTaxNumber ?? this.clientTaxNumber,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      discount: discount ?? this.discount,
      vat: vat ?? this.vat,
      total: total ?? this.total,
      items: items ?? this.items,
      bankAccountId:
          clearBankAccountId ? null : (bankAccountId ?? this.bankAccountId),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      quotationId:
          clearQuotationId ? null : (quotationId ?? this.quotationId),
      paytabsCartId: paytabsCartId ?? this.paytabsCartId,
      paytabsTranRef: paytabsTranRef ?? this.paytabsTranRef,
      paytabsRedirectUrl: paytabsRedirectUrl ?? this.paytabsRedirectUrl,
      paytabsSessionAmount: paytabsSessionAmount ?? this.paytabsSessionAmount,
      cardProvider: cardProvider ?? this.cardProvider,
      cardPaymentUrl: cardPaymentUrl ?? this.cardPaymentUrl,
      cardSessionAmount: cardSessionAmount ?? this.cardSessionAmount,
      cardProviderRef: cardProviderRef ?? this.cardProviderRef,
      alqasehOrderId: alqasehOrderId ?? this.alqasehOrderId,
      payLinkToken: payLinkToken ?? this.payLinkToken,
      qicardRequestId: qicardRequestId ?? this.qicardRequestId,
      qicardPaymentId: qicardPaymentId ?? this.qicardPaymentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
