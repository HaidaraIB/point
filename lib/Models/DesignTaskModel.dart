class DesignTaskModel {
  final String taskType; // نوع المهمة
  final List platform; // المنصة
  final String designType; // نوع التصميم
  final String? designCount; // عدد التصاميم
  final String? designsDimensions; // القياسات

  DesignTaskModel({
    required this.taskType,
    required this.platform,
    required this.designType,
    required this.designCount,
    required this.designsDimensions,
  });

  // ✅ fromJson
  factory DesignTaskModel.fromJson(Map<String, dynamic> json) {
    return DesignTaskModel(
      taskType: json['taskType'] ?? '',
      platform: json['platform'] ?? '',
      designType: json['designType'] ?? '',
      designCount: json['designCount'] ?? 0,
      designsDimensions:
          (json['designsDimensions'] != null)
              ? (json['designsDimensions'] as String?).toString()
              : null,
    );
  }

  // ✅ toJson
  Map<String, dynamic> toJson() {
    return {
      'taskType': taskType,
      'platform': platform,
      'designType': designType,
      'designCount': designCount,
      'designsDimensions': designsDimensions,
    };
  }

  // ✅ copyWith
  DesignTaskModel copyWith({
    String? taskType,
    List? platform,
    String? designType,
    String? designCount,
    List<String>? sizes,
  }) {
    return DesignTaskModel(
      taskType: taskType ?? this.taskType,
      platform: platform ?? this.platform,
      designType: designType ?? this.designType,
      designCount: designCount ?? this.designCount,
      designsDimensions: designsDimensions ?? this.designsDimensions,
    );
  }
}
