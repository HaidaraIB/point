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
  final String? caption;
  final List<dynamic>? postAttachments;
  final List<dynamic>? storyAttachments;
  final List<dynamic>? reelAttachments;

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
    this.caption,
    this.postAttachments,
    this.storyAttachments,
    this.reelAttachments,
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
    String? caption,
    List<dynamic>? postAttachments,
    List<dynamic>? storyAttachments,
    List<dynamic>? reelAttachments,
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
      caption: caption ?? this.caption,
      postAttachments: postAttachments ?? this.postAttachments,
      storyAttachments: storyAttachments ?? this.storyAttachments,
      reelAttachments: reelAttachments ?? this.reelAttachments,
    );
  }

  factory ContentModel.fromJson(Map<String, dynamic> json, String id) {
    return ContentModel(
      id: id,
      title: json['title'] ?? '',
      files: _asDynamicList(json['files']),
      platform: json['platform'] ?? '',
      contentType: json['contentType'] ?? '',
      executor: json['executor'] ?? '',
      status: json['status'] ?? 'draft',
      promotion: json['promotion'],
      clientNotes: json['clientNotes'],
      clientEdits: _asDynamicList(json['clientEdits']),
      clientId: json['clientId'] ?? '',
      publishDate:
          json['publishDate'] != null
              ? DateTime.tryParse(json['publishDate'])
              : null,
      createdAt: DateTime.parse(json['createdAt']),
      notes: json['notes'], // 🔹 مضاف
      caption: json['caption'],
      postAttachments: _asDynamicList(json['postAttachments']),
      storyAttachments: _asDynamicList(json['storyAttachments']),
      reelAttachments: _asDynamicList(json['reelAttachments']),
    );
  }

  /// Firestore sometimes stores a lone URL string instead of a list.
  static List<dynamic>? _asDynamicList(dynamic value) {
    if (value == null) return null;
    if (value is List) return List<dynamic>.from(value);
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? <dynamic>[] : <dynamic>[t];
    }
    return <dynamic>[value];
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
      "caption": caption,
      "postAttachments": postAttachments,
      "storyAttachments": storyAttachments,
      "reelAttachments": reelAttachments,
    };
  }

  /// All attachment URLs for UI (list thumbs, details, edit).
  ///
  /// Merges [files] with Meta publish fields ([postAttachments] /
  /// [storyAttachments] / [reelAttachments]). Older / partial saves often put
  /// media only in the type-specific lists, so reading [files] alone shows
  /// "no attachments" while previews elsewhere look broken.
  List<String> get attachmentUrls {
    final out = <String>[];
    final seen = <String>{};
    void addAll(Iterable<dynamic>? raw) {
      if (raw == null) return;
      for (final e in raw) {
        final s = e?.toString().trim() ?? '';
        if (s.isEmpty) continue;
        if (seen.add(s)) out.add(s);
      }
    }

    addAll(files);
    addAll(postAttachments);
    addAll(storyAttachments);
    addAll(reelAttachments);
    return out;
  }

  /// Which typed attachment list a content type belongs to: `post`, `story` or
  /// `reel`. Everything that is neither a story nor a reel is treated as a post,
  /// the same mapping the publish flow uses.
  static String attachmentBucketFor(String contentType) {
    final t = contentType.toLowerCase();
    if (t.contains('reel')) return 'reel';
    if (t.contains('story')) return 'story';
    return 'post';
  }

  /// The typed list matching [contentType].
  List<String> get bucketAttachments {
    switch (attachmentBucketFor(contentType)) {
      case 'reel':
        return _clean(reelAttachments);
      case 'story':
        return _clean(storyAttachments);
      default:
        return _clean(postAttachments);
    }
  }

  /// URLs saved only in the legacy general [files] bucket, i.e. attachments that
  /// belong to no typed list. Content forms adopt these into the typed list so
  /// they stay editable and publishable.
  List<String> get untypedFileUrls {
    final typed = <String>{
      ..._clean(postAttachments),
      ..._clean(storyAttachments),
      ..._clean(reelAttachments),
    };
    return _clean(files).where((u) => !typed.contains(u)).toList();
  }

  static List<String> _clean(List<dynamic>? raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final e in raw ?? const <dynamic>[]) {
      final s = e?.toString().trim() ?? '';
      if (s.isEmpty) continue;
      if (seen.add(s)) out.add(s);
    }
    return out;
  }

  /// Prefer a URL for list-card thumbnails (first available attachment).
  String? get primaryAttachmentUrl {
    final urls = attachmentUrls;
    return urls.isEmpty ? null : urls.first;
  }
}
