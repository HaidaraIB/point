import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/os_finance_enums.dart';

class OsBankAccountModel {
  final String? id;
  final String name;
  final String accountNumber;
  final double balance;
  final String type;
  final DateTime createdAt;

  const OsBankAccountModel({
    this.id,
    required this.name,
    required this.accountNumber,
    required this.balance,
    this.type = OsBankAccountType.bank,
    required this.createdAt,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory OsBankAccountModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return OsBankAccountModel(
      id: json['id'] as String? ?? docId,
      name: json['name'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ??
          OsBankAccountType.unsetNumber,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      type: json['type'] as String? ?? OsBankAccountType.bank,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'accountNumber': accountNumber,
        'balance': balance,
        'type': type,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsBankAccountModel copyWith({
    String? id,
    String? name,
    String? accountNumber,
    double? balance,
    String? type,
    DateTime? createdAt,
  }) {
    return OsBankAccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      accountNumber: accountNumber ?? this.accountNumber,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
