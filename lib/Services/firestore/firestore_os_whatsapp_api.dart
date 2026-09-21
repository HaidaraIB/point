import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsWhatsappLogModel.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';
import 'package:point/Services/firestore/firestore_stream_utils.dart';
import 'package:point/Utils/app_log.dart';

/// Firestore read API for WhatsApp dispatch logs (writes happen in Edge Function).
class FirestoreOsWhatsappApi {
  FirestoreOsWhatsappApi._();

  static const logsCollection = 'os_whatsapp_logs';

  static Stream<List<OsWhatsappLogModel>> streamLogs() {
    final mapped = FirebaseFirestore.instance
        .collection(logsCollection)
        .orderBy('sentAt', descending: true)
        .limit(FirestoreQueryLimits.osWhatsappLogs)
        .snapshots()
        .map((snap) {
          final items = <OsWhatsappLogModel>[];
          for (final d in snap.docs) {
            try {
              final raw = d.data();
              items.add(
                OsWhatsappLogModel.fromFirestore(raw, d.id),
              );
            } catch (e, st) {
              appLog('os_whatsapp_logs skip doc ${d.id}: $e\n$st');
            }
          }
          return items;
        });
    return safeFirestoreListStream(mapped, 'os_whatsapp_logs');
  }
}
