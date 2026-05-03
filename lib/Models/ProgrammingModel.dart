class ProgrammingModel {
  final String contenturl; // نوع المهمة
  // final String platform; // المنصة
  final String category; // نوع التصميم
  final String? fileurl; // عدد التصاميم
  final String? designsDimensions; // القياسات
  /// Long-form explanation of what the task involves (programming tasks).
  final String aboutTask;

  ProgrammingModel({
    required this.contenturl,
    // required this.platform,
    required this.category,
    required this.fileurl,
    required this.designsDimensions,
    this.aboutTask = '',
  });

  // ✅ fromJson
  factory ProgrammingModel.fromJson(Map<String, dynamic> json) {
    return ProgrammingModel(
      contenturl: json['contenturl'] ?? '',
      // platform: json['platform'] ?? '',
      category: json['category'] ?? '',
      fileurl: json['fileurl'] ?? 0,
      designsDimensions:
          (json['designsDimensions'] != null)
              ? (json['designsDimensions'] as String?).toString()
              : null,
      aboutTask: json['aboutTask']?.toString() ?? '',
    );
  }

  // ✅ toJson
  Map<String, dynamic> toJson() {
    return {
      'contenturl': contenturl,
      // 'platform': platform,
      'category': category,
      'fileurl': fileurl,
      'designsDimensions': designsDimensions,
      'aboutTask': aboutTask,
    };
  }

  // ✅ copyWith
  ProgrammingModel copyWith({
    String? contenturl,
    // String? platform,
    String? category,
    String? fileurl,
    String? designsDimensions,
    String? aboutTask,
  }) {
    return ProgrammingModel(
      contenturl: contenturl ?? this.contenturl,
      // platform: platform ?? this.platform,
      category: category ?? this.category,
      fileurl: fileurl ?? this.fileurl,
      designsDimensions: designsDimensions ?? this.designsDimensions,
      aboutTask: aboutTask ?? this.aboutTask,
    );
  }
}
