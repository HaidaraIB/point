import 'package:point/Services/StorageKeys.dart';
import 'package:point/Models/VoiceRecordEntry.dart';

class ProgrammingUpdateModel {
  final String? id;
  final String title;
  final String description;
  final List<String> files;
  final String voiceRecordUrl;
  final int voiceRecordDurationSec;
  final List<VoiceRecordEntry> voiceRecords;
  final String assignedTo;
  final String clientName;
  final String priority;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String contenturl;
  final String category;
  final String fileurl;
  final String aboutTask;
  final String status;
  final String? convertedToTaskId;
  final DateTime? convertedAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProgrammingUpdateModel({
    this.id,
    this.title = '',
    this.description = '',
    this.files = const [],
    this.voiceRecordUrl = '',
    this.voiceRecordDurationSec = 0,
    this.voiceRecords = const [],
    this.assignedTo = '',
    this.clientName = '',
    this.priority = '',
    this.fromDate,
    this.toDate,
    this.contenturl = '',
    this.category = '',
    this.fileurl = '',
    this.aboutTask = '',
    this.status = StorageKeys.programmingUpdateStatusPending,
    this.convertedToTaskId,
    this.convertedAt,
    this.createdBy = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isPending =>
      status == StorageKeys.programmingUpdateStatusPending;

  bool get isConverted =>
      status == StorageKeys.programmingUpdateStatusConverted;

  factory ProgrammingUpdateModel.fromJson(Map<String, dynamic> json) {
    final parsedVoiceRecords = VoiceRecordEntry.listFromJson(json);
    return ProgrammingUpdateModel(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      files: json['files'] != null
          ? List<String>.from(json['files'] as List)
          : <String>[],
      voiceRecords: parsedVoiceRecords,
      voiceRecordUrl: parsedVoiceRecords.isNotEmpty
          ? parsedVoiceRecords.first.url
          : (json['voiceRecordUrl']?.toString() ?? ''),
      voiceRecordDurationSec: parsedVoiceRecords.isNotEmpty
          ? parsedVoiceRecords.first.durationSec
          : ((json['voiceRecordDurationSec'] as num?)?.toInt() ?? 0),
      assignedTo: json['assignedTo']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      fromDate: json['fromDate'] != null &&
              json['fromDate'].toString().trim().isNotEmpty
          ? DateTime.tryParse(json['fromDate'].toString())
          : null,
      toDate: json['toDate'] != null &&
              json['toDate'].toString().trim().isNotEmpty
          ? DateTime.tryParse(json['toDate'].toString())
          : null,
      contenturl: json['contenturl']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      fileurl: json['fileurl']?.toString() ?? '',
      aboutTask: json['aboutTask']?.toString() ?? '',
      status: json['status']?.toString() ??
          StorageKeys.programmingUpdateStatusPending,
      convertedToTaskId: json['convertedToTaskId']?.toString(),
      convertedAt: json['convertedAt'] != null &&
              json['convertedAt'].toString().trim().isNotEmpty
          ? DateTime.tryParse(json['convertedAt'].toString())
          : null,
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null && id!.isNotEmpty) 'id': id,
      'title': title,
      'description': description,
      'files': files,
      if (voiceRecordUrl.isNotEmpty) 'voiceRecordUrl': voiceRecordUrl,
      if (voiceRecordDurationSec > 0)
        'voiceRecordDurationSec': voiceRecordDurationSec,
      if (voiceRecords.isNotEmpty)
        'voiceRecords': VoiceRecordEntry.listToJson(voiceRecords),
      'assignedTo': assignedTo,
      'clientName': clientName,
      'priority': priority,
      if (fromDate != null) 'fromDate': fromDate!.toIso8601String(),
      if (toDate != null) 'toDate': toDate!.toIso8601String(),
      'contenturl': contenturl,
      'category': category,
      'fileurl': fileurl,
      'aboutTask': aboutTask,
      'status': status,
      if (convertedToTaskId != null && convertedToTaskId!.isNotEmpty)
        'convertedToTaskId': convertedToTaskId,
      if (convertedAt != null) 'convertedAt': convertedAt!.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ProgrammingUpdateModel copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? files,
    String? voiceRecordUrl,
    int? voiceRecordDurationSec,
    List<VoiceRecordEntry>? voiceRecords,
    String? assignedTo,
    String? clientName,
    String? priority,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearFromDate = false,
    bool clearToDate = false,
    String? contenturl,
    String? category,
    String? fileurl,
    String? aboutTask,
    String? status,
    String? convertedToTaskId,
    DateTime? convertedAt,
    bool clearConvertedAt = false,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearVoiceRecord = false,
  }) {
    return ProgrammingUpdateModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      files: files ?? this.files,
      voiceRecordUrl:
          clearVoiceRecord ? '' : (voiceRecordUrl ?? this.voiceRecordUrl),
      voiceRecordDurationSec: clearVoiceRecord
          ? 0
          : (voiceRecordDurationSec ?? this.voiceRecordDurationSec),
      voiceRecords: clearVoiceRecord
          ? const []
          : (voiceRecords ?? this.voiceRecords),
      assignedTo: assignedTo ?? this.assignedTo,
      clientName: clientName ?? this.clientName,
      priority: priority ?? this.priority,
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      contenturl: contenturl ?? this.contenturl,
      category: category ?? this.category,
      fileurl: fileurl ?? this.fileurl,
      aboutTask: aboutTask ?? this.aboutTask,
      status: status ?? this.status,
      convertedToTaskId: convertedToTaskId ?? this.convertedToTaskId,
      convertedAt: clearConvertedAt
          ? null
          : (convertedAt ?? this.convertedAt),
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
