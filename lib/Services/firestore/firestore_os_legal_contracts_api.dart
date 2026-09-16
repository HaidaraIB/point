import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsContractSettings.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';
import 'package:point/Services/firestore/firestore_stream_utils.dart';
import 'package:point/Utils/app_log.dart';
import 'package:uuid/uuid.dart';

class OsLegalContractsException implements Exception {
  OsLegalContractsException(this.messageKey);
  final String messageKey;

  @override
  String toString() => messageKey;
}

/// Firestore API for Point OS legal / client contracts (not payroll contracts).
class FirestoreOsLegalContractsApi {
  FirestoreOsLegalContractsApi._();

  static const contractsCollection = 'os_legal_contracts';
  static const settingsCollection = 'os_legal_contract_settings';
  static const settingsDocId = 'default';
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  static Stream<List<OsLegalContractModel>> streamContracts() {
    final mapped = FirebaseFirestore.instance
        .collection(contractsCollection)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.osLegalContracts)
        .snapshots()
        .map(
          (snap) => snap.docs.map(OsLegalContractModel.fromDoc).toList(),
        );
    return safeFirestoreListStream(mapped, contractsCollection);
  }

  static Stream<OsContractSettings> streamSettings() {
    return FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc(settingsDocId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return OsContractSettings.defaults();
      return OsContractSettings.fromJson(doc.data());
    });
  }

  static Future<OsContractSettings> loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc(settingsDocId)
        .get();
    if (!doc.exists) return OsContractSettings.defaults();
    return OsContractSettings.fromJson(doc.data());
  }

  static Future<bool> saveSettings(OsContractSettings settings) async {
    try {
      await FirebaseFirestore.instance
          .collection(settingsCollection)
          .doc(settingsDocId)
          .set(settings.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('saveLegalContractSettings failed: $e\n$st');
      return false;
    }
  }

  static Future<String> nextContractNumber(String prefix) async {
    final year = DateTime.now().year;
    final base = '$prefix-$year-';
    final snap = await FirebaseFirestore.instance
        .collection(contractsCollection)
        .where('contractNumber', isGreaterThanOrEqualTo: base)
        .where('contractNumber', isLessThan: '$prefix-${year + 1}-')
        .limit(FirestoreQueryLimits.osLegalContracts)
        .get();

    var maxSeq = 0;
    for (final doc in snap.docs) {
      final num = doc.data()['contractNumber'] as String? ?? '';
      final parts = num.split('-');
      if (parts.length >= 3) {
        final seq = int.tryParse(parts.last) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    }
    final next = maxSeq + 1;
    return '$base${next.toString().padLeft(3, '0')}';
  }

  static Future<bool> saveContract(OsLegalContractModel contract) async {
    try {
      final now = DateTime.now();
      final id = contract.id.isNotEmpty ? contract.id : newId();
      final data = contract
          .copyWith(
            id: id,
            updatedAt: now,
            createdAt: contract.createdAt ?? now,
          )
          .toJson();
      await FirebaseFirestore.instance
          .collection(contractsCollection)
          .doc(id)
          .set(data, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('saveLegalContract failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> deleteContract(String id) async {
    if (id.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection(contractsCollection)
          .doc(id)
          .delete();
      return true;
    } catch (e, st) {
      appLog('deleteLegalContract failed: $e\n$st');
      return false;
    }
  }
}
