import 'package:point/Models/AttendanceDayOutcomeModel.dart';
import 'package:point/Models/AttendanceRecordModel.dart';
import 'package:point/Services/attendance_day_state.dart';
import 'package:point/Services/attendance_policy_settings.dart';

class AttendanceReportRow {
  const AttendanceReportRow({
    required this.employeeId,
    required this.employeeName,
    required this.showedUpDays,
    required this.absentDays,
    required this.pendingDays,
  });

  final String employeeId;
  final String employeeName;
  final int showedUpDays;
  final int absentDays;
  final int pendingDays;
}

class AttendanceReportService {
  AttendanceReportService._();

  static List<AttendanceReportRow> aggregate({
    required List<AttendanceRecordModel> records,
    required List<AttendanceDayOutcomeModel> outcomes,
    Map<String, String>? employeeNames,
    Map<String, ({String? workHoursFrom, String? workHoursTo})>? employeeWorkHours,
    AttendancePolicySettings policy = AttendancePolicySettings.defaults,
  }) {
    final recordsByEmployeeDay = <String, List<AttendanceRecordModel>>{};
    for (final r in records) {
      if (r.employeeId.isEmpty || r.recordedAt == null) continue;
      final key = _employeeDayKey(r.employeeId, r.recordedAt!);
      recordsByEmployeeDay.putIfAbsent(key, () => []).add(r);
    }

    final outcomesByEmployeeDay = <String, AttendanceDayOutcomeModel>{};
    for (final o in outcomes) {
      if (o.employeeId.isEmpty || o.dateKey.isEmpty) continue;
      outcomesByEmployeeDay['${o.employeeId}_${o.dateKey}'] = o;
    }

    final allKeys = {
      ...recordsByEmployeeDay.keys,
      ...outcomesByEmployeeDay.keys,
    };

    final byEmployee = <String, AttendanceReportRow>{};

    for (final key in allKeys) {
      final parsed = _parseEmployeeDayKey(key);
      if (parsed == null) continue;
      final employeeId = parsed.$1;
      final dateKey = parsed.$2;

      final dayRecords = recordsByEmployeeDay[key] ?? const [];
      final systemOutcome = outcomesByEmployeeDay[key];
      final workHours = employeeWorkHours?[employeeId];

      final dayState = AttendanceDayState.compute(
        records: dayRecords,
        systemOutcome: systemOutcome,
        workHoursFrom: workHours?.workHoursFrom,
        workHoursTo: workHours?.workHoursTo,
        policy: policy,
        now: _endOfDayFromKey(dateKey),
      );

      final name = employeeNames?[employeeId] ??
          (dayRecords.isNotEmpty ? dayRecords.first.employeeName : employeeId);

      final existing = byEmployee[employeeId];
      var showedUp = existing?.showedUpDays ?? 0;
      var absent = existing?.absentDays ?? 0;
      var pending = existing?.pendingDays ?? 0;

      switch (dayState.outcome) {
        case AttendanceDailyOutcome.showedUp:
          showedUp++;
        case AttendanceDailyOutcome.absent:
        case AttendanceDailyOutcome.noCheckIn:
        case AttendanceDailyOutcome.noCheckout:
          absent++;
        case AttendanceDailyOutcome.pending:
          pending++;
        case AttendanceDailyOutcome.none:
          break;
      }

      byEmployee[employeeId] = AttendanceReportRow(
        employeeId: employeeId,
        employeeName: existing?.employeeName ?? name,
        showedUpDays: showedUp,
        absentDays: absent,
        pendingDays: pending,
      );
    }

    return byEmployee.values.toList()
      ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
  }

  static String _employeeDayKey(String employeeId, DateTime recordedAt) {
    return '${employeeId.trim()}_${AttendanceDayState.dateKey(recordedAt)}';
  }

  static (String, String)? _parseEmployeeDayKey(String key) {
    if (key.length <= 11) return null;
    final separatorIndex = key.length - 11;
    if (key[separatorIndex] != '_') return null;
    final dateKey = key.substring(separatorIndex + 1);
    if (dateKey.length != 10 || dateKey[4] != '-' || dateKey[7] != '-') {
      return null;
    }
    return (key.substring(0, separatorIndex), dateKey);
  }

  static DateTime _endOfDayFromKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return DateTime.now();
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    final day = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(year, month, day, 23, 59);
  }

  static String toCsv(List<AttendanceReportRow> rows, List<String> headers) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCsv).join(','));
    for (final row in rows) {
      buffer.writeln([
        row.employeeName,
        row.showedUpDays,
        row.absentDays,
        row.pendingDays,
      ].map(_escapeCsv).join(','));
    }
    return buffer.toString();
  }

  static String toPlainTextReport({
    required String title,
    required List<AttendanceReportRow> rows,
    required List<String> headers,
  }) {
    final buffer = StringBuffer('$title\n\n');
    buffer.writeln(headers.join('\t'));
    for (final row in rows) {
      buffer.writeln([
        row.employeeName,
        row.showedUpDays,
        row.absentDays,
        row.pendingDays,
      ].join('\t'));
    }
    return buffer.toString();
  }

  static String _escapeCsv(Object value) {
    final s = value.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
