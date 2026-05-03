import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/TaskModel.dart';

/// In-memory cache: [TaskModel.clientName] raw ref → display string from Firestore.
final Map<String, String> taskClientDocNameCache = {};

final Set<String> _taskClientDocNameInflight = {};
final Set<String> _taskClientDocNameMiss = {};

bool _eqCi(String? a, String b) {
  if (a == null) return false;
  return a.trim().toLowerCase() == b.trim().toLowerCase();
}

bool _nonEmpty(String? s) => s != null && s.trim().isNotEmpty;

String? _displayFromClient(ClientModel? c) {
  if (c == null) return null;
  if (_nonEmpty(c.name)) return c.name!.trim();
  if (_nonEmpty(c.email)) return c.email!.trim();
  if (_nonEmpty(c.phone)) return c.phone!.trim();
  return null;
}

ClientModel? _findClientForTaskRef(HomeController controller, String raw) {
  if (raw.isEmpty) return null;
  for (final c in controller.clients) {
    if (_eqCi(c.id, raw) || _eqCi(c.authUid, raw)) return c;
  }
  return null;
}

/// [TaskModel.clientName] is usually a client document id (or auth uid); resolves to a human label.
String resolvedTaskClientDisplayName(TaskModel task, HomeController controller) {
  final raw = task.clientName.trim();
  if (raw.isEmpty) return '';
  final fromList = _displayFromClient(_findClientForTaskRef(controller, raw));
  if (fromList != null) return fromList;
  final cached = taskClientDocNameCache[raw];
  if (cached != null && cached.isNotEmpty) return cached;
  return raw;
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

Future<void> _loadClientLabelFromFirestore(String raw) async {
  if (raw.isEmpty) return;
  if (taskClientDocNameCache.containsKey(raw) && taskClientDocNameCache[raw]!.isNotEmpty) {
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
      final d = _displayFromClient(c);
      if (d != null) {
        taskClientDocNameCache[raw] = d;
        return;
      }
    }
    final byUid = await db.collection('clients').where('authUid', isEqualTo: raw).limit(1).get();
    if (byUid.docs.isNotEmpty) {
      final doc = byUid.docs.first;
      final c = ClientModel.fromJson(
        Map<String, dynamic>.from(doc.data() as Map),
        doc.id,
      );
      final d = _displayFromClient(c);
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

/// Task card row: reactive client list + one-shot Firestore resolve when the task still holds a bare id.
class TaskCardClientNameRow extends StatefulWidget {
  final TaskModel task;

  const TaskCardClientNameRow({super.key, required this.task});

  @override
  State<TaskCardClientNameRow> createState() => _TaskCardClientNameRowState();
}

class _TaskCardClientNameRowState extends State<TaskCardClientNameRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleDocLookup());
  }

  @override
  void didUpdateWidget(covariant TaskCardClientNameRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.clientName != widget.task.clientName) {
      _scheduleDocLookup();
    }
  }

  void _scheduleDocLookup() {
    final raw = widget.task.clientName.trim();
    if (raw.isEmpty) return;
    final hc = Get.find<HomeController>();
    if (_displayFromClient(_findClientForTaskRef(hc, raw)) != null) return;
    if (!taskClientRefLooksLikeTechnicalId(raw)) return;
    if (taskClientDocNameCache.containsKey(raw) && taskClientDocNameCache[raw]!.isNotEmpty) {
      return;
    }
    _loadClientLabelFromFirestore(raw).then((_) {
      if (!mounted) return;
      if (taskClientDocNameCache.containsKey(raw) && taskClientDocNameCache[raw]!.isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hc = Get.find<HomeController>();
      hc.clients.length;
      final raw = widget.task.clientName.trim();
      if (raw.isEmpty) return const SizedBox.shrink();

      final display = resolvedTaskClientDisplayName(widget.task, hc);
      if (display.isEmpty) return const SizedBox.shrink();
      if (display == raw && taskClientRefLooksLikeTechnicalId(raw)) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(Icons.person_outline, size: 15, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
