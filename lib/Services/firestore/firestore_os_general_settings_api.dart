import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsGeneralSettings.dart';
import 'package:point/Services/firestore/firestore_stream_utils.dart';
import 'package:point/Utils/app_log.dart';

/// Firestore API for agency-wide Point OS general settings.
class FirestoreOsGeneralSettingsApi {
  FirestoreOsGeneralSettingsApi._();

  static const collection = 'os_general_settings';
  static const settingsDocId = 'default';

  static Stream<OsGeneralSettings> streamSettings() {
    final mapped = FirebaseFirestore.instance
        .collection(collection)
        .doc(settingsDocId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return OsGeneralSettings.defaults();
      return OsGeneralSettings.fromJson(doc.data());
    });
    return safeFirestoreValueStream(
      mapped,
      'os_general_settings',
      OsGeneralSettings.defaults(),
    );
  }

  static Future<OsGeneralSettings> loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection(collection)
        .doc(settingsDocId)
        .get();
    if (!doc.exists) return OsGeneralSettings.defaults();
    return OsGeneralSettings.fromJson(doc.data());
  }

  static Future<bool> saveSettings(OsGeneralSettings settings) async {
    return patchSettings(settings.toJson());
  }

  /// Merges only the given fields so unrelated settings are not overwritten.
  static Future<bool> patchSettings(Map<String, dynamic> fields) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(settingsDocId)
          .set(fields, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('saveGeneralSettings failed: $e\n$st');
      return false;
    }
  }
}
