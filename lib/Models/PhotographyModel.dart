class PhotographyModel {
  final String shootingtype; // نوع المهمة
  final List platform; // المنصة
  final String shootinglocation; // نوع التصميم
  final String? designCount; // عدد التصاميم
  final String? duration; // القياسات

  PhotographyModel({
    required this.shootingtype,
    required this.platform,
    required this.shootinglocation,
    required this.designCount,
    required this.duration,
  });

  // ✅ fromJson
  factory PhotographyModel.fromJson(Map<String, dynamic> json) {
    return PhotographyModel(
      shootingtype: json['shootingtype'] ?? '',
      platform: json['platform'] ?? '',
      shootinglocation: json['shootinglocation'] ?? '',
      designCount: json['designCount'] ?? 0,
      duration:
          (json['duration'] != null)
              ? (json['duration'] as String?).toString()
              : null,
    );
  }

  // ✅ toJson
  Map<String, dynamic> toJson() {
    return {
      'shootingtype': shootingtype,
      'platform': platform,
      'shootinglocation': shootinglocation,
      'designCount': designCount,
      'duration': duration,
    };
  }

  // ✅ copyWith
  PhotographyModel copyWith({
    String? shootingtype,
    List? platform,
    String? shootinglocation,
    String? designCount,
    List<String>? sizes,
  }) {
    return PhotographyModel(
      shootingtype: shootingtype ?? this.shootingtype,
      platform: platform ?? this.platform,
      shootinglocation: shootinglocation ?? this.shootinglocation,
      designCount: designCount ?? this.designCount,
      duration: duration ?? this.duration,
    );
  }
}
