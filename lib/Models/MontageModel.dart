class MonatageModel {
  final String category; // نوع المهمة
  final List platform; // المنصة
  final String dimentioans; // نوع التصميم
  final String? attachementurl; // عدد التصاميم
  final String? duration; // القياسات

  MonatageModel({
    required this.category,
    required this.platform,
    required this.dimentioans,
    required this.attachementurl,
    required this.duration,
  });

  factory MonatageModel.fromJson(Map<String, dynamic> json) {
    return MonatageModel(
      category: json['category'] ?? '',
      platform: json['platform'] ?? '',
      dimentioans: json['dimentioans'] ?? '',
      attachementurl: json['attachementurl'] ?? 0,
      duration:
          (json['duration'] != null)
              ? (json['duration'] as String?).toString()
              : null,
    );
  }

  // ✅ toJson
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'platform': platform,
      'dimentioans': dimentioans,
      'attachementurl': attachementurl,
      'duration': duration,
    };
  }

  // ✅ copyWith
  MonatageModel copyWith({
    String? category,
    List? platform,
    String? dimentioans,
    String? attachementurl,
    List<String>? sizes,
  }) {
    return MonatageModel(
      category: category ?? this.category,
      platform: platform ?? this.platform,
      dimentioans: dimentioans ?? this.dimentioans,
      attachementurl: attachementurl ?? this.attachementurl,
      duration: duration ?? this.duration,
    );
  }
}
