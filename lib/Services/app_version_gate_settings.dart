import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Services/mobile_version_gate.dart';
import 'package:point/Utils/app_log.dart';

/// Admin-editable mobile force-update config in Firestore `appVersionGate/mobile`.
class AppVersionGateSettings {
  const AppVersionGateSettings({
    required this.androidMinBuild,
    required this.iosMinBuild,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
  });

  final int androidMinBuild;
  final int iosMinBuild;
  final String androidStoreUrl;
  final String iosStoreUrl;

  static const String documentPath = MobileVersionGate.firestoreDocPath;

  static Future<AppVersionGateSettings?> load() async {
    final snap = await FirebaseFirestore.instance.doc(documentPath).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;

    final androidMin = _asInt(data['androidMinBuild']);
    final iosMin = _asInt(data['iosMinBuild']);
    final androidUrl = _nonEmptyString(data['androidStoreUrl']);
    final iosUrl = _nonEmptyString(data['iosStoreUrl']);

    if (androidMin == null || iosMin == null) return null;

    return AppVersionGateSettings(
      androidMinBuild: androidMin,
      iosMinBuild: iosMin,
      androidStoreUrl: androidUrl ?? '',
      iosStoreUrl: iosUrl ?? '',
    );
  }

  static Future<void> save({
    required int androidMinBuild,
    required int iosMinBuild,
    String? androidStoreUrl,
    String? iosStoreUrl,
  }) async {
    final androidUrl = androidStoreUrl?.trim() ?? '';
    final iosUrl = iosStoreUrl?.trim() ?? '';

    final data = <String, dynamic>{
      'androidMinBuild': androidMinBuild,
      'iosMinBuild': iosMinBuild,
    };
    if (androidUrl.isNotEmpty) data['androidStoreUrl'] = androidUrl;
    if (iosUrl.isNotEmpty) data['iosStoreUrl'] = iosUrl;

    try {
      // Full replace — omitting optional URL keys clears them in Firestore.
      await FirebaseFirestore.instance.doc(documentPath).set(data);
    } catch (e, s) {
      appLog('AppVersionGateSettings.save failed: $e', error: e, stackTrace: s);
      rethrow;
    }
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _nonEmptyString(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return s;
  }
}
