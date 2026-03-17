class ContentWriteModel {
  // final String taskType; // نوع المهمة
  final List platform; // المنصة
  final String contenttype; // نوع التصميم
  final String? designCount; // عدد التصاميم
  final String? designsDimensions; // القياسات

  ContentWriteModel({
    // required this.taskType,
    required this.platform,
    required this.contenttype,
    required this.designCount,
    required this.designsDimensions,
  });

  // ✅ fromJson
  factory ContentWriteModel.fromJson(Map<String, dynamic> json) {
    return ContentWriteModel(
      // taskType: json['taskType'] ?? '',
      platform: json['platform'] ?? '',
      contenttype: json['contenttype'] ?? '',
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
      // 'taskType': taskType,
      'platform': platform,
      'contenttype': contenttype,
      'designCount': designCount,
      'designsDimensions': designsDimensions,
    };
  }

  // ✅ copyWith
  ContentWriteModel copyWith({
    String? taskType,
    List? platform,
    String? contenttype,
    String? designCount,
    List<String>? sizes,
  }) {
    return ContentWriteModel(
      // taskType: taskType ?? this.taskType,
      platform: platform ?? this.platform,
      contenttype: contenttype ?? this.contenttype,
      designCount: designCount ?? this.designCount,
      designsDimensions: designsDimensions ?? this.designsDimensions,
    );
  }
}
