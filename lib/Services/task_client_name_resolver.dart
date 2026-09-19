import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/TaskModel.dart';

/// In-memory cache: task client ref → display string from Firestore.
final Map<String, String> taskClientDocNameCache = {};

final Set<String> _taskClientDocNameInflight = {};
final Set<String> _taskClientDocNameMiss = {};

bool _eqCi(String? a, String b) {
  if (a == null) return false;
  return a.trim().toLowerCase() == b.trim().toLowerCase();
}

bool _nonEmpty(String? s) => s != null && s.trim().isNotEmpty;

String? displayLabelFromClient(ClientModel? c) {
  if (c == null) return null;
  if (_nonEmpty(c.name)) return c.name!.trim();
  if (_nonEmpty(c.email)) return c.email!.trim();
  if (_nonEmpty(c.phone)) return c.phone!.trim();
  return null;
}

ClientModel? findClientForTaskRef(List<ClientModel> clients, String raw) {
  if (raw.isEmpty) return null;
  for (final c in clients) {
    if (_eqCi(c.id, raw) || _eqCi(c.authUid, raw)) return c;
  }
  return null;
}

final RegExp _uuidLike = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Firestore client doc id or auth uid — not arbitrary human-entered client names.
bool taskClientRefLooksLikeTechnicalId(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return false;
  if (_uuidLike.hasMatch(s)) return true;
  if (s.length >= 20 && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(s)) return true;
  return false;
}

String? _resolveFromMemory(String raw, List<ClientModel> clients) {
  final fromList = displayLabelFromClient(findClientForTaskRef(clients, raw));
  if (fromList != null) return fromList;
  final cached = taskClientDocNameCache[raw];
  if (cached != null && cached.isNotEmpty) return cached;
  return null;
}

Future<void> loadTaskClientLabelFromFirestore(String raw) async {
  if (raw.isEmpty) return;
  if (taskClientDocNameCache.containsKey(raw) &&
      taskClientDocNameCache[raw]!.isNotEmpty) {
    return;
  }
  if (_taskClientDocNameMiss.contains(raw)) return;
  if (_taskClientDocNameInflight.contains(raw)) return;
  _taskClientDocNameInflight.add(raw);
  try {
    final db = FirebaseFirestore.instance;
    final docSnap = await db.collection('clients').doc(raw).get();
    if (docSnap.exists && docSnap.data() != null) {
      final c = ClientModel.fromJson(
        Map<String, dynamic>.from(docSnap.data()! as Map),
        docSnap.id,
      );
      final d = displayLabelFromClient(c);
      if (d != null) {
        taskClientDocNameCache[raw] = d;
        return;
      }
    }
    final byUid = await db
        .collection('clients')
        .where('authUid', isEqualTo: raw)
        .limit(1)
        .get();
    if (byUid.docs.isNotEmpty) {
      final doc = byUid.docs.first;
      final c = ClientModel.fromJson(
        Map<String, dynamic>.from(doc.data() as Map),
        doc.id,
      );
      final d = displayLabelFromClient(c);
      if (d != null) {
        taskClientDocNameCache[raw] = d;
        return;
      }
    }
    _taskClientDocNameMiss.add(raw);
  } catch (_) {
    // Permission or network — do not negative-cache.
  } finally {
    _taskClientDocNameInflight.remove(raw);
  }
}

/// Resolves [raw] client ref from in-memory clients + cache only.
String resolveTaskClientRef(String raw, List<ClientModel> clients) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final resolved = _resolveFromMemory(trimmed, clients);
  if (resolved != null) return resolved;
  return trimmed;
}

/// Resolves [raw] for emails/notifications; omits unresolved technical ids.
Future<String?> resolveTaskClientRefForEmail(
  String raw,
  List<ClientModel> clients,
) async {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  var resolved = _resolveFromMemory(trimmed, clients);
  if (resolved != null) return resolved;

  if (taskClientRefLooksLikeTechnicalId(trimmed)) {
    await loadTaskClientLabelFromFirestore(trimmed);
    resolved = _resolveFromMemory(trimmed, clients);
    if (resolved != null) return resolved;
    return null;
  }

  return trimmed;
}

/// [TaskModel.clientName] is usually a client document id (or auth uid).
String resolvedTaskClientDisplayName(
  TaskModel task,
  List<ClientModel> clients,
) {
  return resolveTaskClientRef(task.clientName, clients);
}

/// UI label: human name, custom text, or [fallback] for unresolved technical ids.
String taskClientDisplayLabelForUi(
  String raw,
  List<ClientModel> clients, {
  String fallback = '-',
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;
  final display = resolveTaskClientRef(trimmed, clients);
  if (display != trimmed) return display;
  if (taskClientRefLooksLikeTechnicalId(trimmed)) return fallback;
  return display;
}
