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
    this.subType = '',
    this.governingLaw = '',
    this.tags = const [],
    this.defaultDurationMonths,
    this.isPreset = true,
  });

  final String id;
  final String name;
  final String description;
  final String targetType;
  final List<OsContractClause> clauses;
  final String suggestedTitle;
  final String subType;
  final String governingLaw;
  final List<String> tags;
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
      subType: json['subType'] as String? ?? '',
      governingLaw: json['governingLaw'] as String? ?? '',
      tags: (json['tags'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
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
        'subType': subType,
        'governingLaw': governingLaw,
        'tags': tags,
        if (defaultDurationMonths != null)
          'defaultDurationMonths': defaultDurationMonths,
        'isPreset': isPreset,
      };

  OsContractTemplate copyWith({
    String? id,
    String? name,
    String? description,
    String? targetType,
    List<OsContractClause>? clauses,
    String? suggestedTitle,
    String? subType,
    String? governingLaw,
    List<String>? tags,
    int? defaultDurationMonths,
    bool? isPreset,
  }) {
    return OsContractTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetType: targetType ?? this.targetType,
      clauses: clauses ?? this.clauses,
      suggestedTitle: suggestedTitle ?? this.suggestedTitle,
      subType: subType ?? this.subType,
      governingLaw: governingLaw ?? this.governingLaw,
      tags: tags ?? this.tags,
      defaultDurationMonths:
          defaultDurationMonths ?? this.defaultDurationMonths,
      isPreset: isPreset ?? this.isPreset,
    );
  }

  /// Custom templates saved in Firestore must not use preset ids.
  static bool isPresetId(String id) => id.startsWith('TPL-');
}
