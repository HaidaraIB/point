class OsContractClause {
  const OsContractClause({
    required this.id,
    required this.title,
    required this.content,
    this.isMandatory = false,
    this.isEnabled = true,
  });

  final String id;
  final String title;
  final String content;
  final bool isMandatory;
  final bool isEnabled;

  factory OsContractClause.fromJson(Map<String, dynamic> json) {
    return OsContractClause(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isMandatory: json['isMandatory'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'isMandatory': isMandatory,
        'isEnabled': isEnabled,
      };

  OsContractClause copyWith({
    String? id,
    String? title,
    String? content,
    bool? isMandatory,
    bool? isEnabled,
  }) {
    return OsContractClause(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      isMandatory: isMandatory ?? this.isMandatory,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  static List<OsContractClause> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => OsContractClause.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
