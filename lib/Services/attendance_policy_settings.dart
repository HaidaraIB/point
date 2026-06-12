import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Utils/app_log.dart';

/// Admin-editable grace windows for auto-absent attendance rules.
/// Stored in Firestore `app_settings/attendance_policy`.
class AttendancePolicySettings {
  const AttendancePolicySettings({
    required this.checkInGraceMinutes,
    required this.checkOutGraceMinutes,
  });

  final int checkInGraceMinutes;
  final int checkOutGraceMinutes;

  static const String documentPath = 'app_settings/attendance_policy';
  static const int defaultGraceMinutes = 60;
  static const int minGraceMinutes = 5;
  static const int maxGraceMinutes = 480;

  static const AttendancePolicySettings defaults = AttendancePolicySettings(
    checkInGraceMinutes: defaultGraceMinutes,
    checkOutGraceMinutes: defaultGraceMinutes,
  );

  static Future<AttendancePolicySettings> load() async {
    final snap = await FirebaseFirestore.instance.doc(documentPath).get();
    if (!snap.exists) return defaults;
    final data = snap.data();
    if (data == null) return defaults;

    return AttendancePolicySettings(
      checkInGraceMinutes: _clampGrace(
        _asInt(data['checkInGraceMinutes']) ?? defaultGraceMinutes,
      ),
      checkOutGraceMinutes: _clampGrace(
        _asInt(data['checkOutGraceMinutes']) ?? defaultGraceMinutes,
      ),
    );
  }

  static Future<void> save({
    required int checkInGraceMinutes,
    required int checkOutGraceMinutes,
  }) async {
    final data = <String, dynamic>{
      'checkInGraceMinutes': _clampGrace(checkInGraceMinutes),
      'checkOutGraceMinutes': _clampGrace(checkOutGraceMinutes),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.doc(documentPath).set(data);
    } catch (e, s) {
      appLog('AttendancePolicySettings.save failed: $e', error: e, stackTrace: s);
      rethrow;
    }
  }

  static int _clampGrace(int value) {
    return value.clamp(minGraceMinutes, maxGraceMinutes);
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
