/// Per-employee branch/office geofence for attendance check-in.
class EmployeeAttendanceLocation {
  const EmployeeAttendanceLocation({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.label,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String? label;

  static const double defaultRadiusMeters = 100;

  bool get isConfigured => latitude != 0 || longitude != 0;

  factory EmployeeAttendanceLocation.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EmployeeAttendanceLocation(
        latitude: 0,
        longitude: 0,
        radiusMeters: defaultRadiusMeters,
      );
    }
    return EmployeeAttendanceLocation(
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
      radiusMeters: _asDouble(json['radiusMeters']) ?? defaultRadiusMeters,
      label: _nonEmptyString(json['label']),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
    };
    final trimmedLabel = label?.trim() ?? '';
    if (trimmedLabel.isNotEmpty) {
      data['label'] = trimmedLabel;
    }
    return data;
  }

  EmployeeAttendanceLocation copyWith({
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? label,
  }) {
    return EmployeeAttendanceLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      label: label ?? this.label,
    );
  }

  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static String? _nonEmptyString(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return s;
  }
}
