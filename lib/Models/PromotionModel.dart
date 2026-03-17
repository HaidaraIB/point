class PromotionModel {
  final String name; // اسم المهمة
  final String target; // اسم العميل
  final String campaignName; // اسم الحملة
  final String type; // نوع المهمة: تصوير، مونتاج، تصميم، تسويق...
  final String priority; // أولوية المهمة
  final String status; // الحالة: جديد، قيد التنفيذ، مكتمل...
  final String? description; // تفاصيل إضافية عامة
  final String? executorId; // منفذ المهمة (id أو الاسم)
  final DateTime? startDate;
  final DateTime? endDate;
  final String? duration; // المدة
  final String? tags; // العلامات
  final List? platforms; // المنصات: Facebook, Instagram, TikTok...
  final List<String>? interests; // الاهتمامات
  final List<String>? cities; // المدن
  final List<String>? countries; // 🌍 الدول
  final List<String>? specializations; // المجالات أو التخصصات
  final String? ageRanges; // الفئات العمرية
  final Map<String, dynamic>? customDetails; // تفاصيل خاصة بنوع المهمة
  final String? notes;
  final String? attachementurl; // رابط الملفات
  final DateTime createdAt;

  PromotionModel({
    required this.name,
    required this.target,
    required this.campaignName,
    required this.type,
    required this.priority,
    required this.status,
    this.description,
    this.executorId,
    this.startDate,
    this.endDate,
    this.duration,
    this.tags,
    this.platforms,
    this.interests,
    this.cities,
    this.countries, // ✅ تمت الإضافة هنا
    this.specializations,
    this.ageRanges,
    this.customDetails,
    this.notes,
    this.attachementurl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      name: json['name'],
      target: json['target'],
      campaignName: json['campaignName'],
      type: json['type'],
      priority: json['priority'],
      status: json['status'],
      description: json['description'],
      executorId: json['executorId'],
      startDate:
          json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      duration: json['duration'],
      tags: json['tags'],
      platforms: json['platforms'],
      interests: (json['interests'] as List?)?.cast<String>(),
      cities: (json['cities'] as List?)?.cast<String>(),
      countries:
          (json['countries'] as List?)?.cast<String>(), // ✅ تمت الإضافة هنا
      specializations: (json['specializations'] as List?)?.cast<String>(),
      ageRanges: json['ageRanges'],
      customDetails: json['customDetails'] as Map<String, dynamic>?,
      notes: json['notes'],
      attachementurl: json['attachementurl'] as String?,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'target': target,
    'campaignName': campaignName,
    'type': type,
    'priority': priority,
    'status': status,
    'description': description,
    'executorId': executorId,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'duration': duration,
    'tags': tags,
    'platforms': platforms,
    'interests': interests,
    'cities': cities,
    'countries': countries, // ✅ تمت الإضافة هنا
    'specializations': specializations,
    'ageRanges': ageRanges,
    'customDetails': customDetails,
    'notes': notes,
    'attachementurl': attachementurl,
    'createdAt': createdAt.toIso8601String(),
  };

  PromotionModel copyWith({
    String? name,
    String? target,
    String? campaignName,
    String? type,
    String? priority,
    String? status,
    String? description,
    String? executorId,
    DateTime? startDate,
    DateTime? endDate,
    String? duration,
    String? tags,
    List? platforms,
    List<String>? interests,
    List<String>? cities,
    List<String>? countries, // ✅ تمت الإضافة هنا
    List<String>? specializations,
    String? ageRanges,
    Map<String, dynamic>? customDetails,
    String? notes,
    String? attachementurl,
    DateTime? createdAt,
  }) {
    return PromotionModel(
      name: name ?? this.name,
      target: target ?? this.target,
      campaignName: campaignName ?? this.campaignName,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      description: description ?? this.description,
      executorId: executorId ?? this.executorId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      duration: duration ?? this.duration,
      tags: tags ?? this.tags,
      platforms: platforms ?? this.platforms,
      interests: interests ?? this.interests,
      cities: cities ?? this.cities,
      countries: countries ?? this.countries, // ✅ تمت الإضافة هنا
      specializations: specializations ?? this.specializations,
      ageRanges: ageRanges ?? this.ageRanges,
      customDetails: customDetails ?? this.customDetails,
      notes: notes ?? this.notes,
      attachementurl: attachementurl ?? this.attachementurl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
