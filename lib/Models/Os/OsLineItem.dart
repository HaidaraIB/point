import 'package:point/Models/Os/OsServiceModel.dart';

/// Shared line item for OS invoices and quotations.
class OsLineItem {
  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final double total;
  final String? serviceId;
  final String? serviceMarketingDescription;

  const OsLineItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.serviceId,
    this.serviceMarketingDescription,
  });

  factory OsLineItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toDouble() ?? 1;
    final price = (json['unitPrice'] as num?)?.toDouble() ?? 0;
    return OsLineItem(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: qty,
      unitPrice: price,
      total: (json['total'] as num?)?.toDouble() ?? (qty * price),
      serviceId: json['serviceId'] as String?,
      serviceMarketingDescription:
          json['serviceMarketingDescription'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
        if (serviceId != null && serviceId!.trim().isNotEmpty)
          'serviceId': serviceId!.trim(),
        if (serviceMarketingDescription != null &&
            serviceMarketingDescription!.trim().isNotEmpty)
          'serviceMarketingDescription':
              serviceMarketingDescription!.trim(),
      };

  String? get effectiveMarketingDescription {
    final snap = serviceMarketingDescription?.trim();
    if (snap != null && snap.isNotEmpty) return snap;
    return null;
  }

  OsLineItem copyWith({
    String? id,
    String? description,
    double? quantity,
    double? unitPrice,
    double? total,
    String? serviceId,
    String? serviceMarketingDescription,
  }) {
    return OsLineItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      serviceId: serviceId ?? this.serviceId,
      serviceMarketingDescription:
          serviceMarketingDescription ?? this.serviceMarketingDescription,
    );
  }

  /// Fills marketing copy from the catalog when a line is linked to a service.
  static List<OsLineItem> withResolvedMarketing(
    List<OsLineItem> items,
    List<OsServiceModel> services,
  ) {
    if (items.isEmpty || services.isEmpty) return items;
    return items
        .map((item) => item._resolveMarketing(services))
        .toList(growable: false);
  }

  OsLineItem _resolveMarketing(List<OsServiceModel> services) {
    final existing = effectiveMarketingDescription;
    if (existing != null) return this;

    final svc = _linkedService(services);
    final marketing = svc?.marketingDescription?.trim();
    if (marketing == null || marketing.isEmpty) return this;
    return copyWith(serviceMarketingDescription: marketing);
  }

  OsServiceModel? _linkedService(List<OsServiceModel> services) {
    final sid = serviceId?.trim();
    if (sid != null && sid.isNotEmpty) {
      for (final s in services) {
        if (s.id == sid) return s;
      }
    }
    final desc = description.trim();
    if (desc.isEmpty) return null;
    for (final s in services) {
      if (s.name.trim() == desc) return s;
    }
    return null;
  }

  static List<OsLineItem> listFromJson(dynamic rawItems) {
    final items = <OsLineItem>[];
    if (rawItems is! List) return items;
    for (final e in rawItems) {
      if (e is Map<String, dynamic>) {
        items.add(OsLineItem.fromJson(e));
      } else if (e is Map) {
        items.add(OsLineItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return items;
  }
}
