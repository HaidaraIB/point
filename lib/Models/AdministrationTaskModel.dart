/// تفاصيل اختيارية لمهام القسم الإداري؛ [extra] للحقول المخصصة لاحقاً.
class AdministrationTaskModel {
  static const String kExtraKey = 'extra';

  final Map<String, dynamic> extra;

  AdministrationTaskModel({this.extra = const {}});

  factory AdministrationTaskModel.fromJson(Map<String, dynamic> json) {
    final raw = json[kExtraKey];
    if (raw is Map) {
      return AdministrationTaskModel(
        extra: Map<String, dynamic>.from(
          raw.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
    }
    return AdministrationTaskModel(extra: const {});
  }

  Map<String, dynamic> toJson() {
    return {kExtraKey: extra};
  }

  AdministrationTaskModel copyWith({Map<String, dynamic>? extra}) {
    return AdministrationTaskModel(extra: extra ?? this.extra);
  }
}
