class ContentModel {
  final String? id; // auto id من فايربيز
  final String title; // العنوان
  final List platform; // المنصة (Facebook, Instagram ...)
  final String contentType; // نوع المحتوى (Post, Story ...)
  final String executor; // منفذ المحتوى
  final String status; // الحالة (draft, approved ...)
  final String? promotion; // الترويج (organic / paid)
  final String? clientNotes; // ملاحظات العميل
  final List<dynamic>? clientEdits; // تعديلات العميل
  final String clientId; // معرف العميل المرتبط بالمحتوى
  final DateTime? publishDate; // تاريخ النشر
  final DateTime createdAt; // تاريخ الإنشاء
  List<dynamic>? files;
  final String? notes; // 🔹 الملاحظات الداخلية

  ContentModel({
    this.id,
    required this.title,
    required this.platform,
    required this.contentType,
    required this.executor,
    required this.status,
    required this.clientId,
    this.promotion,
    this.clientNotes,
    this.clientEdits,
    this.publishDate,
    required this.createdAt,
    this.files,
    this.notes, // 🔹 مضاف
  });

  ContentModel copyWith({
    String? id,
    String? title,
    List? platform,
    String? contentType,
    String? executor,
    String? status,
    String? promotion,
    String? clientNotes,
    List<dynamic>? clientEdits,
    String? clientId,
    DateTime? publishDate,
    DateTime? createdAt,
    List<dynamic>? files,
    String? notes, // 🔹 مضاف
  }) {
    return ContentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      platform: platform ?? this.platform,
      contentType: contentType ?? this.contentType,
      executor: executor ?? this.executor,
      status: status ?? this.status,
      promotion: promotion ?? this.promotion,
      clientNotes: clientNotes ?? this.clientNotes,
      clientEdits: clientEdits ?? this.clientEdits,
      clientId: clientId ?? this.clientId,
      publishDate: publishDate ?? this.publishDate,
      createdAt: createdAt ?? this.createdAt,
      files: files ?? this.files,
      notes: notes ?? this.notes, // 🔹 مضاف
    );
  }

  factory ContentModel.fromJson(Map<String, dynamic> json, String id) {
    return ContentModel(
      id: id,
      title: json['title'] ?? '',
      files: json['files'],
      platform: json['platform'] ?? '',
      contentType: json['contentType'] ?? '',
      executor: json['executor'] ?? '',
      status: json['status'] ?? 'draft',
      promotion: json['promotion'],
      clientNotes: json['clientNotes'],
      clientEdits: json['clientEdits'],
      clientId: json['clientId'] ?? '',
      publishDate:
          json['publishDate'] != null
              ? DateTime.tryParse(json['publishDate'])
              : null,
      createdAt: DateTime.parse(json['createdAt']),
      notes: json['notes'], // 🔹 مضاف
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "platform": platform,
      "contentType": contentType,
      "executor": executor,
      'files': files,
      "status": status,
      "promotion": promotion,
      "clientNotes": clientNotes,
      "clientEdits": clientEdits,
      "clientId": clientId,
      "publishDate": publishDate?.toIso8601String(),
      "createdAt": createdAt.toIso8601String(),
      "notes": notes, // 🔹 مضاف
    };
  }
}
