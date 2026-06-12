import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/AttendanceDayOutcomeModel.dart';
import 'package:point/Models/AttendanceRecordModel.dart';
import 'package:point/Services/attendance_day_state.dart';
import 'package:point/Services/attendance_policy_settings.dart';
import 'package:point/Utils/app_log.dart';
import 'package:uuid/uuid.dart';

/// Thrown when [recordAttendance] is rejected by business rules.
class AttendanceRecordRejectedException implements Exception {
  AttendanceRecordRejectedException(this.messageKey);

  final String messageKey;

  @override
  String toString() => messageKey;
}

/// Firestore API for GPS attendance records.
class FirestoreAttendanceApi {
  FirestoreAttendanceApi._();

  static const String collectionName = 'attendance_records';
  static const String dayOutcomesCollection = 'attendance_day_outcomes';
  static const _uuid = Uuid();

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime endOfDay(DateTime date) {
    return startOfDay(date).add(const Duration(days: 1));
  }

  static Stream<List<AttendanceRecordModel>> streamTodayRecordsForEmployee(
    String employeeId,
  ) {
    final id = employeeId.trim();
    if (id.isEmpty) return Stream.value(const []);

    final now = DateTime.now();
    final start = Timestamp.fromDate(startOfDay(now));
    final end = Timestamp.fromDate(endOfDay(now));

    return FirebaseFirestore.instance
        .collection(collectionName)
        .where('employeeId', isEqualTo: id)
        .where('recordedAt', isGreaterThanOrEqualTo: start)
        .where('recordedAt', isLessThan: end)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map(_mapSnapshot);
  }

  static Stream<AttendanceDayOutcomeModel?> streamTodayOutcomeForEmployee(
    String employeeId,
  ) {
    final id = employeeId.trim();
    if (id.isEmpty) return Stream.value(null);

    final docId = AttendanceDayState.outcomeDocId(id, DateTime.now());
    return FirebaseFirestore.instance
        .collection(dayOutcomesCollection)
        .doc(docId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return AttendanceDayOutcomeModel.fromJson(data, id: snap.id);
    });
  }

  static Stream<List<AttendanceRecordModel>> streamRecordsForDate(
    DateTime date,
  ) {
    final start = Timestamp.fromDate(startOfDay(date));
    final end = Timestamp.fromDate(endOfDay(date));

    return FirebaseFirestore.instance
        .collection(collectionName)
        .where('recordedAt', isGreaterThanOrEqualTo: start)
        .where('recordedAt', isLessThan: end)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map(_mapSnapshot);
  }

  static Future<List<AttendanceRecordModel>> fetchRecordsForRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection(collectionName)
        .where(
          'recordedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive),
        )
        .where(
          'recordedAt',
          isLessThan: Timestamp.fromDate(endExclusive),
        )
        .orderBy('recordedAt', descending: false)
        .get();
    return _mapSnapshot(snap);
  }

  static Future<List<AttendanceDayOutcomeModel>> fetchOutcomesForRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final startKey = AttendanceDayState.dateKey(startInclusive);
    final endKey = AttendanceDayState.dateKey(
      endExclusive.subtract(const Duration(days: 1)),
    );

    final snap = await FirebaseFirestore.instance
        .collection(dayOutcomesCollection)
        .where('dateKey', isGreaterThanOrEqualTo: startKey)
        .where('dateKey', isLessThanOrEqualTo: endKey)
        .get();

    return snap.docs
        .map(
          (doc) => AttendanceDayOutcomeModel.fromJson(
            doc.data(),
            id: doc.id,
          ),
        )
        .toList();
  }

  static Future<List<AttendanceDayOutcomeModel>> fetchOutcomesForDate(
    DateTime date,
  ) async {
    final key = AttendanceDayState.dateKey(date);
    final snap = await FirebaseFirestore.instance
        .collection(dayOutcomesCollection)
        .where('dateKey', isEqualTo: key)
        .get();
    return snap.docs
        .map(
          (doc) => AttendanceDayOutcomeModel.fromJson(
            doc.data(),
            id: doc.id,
          ),
        )
        .toList();
  }

  static Stream<List<AttendanceRecordModel>> streamPendingRecords() {
    return FirebaseFirestore.instance
        .collection(collectionName)
        .where('approvalStatus', isEqualTo: AttendanceRecordModel.statusPending)
        .orderBy('recordedAt', descending: true)
        .limit(200)
        .snapshots()
        .map(_mapSnapshot);
  }

  static Stream<int> streamPendingCount() {
    return streamPendingRecords().map((records) => records.length);
  }

  static bool _isRecordedOnDay(DateTime? recordedAt, DateTime day) {
    if (recordedAt == null) return false;
    final local = recordedAt.toLocal();
    return local.year == day.year &&
        local.month == day.month &&
        local.day == day.day;
  }

  static List<AttendanceRecordModel> _filterRecordsForDay(
    List<AttendanceRecordModel> records,
    DateTime day,
  ) {
    return records
        .where((r) => _isRecordedOnDay(r.recordedAt, day))
        .toList();
  }

  static List<AttendanceRecordModel> _mapSnapshot(QuerySnapshot snap) {
    return snap.docs
        .map(
          (doc) => AttendanceRecordModel.fromJson(
            doc.data() as Map<String, dynamic>,
            id: doc.id,
          ),
        )
        .toList();
  }

  /// Latest record that blocks new actions (pending review).
  static AttendanceRecordModel? latestBlockingRecord(
    List<AttendanceRecordModel> records,
  ) {
    if (records.isEmpty) return null;
    final latest = records.first;
    if (latest.isPending) return latest;
    return null;
  }

  /// Last approved action for Present/Left sequencing.
  static String? todayLastApprovedAction(List<AttendanceRecordModel> records) {
    for (final r in records) {
      if (r.isApproved) return r.action;
    }
    return null;
  }

  static String? todayLastAction(List<AttendanceRecordModel> records) {
    return todayLastApprovedAction(records);
  }

  static Future<void> recordAttendance({
    required String employeeId,
    required String employeeName,
    required String action,
    required double latitude,
    required double longitude,
    required double distanceMeters,
    required double officeLatitude,
    required double officeLongitude,
    required double officeRadiusMeters,
    required String photoUrl,
  }) async {
    final id = employeeId.trim();
    if (id.isEmpty) return;

    final now = DateTime.now();

    final employeeSnap = await FirebaseFirestore.instance
        .collection('employees')
        .doc(id)
        .get();
    final employeeData = employeeSnap.data();
    final workHoursFrom = employeeData?['workHoursFrom']?.toString();
    final workHoursTo = employeeData?['workHoursTo']?.toString();

    if (!AttendanceDayState.hasWorkHoursConfigured(workHoursFrom, workHoursTo)) {
      throw AttendanceRecordRejectedException(
        'attendance.work_hours_not_configured',
      );
    }

    final policy = await AttendancePolicySettings.load();

    if (action == AttendanceRecordModel.actionPresent) {
      if (!AttendanceDayState.isWithinPresentWindow(
        workHoursFrom: workHoursFrom,
        graceMinutes: policy.checkInGraceMinutes,
        now: now,
      )) {
        throw AttendanceRecordRejectedException(
          'attendance.outside_present_window',
        );
      }
    } else if (action == AttendanceRecordModel.actionLeft) {
      if (!AttendanceDayState.isWithinLeftWindow(
        workHoursTo: workHoursTo,
        graceMinutes: policy.checkOutGraceMinutes,
        now: now,
      )) {
        throw AttendanceRecordRejectedException(
          'attendance.outside_left_window',
        );
      }
    }

    List<AttendanceRecordModel> todayRecords;
    try {
      // Single-field query (employeeId) — no composite index required; filter
      // today's rows in memory (each employee has at most a few records/day).
      final todaySnap = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('employeeId', isEqualTo: id)
          .get();
      todayRecords = _filterRecordsForDay(_mapSnapshot(todaySnap), now);
    } catch (e, s) {
      appLog('recordAttendance today query failed: $e', error: e, stackTrace: s);
      rethrow;
    }

    if (action == AttendanceRecordModel.actionPresent) {
      if (AttendanceDayState.findPresentRecord(todayRecords) != null) {
        throw AttendanceRecordRejectedException(
          'attendance.already_pressed_present',
        );
      }
    } else if (action == AttendanceRecordModel.actionLeft) {
      if (AttendanceDayState.findLeftRecord(todayRecords) != null) {
        throw AttendanceRecordRejectedException(
          'attendance.already_pressed_left',
        );
      }
    }

    final dayState = AttendanceDayState.compute(
      records: todayRecords,
      workHoursFrom: workHoursFrom,
      workHoursTo: workHoursTo,
      policy: policy,
      now: now,
    );
    if (dayState.outcome == AttendanceDailyOutcome.showedUp) {
      throw AttendanceRecordRejectedException('attendance.day_complete');
    }

    final data = <String, dynamic>{
      'employeeId': id,
      'employeeName': employeeName.trim(),
      'action': action,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'officeLatitude': officeLatitude,
      'officeLongitude': officeLongitude,
      'officeRadiusMeters': officeRadiusMeters,
      'photoUrl': photoUrl.trim(),
      'approvalStatus': AttendanceRecordModel.statusPending,
      'recordedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(_uuid.v4())
          .set(data);
    } catch (e, s) {
      appLog('recordAttendance write failed: $e', error: e, stackTrace: s);
      rethrow;
    }
  }

  static Future<void> reviewAttendanceRecord({
    required String recordId,
    required bool approved,
    required String reviewerEmployeeId,
    required String reviewerName,
  }) async {
    final id = recordId.trim();
    if (id.isEmpty) return;

    await FirebaseFirestore.instance.collection(collectionName).doc(id).update({
      'approvalStatus': approved
          ? AttendanceRecordModel.statusApproved
          : AttendanceRecordModel.statusAbsent,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedByEmployeeId': reviewerEmployeeId.trim(),
      'reviewedByName': reviewerName.trim(),
    });
  }
}
