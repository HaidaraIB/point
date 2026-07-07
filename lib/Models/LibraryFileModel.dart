import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore document in `library_files` — direct upload into a Library leaf folder.
class LibraryFileModel {
  const LibraryFileModel({
    this.id,
    required this.clientId,
    required this.clientName,
    required this.yearMonth,
    required this.category,
    required this.url,
    required this.fileName,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  final String? id;
  final String clientId;
  final String clientName;
  final String yearMonth;
  final String category;
  final String url;
  final String fileName;
  final DateTime uploadedAt;
  final String uploadedBy;

  LibraryFileModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? yearMonth,
    String? category,
    String? url,
    String? fileName,
    DateTime? uploadedAt,
    String? uploadedBy,
  }) {
    return LibraryFileModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      yearMonth: yearMonth ?? this.yearMonth,
      category: category ?? this.category,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
    );
  }

  factory LibraryFileModel.fromJson(Map<String, dynamic> json, String docId) {
    DateTime uploadedAt = DateTime.now();
    final rawAt = json['uploadedAt'];
    if (rawAt is Timestamp) {
      uploadedAt = rawAt.toDate();
    } else if (rawAt is String && rawAt.isNotEmpty) {
      uploadedAt = DateTime.tryParse(rawAt) ?? uploadedAt;
    }

    return LibraryFileModel(
      id: docId,
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      yearMonth: json['yearMonth']?.toString() ?? '',
      category: json['category']?.toString() ?? 'post',
      url: json['url']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      uploadedAt: uploadedAt,
      uploadedBy: json['uploadedBy']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'yearMonth': yearMonth,
      'category': category,
      'url': url,
      'fileName': fileName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'uploadedBy': uploadedBy,
    };
  }
}
