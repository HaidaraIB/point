import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/AttendanceRecordModel.dart';
import 'package:point/Utils/app_log.dart';
import 'package:uuid/uuid.dart';

/// Firestore API for GPS attendance records.
class FirestoreAttendanceApi {
  FirestoreAttendanceApi._();

  static const String collectionName = 'attendance_records';
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

  static String? todayLastAction(List<AttendanceRecordModel> records) {
    if (records.isEmpty) return null;
    return records.first.action;
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
      'recordedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(_uuid.v4())
          .set(data);
    } catch (e, s) {
      appLog('recordAttendance failed: $e', error: e, stackTrace: s);
      rethrow;
    }
  }
}
