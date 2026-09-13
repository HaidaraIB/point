/// Shared line item for OS invoices and quotations.
class OsLineItem {
  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final double total;

  const OsLineItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
      };

  OsLineItem copyWith({
    String? id,
    String? description,
    double? quantity,
    double? unitPrice,
    double? total,
  }) {
    return OsLineItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
    );
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
