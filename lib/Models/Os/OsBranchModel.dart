import 'package:cloud_firestore/cloud_firestore.dart';

/// Branch / office site for Point OS (expenses, payroll, employees).
class OsBranchStatus {
  OsBranchStatus._();

  static const active = 'ACTIVE';
  static const inactive = 'INACTIVE';

  static const all = [active, inactive];
}

class OsBranchModel {
  final String? id;
  final String name;
  final String location;
  final String manager;
  final String phone;
  final String status;
  final String? color;
  final DateTime createdAt;

  const OsBranchModel({
    this.id,
    required this.name,
    required this.location,
    required this.manager,
    required this.phone,
    this.status = OsBranchStatus.active,
    this.color,
    required this.createdAt,
  });

  bool get isActive => status == OsBranchStatus.active;

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory OsBranchModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return OsBranchModel(
      id: json['id'] as String? ?? docId,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      manager: json['manager'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      status: json['status'] as String? ?? OsBranchStatus.active,
      color: json['color'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'manager': manager,
        'phone': phone,
        'status': status,
        if (color != null && color!.isNotEmpty) 'color': color,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsBranchModel copyWith({
    String? id,
    String? name,
    String? location,
    String? manager,
    String? phone,
    String? status,
    String? color,
    DateTime? createdAt,
    bool clearColor = false,
  }) {
    return OsBranchModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      manager: manager ?? this.manager,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      color: clearColor ? null : (color ?? this.color),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
