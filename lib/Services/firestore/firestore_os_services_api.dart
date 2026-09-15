import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsServiceModel.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';
import 'package:point/Services/firestore/firestore_stream_utils.dart';
import 'package:point/Utils/app_log.dart';
import 'package:uuid/uuid.dart';

class OsServicesException implements Exception {
  OsServicesException(this.messageKey);
  final String messageKey;

  @override
  String toString() => messageKey;
}

/// Firestore API for Point OS service packages catalog.
class FirestoreOsServicesApi {
  FirestoreOsServicesApi._();

  static const servicesCollection = 'os_services';
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  static List<OsServiceModel> seedServices() {
    final now = DateTime.now();
    return [
      OsServiceModel(
        id: 'SRV-01',
        name: 'تصوير فوتوغرافي احترافي',
        category: OsServiceCategory.artisticProduction,
        basePrice: 1500000,
        priceType: OsServicePriceType.package,
        createdAt: now,
      ),
      OsServiceModel(
        id: 'SRV-02',
        name: 'إنتاج فيديوهات تسويقية',
        category: OsServiceCategory.visualProduction,
        basePrice: 5000000,
        priceType: OsServicePriceType.fixed,
        createdAt: now,
      ),
      OsServiceModel(
        id: 'SRV-03',
        name: 'مونتاج وتحرير فيديو سينمائي',
        category: OsServiceCategory.postProduction,
        basePrice: 75000,
        priceType: OsServicePriceType.hourly,
        createdAt: now,
      ),
      OsServiceModel(
        id: 'SRV-04',
        name: 'إدارة وحملات السوشيال ميديا',
        category: OsServiceCategory.digitalMarketing,
        basePrice: 2000000,
        priceType: OsServicePriceType.package,
        createdAt: now,
      ),
      OsServiceModel(
        id: 'SRV-05',
        name: 'الهوية البصرية المتكاملة',
        category: OsServiceCategory.creativeDesign,
        basePrice: 3500000,
        priceType: OsServicePriceType.fixed,
        createdAt: now,
      ),
    ];
  }

  static Stream<List<OsServiceModel>> streamServices() {
    final mapped = FirebaseFirestore.instance
        .collection(servicesCollection)
        .orderBy('createdAt')
        .limit(FirestoreQueryLimits.osServices)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsServiceModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_services');
  }

  /// Writes the five AppContext seed packages if the collection is empty.
  static Future<void> ensureSeeded() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(servicesCollection)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final service in seedServices()) {
        final id = service.id!;
        batch.set(
          FirebaseFirestore.instance.collection(servicesCollection).doc(id),
          service.toJson(),
        );
      }
      await batch.commit();
      appLog('os_services seeded (SRV-01..05)');
    } catch (e, st) {
      appLog('ensureSeeded os_services failed: $e\n$st');
    }
  }

  static Future<bool> upsertService(OsServiceModel service) async {
    try {
      final id = (service.id != null && service.id!.trim().isNotEmpty)
          ? service.id!.trim()
          : newId();
      final saved = service.copyWith(id: id);
      await FirebaseFirestore.instance
          .collection(servicesCollection)
          .doc(id)
          .set(saved.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('upsertService failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> deleteService(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection(servicesCollection)
          .doc(trimmed)
          .delete();
      return true;
    } catch (e, st) {
      appLog('deleteService failed: $e\n$st');
      return false;
    }
  }
}
