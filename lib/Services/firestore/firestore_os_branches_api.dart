import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsBranchModel.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';
import 'package:point/Services/firestore/firestore_stream_utils.dart';
import 'package:point/Utils/app_log.dart';
import 'package:uuid/uuid.dart';

class OsBranchesException implements Exception {
  OsBranchesException(this.messageKey);
  final String messageKey;

  @override
  String toString() => messageKey;
}

/// Firestore API for Point OS branches / offices.
class FirestoreOsBranchesApi {
  FirestoreOsBranchesApi._();

  static const branchesCollection = 'os_branches';
  static const expensesCollection = 'os_expenses';
  static const employeesCollection = 'employees';
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  /// Seed ids already used by expenses / employees in production data.
  static const seedBaghdadId = 'BR-01';
  static const seedErbilId = 'BR-02';
  static const seedBasraId = 'BR-03';

  static List<OsBranchModel> seedBranches() {
    final now = DateTime.now();
    return [
      OsBranchModel(
        id: seedBaghdadId,
        name: 'فرع بغداد الرئيسي',
        location: 'الكرادة، ساحة الأندلس',
        manager: 'علي جاسم',
        phone: '07801112223',
        status: OsBranchStatus.active,
        color: 'indigo',
        createdAt: now,
      ),
      OsBranchModel(
        id: seedErbilId,
        name: 'مكتب أربيل للإنتاج',
        location: 'عينكاوة، مجمع القرية الإيطالية',
        manager: 'سارة هاني',
        phone: '07504445556',
        status: OsBranchStatus.active,
        color: 'emerald',
        createdAt: now,
      ),
      OsBranchModel(
        id: seedBasraId,
        name: 'فرع البصرة (قيد التجهيز)',
        location: 'الجزائر، قرب مول البصرة',
        manager: 'محمد قاسم',
        phone: '07709998887',
        status: OsBranchStatus.inactive,
        color: 'amber',
        createdAt: now,
      ),
    ];
  }

  static Stream<List<OsBranchModel>> streamBranches() {
    final mapped = FirebaseFirestore.instance
        .collection(branchesCollection)
        .orderBy('createdAt')
        .limit(FirestoreQueryLimits.osBranches)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => OsBranchModel.fromJson(d.data(), d.id))
              .toList(),
        );
    return safeFirestoreListStream(mapped, 'os_branches');
  }

  /// Writes the three MOCK_BRANCHES docs if the collection is empty.
  static Future<void> ensureSeeded() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(branchesCollection)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final branch in seedBranches()) {
        final id = branch.id!;
        batch.set(
          FirebaseFirestore.instance.collection(branchesCollection).doc(id),
          branch.toJson(),
        );
      }
      await batch.commit();
      appLog('os_branches seeded (BR-01/02/03)');
    } catch (e, st) {
      appLog('ensureSeeded os_branches failed: $e\n$st');
    }
  }

  static Future<bool> upsertBranch(OsBranchModel branch) async {
    try {
      final id = (branch.id != null && branch.id!.trim().isNotEmpty)
          ? branch.id!.trim()
          : newId();
      final saved = branch.copyWith(id: id);
      await FirebaseFirestore.instance
          .collection(branchesCollection)
          .doc(id)
          .set(saved.toJson(), SetOptions(merge: true));
      return true;
    } catch (e, st) {
      appLog('upsertBranch failed: $e\n$st');
      return false;
    }
  }

  /// Deletes only when no employee or expense still references [id].
  static Future<bool> deleteBranch(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return false;

    try {
      final employees = await FirebaseFirestore.instance
          .collection(employeesCollection)
          .where('branchId', isEqualTo: trimmed)
          .limit(1)
          .get();
      if (employees.docs.isNotEmpty) {
        throw OsBranchesException('errors.osBranches.in_use');
      }

      final expenses = await FirebaseFirestore.instance
          .collection(expensesCollection)
          .where('branchId', isEqualTo: trimmed)
          .limit(1)
          .get();
      if (expenses.docs.isNotEmpty) {
        throw OsBranchesException('errors.osBranches.in_use');
      }

      await FirebaseFirestore.instance
          .collection(branchesCollection)
          .doc(trimmed)
          .delete();
      return true;
    } on OsBranchesException {
      rethrow;
    } catch (e, st) {
      appLog('deleteBranch failed: $e\n$st');
      return false;
    }
  }
}
