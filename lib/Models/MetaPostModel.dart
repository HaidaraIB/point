/// Firestore document in `meta_posts` — direct Meta publish queue / history.
class MetaPostModel {
  const MetaPostModel({
    this.id,
    this.title = '',
    required this.pageId,
    required this.pageAccessToken,
    this.pageName,
    this.instagramUserId,
    this.instagramUserName,
    required this.postType,
    this.mediaType,
    this.mediaUrl,
    this.caption,
    required this.platforms,
    this.status = 'created',
    this.metaResponse,
    this.lastError,
    this.clientId,
    this.createdBy,
    this.lang,
    this.scheduledAt,
    required this.createdAt,
  });

  final String? id;
  final String title;
  final String pageId;
  /// Facebook Page access token from `/me/accounts` (required for publishing).
  final String pageAccessToken;
  final String? pageName;
  final String? instagramUserId;
  final String? instagramUserName;
  /// `reel` | `story` | `feed`
  final String postType;
  /// `photo` | `video` | null
  final String? mediaType;
  final String? mediaUrl;
  final String? caption;
  final List<dynamic> platforms;
  /// `created` | `publishing` | `published` | `failed`
  final String status;
  final String? metaResponse;
  final String? lastError;
  final String? clientId;
  final String? createdBy;
  /// UI/content language used by external scheduler worker notifications (`ar`/`en`).
  final String? lang;
  /// When present and status is `scheduled`, worker publishes at/after this UTC time.
  final DateTime? scheduledAt;
  final DateTime createdAt;

  MetaPostModel copyWith({
    String? id,
    String? title,
    String? pageId,
    String? pageAccessToken,
    String? pageName,
    String? instagramUserId,
    String? instagramUserName,
    String? postType,
    String? mediaType,
    String? mediaUrl,
    String? caption,
    List<dynamic>? platforms,
    String? status,
    String? metaResponse,
    String? lastError,
    String? clientId,
    String? createdBy,
    String? lang,
    DateTime? scheduledAt,
    DateTime? createdAt,
  }) {
    return MetaPostModel(
      id: id ?? this.id,
      title: title ?? this.title,
      pageId: pageId ?? this.pageId,
      pageAccessToken: pageAccessToken ?? this.pageAccessToken,
      pageName: pageName ?? this.pageName,
      instagramUserId: instagramUserId ?? this.instagramUserId,
      instagramUserName: instagramUserName ?? this.instagramUserName,
      postType: postType ?? this.postType,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      caption: caption ?? this.caption,
      platforms: platforms ?? this.platforms,
      status: status ?? this.status,
      metaResponse: metaResponse ?? this.metaResponse,
      lastError: lastError ?? this.lastError,
      clientId: clientId ?? this.clientId,
      createdBy: createdBy ?? this.createdBy,
      lang: lang ?? this.lang,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory MetaPostModel.fromJson(Map<String, dynamic> json, String docId) {
    return MetaPostModel(
      id: docId,
      title: json['title']?.toString() ?? '',
      pageId: json['pageId']?.toString() ?? '',
      pageAccessToken: json['pageAccessToken']?.toString() ?? '',
      pageName: json['pageName']?.toString(),
      instagramUserId: json['instagramUserId']?.toString(),
      instagramUserName: json['instagramUserName']?.toString(),
      postType: json['postType']?.toString() ?? 'feed',
      mediaType: json['mediaType']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      caption: json['caption']?.toString(),
      platforms: json['platforms'] is List ? List<dynamic>.from(json['platforms'] as List) : [],
      status: json['status']?.toString() ?? 'created',
      metaResponse: json['metaResponse']?.toString(),
      lastError: json['lastError']?.toString(),
      clientId: json['clientId']?.toString(),
      createdBy: json['createdBy']?.toString(),
      lang: json['lang']?.toString(),
      scheduledAt: _parseDate(json['scheduledAt'] ?? json['scheduled_at']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'pageId': pageId,
      'pageAccessToken': pageAccessToken,
      'pageName': pageName,
      'instagramUserId': instagramUserId,
      'instagramUserName': instagramUserName,
      'postType': postType,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'caption': caption,
      'platforms': platforms,
      'status': status,
      'metaResponse': metaResponse,
      'lastError': lastError,
      'clientId': clientId,
      'createdBy': createdBy,
      'lang': lang,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
