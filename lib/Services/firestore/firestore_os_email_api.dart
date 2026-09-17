import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsEmailLogModel.dart';
import 'package:point/Models/Os/OsEmailSettings.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';
import 'package:point/Services/firestore/firestore_stream_utils.dart';
import 'package:point/Utils/app_log.dart';
import 'package:uuid/uuid.dart';

/// Firestore API for Point OS email hub (settings + dispatch logs).
class FirestoreOsEmailApi {
  FirestoreOsEmailApi._();

  static const settingsCollection = 'os_email_settings';
  static const logsCollection = 'os_email_logs';
  static const settingsDocId = 'default';
  static const _uuid = Uuid();

  static String newLogId() => _uuid.v4();

  static Stream<OsEmailSettings> streamSettings() {
    return FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc(settingsDocId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return OsEmailSettings.defaults();
      return OsEmailSettings.fromJson(doc.data());
    });
  }

  static Future<OsEmailSettings> loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc(settingsDocId)
        .get();
    if (!doc.exists) return OsEmailSettings.defaults();
    return OsEmailSettings.fromJson(doc.data());
  }

  static Future<bool> saveSettings(OsEmailSettings settings) async {
    try {
      await FirebaseFirestore.instance
          .collection(settingsCollection)
          .doc(settingsDocId)
          .set(settings.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('saveEmailSettings failed: $e\n$st');
      return false;
    }
  }

  static Stream<List<OsEmailLogModel>> streamLogs() {
    final mapped = FirebaseFirestore.instance
        .collection(logsCollection)
        .orderBy('sentAt', descending: true)
        .limit(FirestoreQueryLimits.osEmailLogs)
        .snapshots()
        .map((snap) {
          final items = <OsEmailLogModel>[];
          for (final d in snap.docs) {
            try {
              final raw = d.data();
              items.add(
                OsEmailLogModel.fromJson(
                  Map<String, dynamic>.from(raw),
                  d.id,
                ),
              );
            } catch (e, st) {
              appLog('os_email_logs skip doc ${d.id}: $e\n$st');
            }
          }
          return items;
        });
    return safeFirestoreListStream(mapped, 'os_email_logs');
  }

  static Future<bool> addLog(OsEmailLogModel log) async {
    try {
      final id = log.id?.trim().isNotEmpty == true ? log.id! : newLogId();
      final data = log.copyWithId(id).toJson();
      await FirebaseFirestore.instance
          .collection(logsCollection)
          .doc(id)
          .set(data);
      return true;
    } catch (e, st) {
      appLog('addEmailLog failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> deleteLog(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection(logsCollection)
          .doc(id)
          .delete();
      return true;
    } catch (e, st) {
      appLog('deleteEmailLog failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> clearLogs() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(logsCollection)
          .limit(FirestoreQueryLimits.osEmailLogs)
          .get();
      if (snap.docs.isEmpty) return true;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e, st) {
      appLog('clearEmailLogs failed: $e\n$st');
      return false;
    }
  }
}

extension _OsEmailLogCopy on OsEmailLogModel {
  OsEmailLogModel copyWithId(String id) {
    return OsEmailLogModel(
      id: id,
      type: type,
      recipientName: recipientName,
      recipientEmail: recipientEmail,
      subject: subject,
      content: content,
      status: status,
      referenceId: referenceId,
      senderEmail: senderEmail,
      attachmentsCount: attachmentsCount,
      sentAt: sentAt,
    );
  }
}
