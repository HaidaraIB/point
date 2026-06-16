import 'package:point/Models/AttendanceDayOutcomeModel.dart';
import 'package:point/Models/AttendanceRecordModel.dart';
import 'package:point/Services/attendance_policy_settings.dart';

enum AttendanceDailyOutcome {
  none,
  pending,
  showedUp,
  absent,
  noCheckIn,
  noCheckout,
}

class AttendanceDayState {
  const AttendanceDayState({
    required this.presentRecord,
    required this.leftRecord,
    required this.systemOutcome,
    required this.outcome,
    required this.canPressPresent,
    required this.canPressLeft,
  });

  final AttendanceRecordModel? presentRecord;
  final AttendanceRecordModel? leftRecord;
  final AttendanceDayOutcomeModel? systemOutcome;
  final AttendanceDailyOutcome outcome;
  final bool canPressPresent;
  final bool canPressLeft;

  bool get isFinalized =>
      outcome == AttendanceDailyOutcome.absent ||
      outcome == AttendanceDailyOutcome.showedUp ||
      outcome == AttendanceDailyOutcome.noCheckIn ||
      outcome == AttendanceDailyOutcome.noCheckout;

  static String dateKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static String outcomeDocId(String employeeId, DateTime date) {
    return '${employeeId.trim()}_${dateKey(date)}';
  }

  static AttendanceRecordModel? findPresentRecord(
    List<AttendanceRecordModel> records,
  ) {
    for (final r in records) {
      if (r.isPresent) return r;
    }
    return null;
  }

  static AttendanceRecordModel? findLeftRecord(
    List<AttendanceRecordModel> records,
  ) {
    for (final r in records) {
      if (r.isLeft) return r;
    }
    return null;
  }

  /// Present was submitted today (pending or approved — not absent/auto-rejected).
  static bool hasPresentSubmitted(AttendanceRecordModel? present) {
    if (present == null) return false;
    return present.isPending || present.isApproved;
  }

  static bool hasWorkHoursConfigured(String? from, String? to) {
    return parseHHmm(from) != null && parseHHmm(to) != null;
  }

  static bool isWithinPresentWindow({
    required String? workHoursFrom,
    required int graceMinutes,
    required DateTime now,
  }) {
    final from = parseHHmm(workHoursFrom);
    if (from == null) return false;
    final minutes = _nowMinutes(now);
    return minutes >= from && minutes <= from + graceMinutes;
  }

  static bool isWithinLeftWindow({
    required String? workHoursTo,
    required int graceMinutes,
    required DateTime now,
  }) {
    final to = parseHHmm(workHoursTo);
    if (to == null) return false;
    final minutes = _nowMinutes(now);
    return minutes >= to && minutes <= to + graceMinutes;
  }

  static bool isBeforePresentWindow({
    required String? workHoursFrom,
    required DateTime now,
  }) {
    final from = parseHHmm(workHoursFrom);
    if (from == null) return false;
    return _nowMinutes(now) < from;
  }

  static bool isBeforeLeftWindow({
    required String? workHoursTo,
    required DateTime now,
  }) {
    final to = parseHHmm(workHoursTo);
    if (to == null) return false;
    return _nowMinutes(now) < to;
  }

  static bool isAfterPresentWindow({
    required String? workHoursFrom,
    required int graceMinutes,
    required DateTime now,
  }) {
    final from = parseHHmm(workHoursFrom);
    if (from == null) return false;
    return _nowMinutes(now) > from + graceMinutes;
  }

  static bool isAfterLeftWindow({
    required String? workHoursTo,
    required int graceMinutes,
    required DateTime now,
  }) {
    final to = parseHHmm(workHoursTo);
    if (to == null) return false;
    return _nowMinutes(now) > to + graceMinutes;
  }

  static AttendanceDayState compute({
    required List<AttendanceRecordModel> records,
    AttendanceDayOutcomeModel? systemOutcome,
    String? workHoursFrom,
    String? workHoursTo,
    AttendancePolicySettings policy = AttendancePolicySettings.defaults,
    DateTime? now,
    bool flexibleHours = false,
  }) {
    final present = findPresentRecord(records);
    final left = findLeftRecord(records);
    final clock = (now ?? DateTime.now()).toLocal();
    final workHoursOk = hasWorkHoursConfigured(workHoursFrom, workHoursTo);
    final presentSubmitted = hasPresentSubmitted(present);

    final bool canPressPresent;
    final bool canPressLeft;
    if (flexibleHours) {
      canPressPresent = present == null;
      canPressLeft = left == null && presentSubmitted;
    } else {
      canPressPresent = workHoursOk &&
          present == null &&
          isWithinPresentWindow(
            workHoursFrom: workHoursFrom,
            graceMinutes: policy.checkInGraceMinutes,
            now: clock,
          );
      canPressLeft = workHoursOk &&
          left == null &&
          presentSubmitted &&
          isWithinLeftWindow(
            workHoursTo: workHoursTo,
            graceMinutes: policy.checkOutGraceMinutes,
            now: clock,
          );
    }

    if (systemOutcome != null && systemOutcome.isAbsent) {
      final outcome = systemOutcome.isNoCheckIn
          ? AttendanceDailyOutcome.noCheckIn
          : systemOutcome.isNoCheckout
              ? AttendanceDailyOutcome.noCheckout
              : AttendanceDailyOutcome.absent;
      return AttendanceDayState(
        presentRecord: present,
        leftRecord: left,
        systemOutcome: systemOutcome,
        outcome: outcome,
        canPressPresent: false,
        canPressLeft: false,
      );
    }

    if (present != null &&
        present.isApproved &&
        left != null &&
        left.isApproved) {
      return AttendanceDayState(
        presentRecord: present,
        leftRecord: left,
        systemOutcome: systemOutcome,
        outcome: AttendanceDailyOutcome.showedUp,
        canPressPresent: false,
        canPressLeft: false,
      );
    }

    if (_hasAbsentOutcome(present, left)) {
      return AttendanceDayState(
        presentRecord: present,
        leftRecord: left,
        systemOutcome: systemOutcome,
        outcome: AttendanceDailyOutcome.absent,
        canPressPresent: false,
        canPressLeft: false,
      );
    }

    if (present?.isPending == true || left?.isPending == true) {
      return AttendanceDayState(
        presentRecord: present,
        leftRecord: left,
        systemOutcome: systemOutcome,
        outcome: AttendanceDailyOutcome.pending,
        canPressPresent: canPressPresent,
        canPressLeft: canPressLeft,
      );
    }

    if (present != null || left != null) {
      return AttendanceDayState(
        presentRecord: present,
        leftRecord: left,
        systemOutcome: systemOutcome,
        outcome: AttendanceDailyOutcome.pending,
        canPressPresent: canPressPresent,
        canPressLeft: canPressLeft,
      );
    }

    return AttendanceDayState(
      presentRecord: null,
      leftRecord: null,
      systemOutcome: systemOutcome,
      outcome: AttendanceDailyOutcome.none,
      canPressPresent: canPressPresent,
      canPressLeft: canPressLeft,
    );
  }

  static bool _hasAbsentOutcome(
    AttendanceRecordModel? present,
    AttendanceRecordModel? left,
  ) {
    for (final record in [present, left]) {
      if (record == null) continue;
      if (record.isAbsent || record.isAutoRejectedLate) return true;
    }
    return false;
  }

  static int _nowMinutes(DateTime now) => now.hour * 60 + now.minute;

  static int? parseHHmm(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.length != 5 || trimmed[2] != ':') {
      return null;
    }
    final hour = int.tryParse(trimmed.substring(0, 2));
    final minute = int.tryParse(trimmed.substring(3, 5));
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }
}

