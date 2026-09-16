import 'package:point/Models/Os/OsContractClause.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';

class OsContractTemplate {
  const OsContractTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.targetType,
    required this.clauses,
    this.suggestedTitle = '',
    this.defaultDurationMonths,
    this.isPreset = true,
  });

  final String id;
  final String name;
  final String description;
  final String targetType;
  final List<OsContractClause> clauses;
  final String suggestedTitle;
  final int? defaultDurationMonths;
  final bool isPreset;

  factory OsContractTemplate.fromJson(Map<String, dynamic> json) {
    return OsContractTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetType: json['targetType'] as String? ??
          OsLegalContractTargetType.client,
      clauses: OsContractClause.listFromJson(json['clauses']),
      suggestedTitle: json['suggestedTitle'] as String? ?? '',
      defaultDurationMonths: (json['defaultDurationMonths'] as num?)?.toInt(),
      isPreset: json['isPreset'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'targetType': targetType,
        'clauses': clauses.map((c) => c.toJson()).toList(),
        'suggestedTitle': suggestedTitle,
        if (defaultDurationMonths != null)
          'defaultDurationMonths': defaultDurationMonths,
        'isPreset': isPreset,
      };
}
