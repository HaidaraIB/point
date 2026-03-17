import 'package:point/Models/ContentWriteModel.dart';
import 'package:point/Models/DesignTaskModel.dart';
import 'package:point/Models/MonatageModel.dart';
import 'package:point/Models/PhotographyModel.dart';
import 'package:point/Models/ProgrammingModel.dart';
import 'package:point/Models/PromotionModel.dart';
import 'package:point/Models/PublishModel.dart';

class TaskModel {
  String? id; // لإضافة معرف المستند من Firestore
  final String title;
  final String description;
  final String status; // مثل: "قيد التنفيذ"
  final String priority; // مثل: "مهم جدًا"
  double? progress; // مثل: 0.4
  final DateTime fromDate;
  final DateTime toDate;
  final String assignedTo;
  final String clientName;
  final String assignedImageUrl;
  final String actionText;
  final String type;
  DesignTaskModel? designDetails;
  ContentWriteModel? contentWriteModel;
  PhotographyModel? photoGrapghyModel;
  MonatageModel? monatageModel;
  PublishModel? publishModel;
  PromotionModel? promotionModel;
  ProgrammingModel? programmingModel;
  final List<dynamic> files;
  final List<NoteModel> notes;
  final List<TaskTimelineEvent> timelineEvents;

  TaskModel({
    this.id,
    required this.title,
    required this.description,
    required this.status,

    required this.priority,
    this.progress,
    required this.fromDate,
    required this.toDate,
    required this.assignedTo,
    required this.clientName,
    required this.assignedImageUrl,
    required this.actionText,
    required this.type,
    this.designDetails,
    this.contentWriteModel,
    this.photoGrapghyModel,
    this.monatageModel,
    this.publishModel,
    this.promotionModel,
    this.programmingModel,
    this.notes = const [],
    this.files = const [],
    this.timelineEvents = const [],
  });

  // ✅ fromJson
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      priority: json['priority'] ?? '',
      progress:
          (json['progress'] != null)
              ? (json['progress'] as num).toDouble()
              : null,
      fromDate: DateTime.tryParse(json['fromDate'] ?? '') ?? DateTime.now(),
      toDate: DateTime.tryParse(json['toDate'] ?? '') ?? DateTime.now(),
      assignedTo: json['assignedTo'] ?? '',
      clientName: json['clientName'] ?? '',
      assignedImageUrl: json['assignedImageUrl'] ?? '',
      actionText: json['actionText'] ?? '',
      type: json['type'] ?? '',
      designDetails:
          json['designDetails'] != null
              ? DesignTaskModel.fromJson(json['designDetails'])
              : null,
      contentWriteModel:
          json['contentWriteModel'] != null
              ? ContentWriteModel.fromJson(json['contentWriteModel'])
              : null,
      photoGrapghyModel:
          json['photoGrapghyModel'] != null
              ? PhotographyModel.fromJson(json['photoGrapghyModel'])
              : null,
      monatageModel:
          json['monatageModel'] != null
              ? MonatageModel.fromJson(json['monatageModel'])
              : null,
      publishModel:
          json['publishModel'] != null
              ? PublishModel.fromJson(json['publishModel'])
              : null,
      promotionModel:
          json['promotionModel'] != null
              ? PromotionModel.fromJson(json['promotionModel'])
              : null,
      programmingModel:
          json['programmingModel'] != null
              ? ProgrammingModel.fromJson(json['programmingModel'])
              : null,
      files:
          (json['files'] != null)
              ? List<String>.from(json['files'])
              : <String>[], // 🆕
      notes:
          json['notes'] != null
              ? List<Map<String, dynamic>>.from(
                json['notes'],
              ).map((e) => NoteModel.fromJson(e)).toList()
              : [],
      timelineEvents:
          json['timelineEvents'] != null
              ? List<Map<String, dynamic>>.from(json['timelineEvents'])
                  .map((e) => TaskTimelineEvent.fromJson(e))
                  .toList()
              : [],
    );
  }

  // ✅ toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,

      'progress': progress,
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'assignedTo': assignedTo,
      'clientName': clientName,
      'assignedImageUrl': assignedImageUrl,
      'actionText': actionText,
      'type': type,
      'designDetails': designDetails?.toJson(),
      'contentWriteModel': contentWriteModel?.toJson(),
      'photoGrapghyModel': photoGrapghyModel?.toJson(),
      'publishModel': publishModel?.toJson(),
      'programmingModel': programmingModel?.toJson(),
      'monatageModel': monatageModel?.toJson(),
      'promotionModel': promotionModel?.toJson(),
      'files': files,
      'notes': notes.map((e) => e.toJson()).toList(),
      'timelineEvents': timelineEvents.map((e) => e.toJson()).toList(),
    };
  }

  // ✅ copyWith
  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? priority,
    double? progress,
    DateTime? fromDate,
    DateTime? toDate,
    String? assignedTo,
    String? clientName,
    String? assignedImageUrl,
    String? actionText,
    String? type,
    DesignTaskModel? designDetails,
    ContentWriteModel? contentWriteModel,
    PhotographyModel? photoGrapghyModel,
    MonatageModel? monatageModel,
    PublishModel? publishModel,
    List<dynamic>? files,
    PromotionModel? promotionModel,
    ProgrammingModel? programmingModel,
    List<NoteModel>? notes,
    List<TaskTimelineEvent>? timelineEvents,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      assignedTo: assignedTo ?? this.assignedTo,
      clientName: clientName ?? this.clientName,
      assignedImageUrl: assignedImageUrl ?? this.assignedImageUrl,
      actionText: actionText ?? this.actionText,
      type: type ?? this.type,
      designDetails: designDetails ?? this.designDetails,
      contentWriteModel: contentWriteModel ?? this.contentWriteModel,
      photoGrapghyModel: photoGrapghyModel ?? this.photoGrapghyModel,
      monatageModel: monatageModel ?? this.monatageModel,
      publishModel: publishModel ?? this.publishModel,
      promotionModel: promotionModel ?? this.promotionModel,
      programmingModel: programmingModel ?? this.programmingModel,
      files: files ?? this.files,
      notes: notes ?? this.notes,
      timelineEvents: timelineEvents ?? this.timelineEvents,
    );
  }
}

/// حدث في الجدول الزمني للمهمة
class TaskTimelineEvent {
  final String type;
  final String label;
  final String? oldValue;
  final String? newValue;
  final String byUserId;
  final String byUserName;
  final DateTime timestamp;
  /// مفتاح الحقل للتصفية أو التحليلات (مثل: title, designDetails.designType)
  final String? fieldKey;

  TaskTimelineEvent({
    required this.type,
    required this.label,
    this.oldValue,
    this.newValue,
    required this.byUserId,
    required this.byUserName,
    required this.timestamp,
    this.fieldKey,
  });

  factory TaskTimelineEvent.fromJson(Map<String, dynamic> json) {
    return TaskTimelineEvent(
      type: json['type'] ?? '',
      label: json['label'] ?? '',
      oldValue: json['oldValue'] as String?,
      newValue: json['newValue'] as String?,
      byUserId: json['byUserId'] ?? '',
      byUserName: json['byUserName'] ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      fieldKey: json['fieldKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'label': label,
      'oldValue': oldValue,
      'newValue': newValue,
      'byUserId': byUserId,
      'byUserName': byUserName,
      'timestamp': timestamp.toIso8601String(),
      if (fieldKey != null) 'fieldKey': fieldKey,
    };
  }
}

class NoteModel {
  final String note;
  final String byWho;
  final DateTime timestamp;

  NoteModel({required this.note, required this.byWho, required this.timestamp});

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      note: json['note'] ?? '',
      byWho: json['byWho'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'note': note,
      'byWho': byWho,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
