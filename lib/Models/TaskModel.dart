import 'package:point/Models/ContentWriteModel.dart';
import 'package:point/Models/DesignTaskModel.dart';
import 'package:point/Models/MontageModel.dart';
import 'package:point/Models/PhotographyModel.dart';
import 'package:point/Models/ProgrammingModel.dart';
import 'package:point/Models/PromotionModel.dart';
import 'package:point/Models/PublishModel.dart';

/// خرائط Firestore على الويب قد تكون كائنات JS وليست [Map] دارتية؛
/// [Map.from] يحوّلها حتى يعمل المشغّل [] في النماذج الفرعية.
Map<String, dynamic> _mapFromFirestoreNested(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

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
  /// نص اختياري للتسليم النهائي عند الإرسال للمراجعة.
  final String finalDeliverableText;
  /// روابط مرفقات التسليم النهائي (بعد الرفع إلى التخزين).
  final List<String> finalDeliverableFileUrls;
  final List<NoteModel> notes;
  final List<TaskTimelineEvent> timelineEvents;
  /// طابع ISO لآخر إشعار «قبل 24 ساعة» (يحدّث من scheduled-notifications).
  final String? dueSoonNotifiedAt24h;
  /// طابع ISO لآخر إشعار «قبل 6 ساعات».
  final String? dueSoonNotifiedAt6h;
  /// طابع ISO لآخر إشعار «قبل ساعة» من التسليم (Cron).
  final String? dueSoonNotifiedAt1h;
  /// طابع ISO لآخر إشعار متابعة «≤12 ساعة» من التسليم (Cron).
  final String? dueSoonNotifiedAt12h;
  /// طابع ISO لتذكير تأخر البدء (مهمة لم تبدأ بعد `fromDate`) — كحد أقصى كل 24 ساعة.
  final String? startReminderNotifiedAt;
  /// طابع ISO لإشعار «عدم تحديث» للموظف (لا نشاط في الجدول الزمني لفترة).
  final String? staleUpdateNotifiedAt;
  /// طابع ISO لإشعار التأخر للموظف المكلّف (بعد تجاوز `toDate`) — كحد أقصى يومياً.
  final String? overdueEmployeeNotifiedAt;
  /// بتات عتبات التقدم المُرسل إشعارها: 32 = 25٪، 64 = 50٪، 128 = 75٪، 256 = 100٪.
  /// القيم 1–31 قديمة — تُحوَّل تلقائياً عند القراءة في [parseProgressMilestoneMask].
  final String? progressMilestoneMask;
  /// بتات تذكيرات التقدّم عبر Cron: [kProgressReminder0] = 0٪، ثم 32|64|128|256 كما في العتبات.
  /// يُحدَّث من [scheduled-notifications] فقط لمنع تكرار التذكير لنفس العتبة.
  final String? progressReminderSentMask;
  /// طابع ISO لتحذير الإدارة: لم يبدأ الموظف بعد `fromDate` + 48 ساعة.
  final String? managerNoActionNotifiedAt;
  /// طابع ISO لتحذير الإدارة: توقف التقدم (لا نشاط 72 ساعة).
  final String? managerStalledNotifiedAt;
  /// طابع ISO لتذكير الموظف: المهمة قيد التنفيذ لكن لا تقدم مسجّل بعد.
  final String? noProgressRemindedAt;

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
    this.finalDeliverableText = '',
    this.finalDeliverableFileUrls = const [],
    this.timelineEvents = const [],
    this.dueSoonNotifiedAt24h,
    this.dueSoonNotifiedAt6h,
    this.dueSoonNotifiedAt1h,
    this.dueSoonNotifiedAt12h,
    this.startReminderNotifiedAt,
    this.staleUpdateNotifiedAt,
    this.overdueEmployeeNotifiedAt,
    this.progressMilestoneMask,
    this.progressReminderSentMask,
    this.managerNoActionNotifiedAt,
    this.managerStalledNotifiedAt,
    this.noProgressRemindedAt,
  });

  /// قيمة عددية لـ [progressMilestoneMask]؛ يُحوَّل الترميز القديم (1–31) إلى 32|64|128|256.
  static int parseProgressMilestoneMask(dynamic raw) {
    final v = _parseProgressMilestoneMaskRaw(raw);
    return migrateLegacyProgressMilestoneMask(v);
  }

  static int _parseProgressMilestoneMaskRaw(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw.clamp(0, 511);
    if (raw is num) return raw.toInt().clamp(0, 511);
    final s = raw.toString().trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s)?.clamp(0, 511) ?? 0;
  }

  /// ترميز جديد: [kMilestone25]…[kMilestone100]. ترميم قديم من 1–31 (بدء/25/50/75/95٪).
  static const int kMilestone25 = 32;
  static const int kMilestone50 = 64;
  static const int kMilestone75 = 128;
  static const int kMilestone100 = 256;
  /// تذكير Cron لعتبة 0٪ (لا يُستخدم في [progressMilestoneMask] القديم).
  static const int kProgressReminder0 = 1;
  static const int _kMilestoneMaskNew =
      kMilestone25 | kMilestone50 | kMilestone75 | kMilestone100;

  static int migrateLegacyProgressMilestoneMask(int raw) {
    if (raw <= 0) return 0;
    if (raw & _kMilestoneMaskNew != 0) return raw & _kMilestoneMaskNew;
    var n = 0;
    if (raw & 2 != 0) n |= kMilestone25;
    if (raw & 4 != 0) n |= kMilestone50;
    if (raw & 8 != 0) n |= kMilestone75;
    if (raw & 16 != 0) n |= kMilestone100;
    return n;
  }

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
              ? DesignTaskModel.fromJson(
                  _mapFromFirestoreNested(json['designDetails']),
                )
              : null,
      contentWriteModel:
          json['contentWriteModel'] != null
              ? ContentWriteModel.fromJson(
                  _mapFromFirestoreNested(json['contentWriteModel']),
                )
              : null,
      photoGrapghyModel:
          json['photoGrapghyModel'] != null
              ? PhotographyModel.fromJson(
                  _mapFromFirestoreNested(json['photoGrapghyModel']),
                )
              : null,
      monatageModel:
          json['monatageModel'] != null
              ? MonatageModel.fromJson(
                  _mapFromFirestoreNested(json['monatageModel']),
                )
              : null,
      publishModel:
          json['publishModel'] != null
              ? PublishModel.fromJson(
                  _mapFromFirestoreNested(json['publishModel']),
                )
              : null,
      promotionModel:
          json['promotionModel'] != null
              ? PromotionModel.fromJson(
                  _mapFromFirestoreNested(json['promotionModel']),
                )
              : null,
      programmingModel:
          json['programmingModel'] != null
              ? ProgrammingModel.fromJson(
                  _mapFromFirestoreNested(json['programmingModel']),
                )
              : null,
      files:
          (json['files'] != null)
              ? List<String>.from(json['files'])
              : <String>[], // 🆕
      finalDeliverableText: json['finalDeliverableText']?.toString() ?? '',
      finalDeliverableFileUrls:
          json['finalDeliverableFileUrls'] != null
              ? List<String>.from(json['finalDeliverableFileUrls'] as List)
              : <String>[],
      notes:
          json['notes'] != null
              ? (json['notes'] as List)
                  .map((e) => NoteModel.fromJson(_mapFromFirestoreNested(e)))
                  .toList()
              : [],
      timelineEvents:
          json['timelineEvents'] != null
              ? (json['timelineEvents'] as List)
                  .map((e) => TaskTimelineEvent.fromJson(_mapFromFirestoreNested(e)))
                  .toList()
              : [],
      dueSoonNotifiedAt24h: json['dueSoonNotifiedAt24h'] as String?,
      dueSoonNotifiedAt6h: json['dueSoonNotifiedAt6h'] as String?,
      dueSoonNotifiedAt1h: json['dueSoonNotifiedAt1h'] as String?,
      dueSoonNotifiedAt12h: json['dueSoonNotifiedAt12h'] as String?,
      startReminderNotifiedAt: json['startReminderNotifiedAt'] as String?,
      staleUpdateNotifiedAt: json['staleUpdateNotifiedAt'] as String?,
      overdueEmployeeNotifiedAt: json['overdueEmployeeNotifiedAt'] as String?,
      progressMilestoneMask: json['progressMilestoneMask'] != null
          ? json['progressMilestoneMask'].toString()
          : null,
      progressReminderSentMask: json['progressReminderSentMask'] != null
          ? json['progressReminderSentMask'].toString()
          : null,
      managerNoActionNotifiedAt: json['managerNoActionNotifiedAt'] as String?,
      managerStalledNotifiedAt: json['managerStalledNotifiedAt'] as String?,
      noProgressRemindedAt: json['noProgressRemindedAt'] as String?,
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
      'finalDeliverableText': finalDeliverableText,
      'finalDeliverableFileUrls': finalDeliverableFileUrls,
      'notes': notes.map((e) => e.toJson()).toList(),
      'timelineEvents': timelineEvents.map((e) => e.toJson()).toList(),
      if (dueSoonNotifiedAt24h != null)
        'dueSoonNotifiedAt24h': dueSoonNotifiedAt24h,
      if (dueSoonNotifiedAt6h != null)
        'dueSoonNotifiedAt6h': dueSoonNotifiedAt6h,
      if (dueSoonNotifiedAt1h != null)
        'dueSoonNotifiedAt1h': dueSoonNotifiedAt1h,
      if (dueSoonNotifiedAt12h != null)
        'dueSoonNotifiedAt12h': dueSoonNotifiedAt12h,
      if (startReminderNotifiedAt != null)
        'startReminderNotifiedAt': startReminderNotifiedAt,
      if (staleUpdateNotifiedAt != null)
        'staleUpdateNotifiedAt': staleUpdateNotifiedAt,
      if (overdueEmployeeNotifiedAt != null)
        'overdueEmployeeNotifiedAt': overdueEmployeeNotifiedAt,
      if (progressMilestoneMask != null)
        'progressMilestoneMask': progressMilestoneMask,
      if (progressReminderSentMask != null)
        'progressReminderSentMask': progressReminderSentMask,
      if (managerNoActionNotifiedAt != null)
        'managerNoActionNotifiedAt': managerNoActionNotifiedAt,
      if (managerStalledNotifiedAt != null)
        'managerStalledNotifiedAt': managerStalledNotifiedAt,
      if (noProgressRemindedAt != null)
        'noProgressRemindedAt': noProgressRemindedAt,
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
    String? finalDeliverableText,
    List<String>? finalDeliverableFileUrls,
    PromotionModel? promotionModel,
    ProgrammingModel? programmingModel,
    List<NoteModel>? notes,
    List<TaskTimelineEvent>? timelineEvents,
    String? dueSoonNotifiedAt24h,
    String? dueSoonNotifiedAt6h,
    String? dueSoonNotifiedAt1h,
    String? dueSoonNotifiedAt12h,
    String? startReminderNotifiedAt,
    String? staleUpdateNotifiedAt,
    String? overdueEmployeeNotifiedAt,
    String? progressMilestoneMask,
    String? progressReminderSentMask,
    String? managerNoActionNotifiedAt,
    String? managerStalledNotifiedAt,
    String? noProgressRemindedAt,
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
      finalDeliverableText:
          finalDeliverableText ?? this.finalDeliverableText,
      finalDeliverableFileUrls:
          finalDeliverableFileUrls ?? this.finalDeliverableFileUrls,
      notes: notes ?? this.notes,
      timelineEvents: timelineEvents ?? this.timelineEvents,
      dueSoonNotifiedAt24h:
          dueSoonNotifiedAt24h ?? this.dueSoonNotifiedAt24h,
      dueSoonNotifiedAt6h: dueSoonNotifiedAt6h ?? this.dueSoonNotifiedAt6h,
      dueSoonNotifiedAt1h: dueSoonNotifiedAt1h ?? this.dueSoonNotifiedAt1h,
      dueSoonNotifiedAt12h:
          dueSoonNotifiedAt12h ?? this.dueSoonNotifiedAt12h,
      startReminderNotifiedAt:
          startReminderNotifiedAt ?? this.startReminderNotifiedAt,
      staleUpdateNotifiedAt:
          staleUpdateNotifiedAt ?? this.staleUpdateNotifiedAt,
      overdueEmployeeNotifiedAt:
          overdueEmployeeNotifiedAt ?? this.overdueEmployeeNotifiedAt,
      progressMilestoneMask:
          progressMilestoneMask ?? this.progressMilestoneMask,
      progressReminderSentMask:
          progressReminderSentMask ?? this.progressReminderSentMask,
      managerNoActionNotifiedAt:
          managerNoActionNotifiedAt ?? this.managerNoActionNotifiedAt,
      managerStalledNotifiedAt:
          managerStalledNotifiedAt ?? this.managerStalledNotifiedAt,
      noProgressRemindedAt:
          noProgressRemindedAt ?? this.noProgressRemindedAt,
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
