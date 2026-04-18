import 'package:get/get.dart';
import 'package:point/Services/StorageKeys.dart';

/// قيمة مرسلة لاختيار "عميل آخر" يدوياً في نماذج المهام.
const String kTaskOtherClientSentinel = '__other_client__';

/// Maps stored Firestore platform keys to the same strings used in form
/// multi-selects ([StorageKeys.platformList] entries shown as [key.tr]).
List<dynamic> normalizeTaskFormPlatformSelections(List<dynamic> raw) {
  if (raw.isEmpty) return <dynamic>[];
  final keys = StorageKeys.platformList;
  return raw.map((e) {
    final s = e.toString();
    if (keys.contains(s)) return s.tr;
    return s;
  }).toList();
}
