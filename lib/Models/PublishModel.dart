class PublishModel {
  final String contenturl; // نوع المهمة
  final List platform; // المنصة
  final String category; // نوع التصميم
  final String? fileurl; // عدد التصاميم
  final String? designsDimensions; // القياسات

  PublishModel({
    required this.contenturl,
    required this.platform,
    required this.category,
    required this.fileurl,
    required this.designsDimensions,
  });

  // ✅ fromJson
  factory PublishModel.fromJson(Map<String, dynamic> json) {
    return PublishModel(
      contenturl: json['contenturl'] ?? '',
      platform: json['platform'] ?? '',
      category: json['category'] ?? '',
      fileurl: json['fileurl'] ?? 0,
      designsDimensions:
          (json['designsDimensions'] != null)
              ? (json['designsDimensions'] as String?).toString()
              : null,
    );
  }

  // ✅ toJson
  Map<String, dynamic> toJson() {
    return {
      'contenturl': contenturl,
      'platform': platform,
      'category': category,
      'fileurl': fileurl,
      'designsDimensions': designsDimensions,
    };
  }

  // ✅ copyWith
  PublishModel copyWith({
    String? contenturl,
    List? platform,
    String? category,
    String? fileurl,
    List<String>? sizes,
  }) {
    return PublishModel(
      contenturl: contenturl ?? this.contenturl,
      platform: platform ?? this.platform,
      category: category ?? this.category,
      fileurl: fileurl ?? this.fileurl,
      designsDimensions: designsDimensions ?? this.designsDimensions,
    );
  }
}
