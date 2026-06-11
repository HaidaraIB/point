import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Utils/app_log.dart';

/// Admin-editable company office location for attendance geofence.
/// Stored in Firestore `app_settings/attendance`.
class AttendanceSettings {
  const AttendanceSettings({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.label,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String? label;

  static const String documentPath = 'app_settings/attendance';
  static const double defaultRadiusMeters = 100;

  bool get isConfigured => latitude != 0 || longitude != 0;

  static Future<AttendanceSettings?> load() async {
    final snap = await FirebaseFirestore.instance.doc(documentPath).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;

    final lat = _asDouble(data['latitude']);
    final lng = _asDouble(data['longitude']);
    final radius = _asDouble(data['radiusMeters']);
    if (lat == null || lng == null || radius == null) return null;

    final label = _nonEmptyString(data['label']);

    return AttendanceSettings(
      latitude: lat,
      longitude: lng,
      radiusMeters: radius,
      label: label,
    );
  }

  static Future<void> save({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    String? label,
  }) async {
    final trimmedLabel = label?.trim() ?? '';
    final data = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (trimmedLabel.isNotEmpty) {
      data['label'] = trimmedLabel;
    }

    try {
      await FirebaseFirestore.instance.doc(documentPath).set(data);
    } catch (e, s) {
      appLog('AttendanceSettings.save failed: $e', error: e, stackTrace: s);
      rethrow;
    }
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
