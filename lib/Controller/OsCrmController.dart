import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/os_crm_activity.dart';
import 'package:point/Models/Os/os_crm_enums.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:uuid/uuid.dart';

class OsCrmController extends GetxController {
  final FirestoreServices _service = FirestoreServices();
  final isLoading = false.obs;

  /// Optimistic CRM stage while Firestore / the clients stream catches up.
  final _pendingStageByClientId = RxMap<String, String>();
  final _pendingStageWorkers = <String, Worker>{};

  List<ClientModel> get clients => Get.find<HomeController>().clients;

  @override
  void onClose() {
    for (final worker in _pendingStageWorkers.values) {
      worker.dispose();
    }
    super.onClose();
  }

  String effectiveStage(ClientModel c) {
    final id = c.id;
    if (id != null) {
      final pending = _pendingStageByClientId[id];
      if (pending != null) return pending;
    }
    return OsCrmStage.effective(c.crmStage);
  }

  /// Ensures [Obx] rebuilds when stage overrides change.
  void _touchStageOverrides() => _pendingStageByClientId.refresh();

  String displayCompany(ClientModel c) {
    final company = (c.company ?? '').trim();
    if (company.isNotEmpty) return company;
    return (c.name ?? '').trim();
  }

  List<ClientModel> clientsInStage(String stage) {
    return clients
        .where((c) => effectiveStage(c) == stage)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int countInStage(String stage) =>
      clients.where((c) => effectiveStage(c) == stage).length;

  Map<String, int> pipelineCountsByStage() {
    return {
      for (final stage in OsCrmStage.ordered)
        stage: countInStage(stage),
    };
  }

  int get pipelineActiveCount => clients
      .where(
        (c) =>
            effectiveStage(c) != OsCrmStage.lost &&
            effectiveStage(c) != OsCrmStage.won,
      )
      .length;

  int get wonClientsCount =>
      clients.where((c) => effectiveStage(c) == OsCrmStage.won).length;

  int get newLeadsCount =>
      clients.where((c) => effectiveStage(c) == OsCrmStage.newLead).length;

  int get conversionRatePercent {
    if (clients.isEmpty) return 0;
    return ((wonClientsCount / clients.length) * 100).round();
  }

  List<ClientModel> filteredClients(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<ClientModel>.from(clients);
    return clients.where((c) {
      final company = displayCompany(c).toLowerCase();
      final name = (c.name ?? '').toLowerCase();
      final phone = (c.phone ?? '').toLowerCase();
      final assignee = (c.assignedTo ?? '').toLowerCase();
      return company.contains(q) ||
          name.contains(q) ||
          phone.contains(q) ||
          assignee.contains(q);
    }).toList();
  }

  ClientModel? clientById(String? id) {
    if (id == null || id.isEmpty) return null;
    return clients.firstWhereOrNull((c) => c.id == id);
  }

  int invoiceCountFor(String? clientId) {
    if (clientId == null || clientId.isEmpty) return 0;
    final finance = Get.find<OsFinanceController>();
    return finance.invoices.where((i) => i.clientId == clientId).length;
  }

  int quotationCountFor(String? clientId) {
    if (clientId == null || clientId.isEmpty) return 0;
    final finance = Get.find<OsFinanceController>();
    return finance.quotations.where((q) => q.clientId == clientId).length;
  }

  String? _currentEmployeeName() {
    final name = Get.find<HomeController>().effectiveEmployee?.name?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  List<OsCrmActivity> activityTimeline(ClientModel client) {
    final structured = client.crmActivities;
    if (structured != null && structured.isNotEmpty) {
      final items = List<OsCrmActivity>.from(structured);
      items.sort((a, b) => b.at.compareTo(a.at));
      return items;
    }
    return parseNotes(client.crmNotes)
        .map(
          (note) => OsCrmActivity(
            type: OsCrmActivityType.note,
            content: note,
            at: client.createdAt,
          ),
        )
        .toList();
  }

  Future<bool> addCrmClient({
    required String company,
    required String contactName,
    String? phone,
    String? email,
    required String crmStage,
    String? leadSource,
    String? assignedTo,
    String? assignedEmployeeId,
  }) async {
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) {
      final emailUsed = await _service.isEmailUsedAcrossUsers(normalizedEmail);
      if (emailUsed) return false;
    }

    isLoading.value = true;
    final client = ClientModel(
      id: const Uuid().v4(),
      name: contactName.trim(),
      company: company.trim(),
      phone: (phone ?? '').trim().isEmpty ? null : phone!.trim(),
      email: normalizedEmail.isEmpty ? null : normalizedEmail,
      status: 'active',
      crmStage: OsCrmStage.effective(crmStage),
      leadSource: leadSource,
      assignedTo: assignedTo,
      assignedEmployeeId: assignedEmployeeId,
      balance: 0,
      totalRevenue: 0,
      createdAt: DateTime.now(),
    );
    final result = await _service.addClient(client);
    isLoading.value = false;
    return result;
  }

  Future<bool> updateCrmClient(ClientModel client) async {
    isLoading.value = true;
    final result = await Get.find<HomeController>().updateClient(client);
    isLoading.value = false;
    return result;
  }

  Future<bool> updateStage(String clientId, String newStage) async {
    final normalized = OsCrmStage.effective(newStage);
    final client = clientById(clientId);
    if (client == null) return false;
    final current = effectiveStage(client);
    if (current == normalized) return true;

    final activities = List<OsCrmActivity>.from(client.crmActivities ?? []);
    activities.insert(
      0,
      OsCrmActivity(
        type: OsCrmActivityType.stageChange,
        content: '$current|$normalized',
        at: DateTime.now(),
        performedBy: _currentEmployeeName(),
      ),
    );

    final patched = client.copyWith(
      crmStage: normalized,
      crmActivities: activities,
    );
    _pendingStageByClientId[clientId] = normalized;
    _touchStageOverrides();
    _patchClientLocal(clientId, patched);
    _trackPendingStageUntilSynced(clientId, normalized);

    final ok = await Get.find<HomeController>().updateClient(patched);
    if (!ok) {
      _clearPendingStage(clientId);
      _patchClientLocal(clientId, client);
    }
    return ok;
  }

  void _patchClientLocal(String clientId, ClientModel patched) {
    final home = Get.find<HomeController>();
    final index = home.clients.indexWhere((c) => c.id == clientId);
    if (index < 0) return;
    final next = List<ClientModel>.from(home.clients);
    next[index] = patched;
    home.clients.assignAll(next);
  }

  void _trackPendingStageUntilSynced(String clientId, String expectedStage) {
    _pendingStageWorkers[clientId]?.dispose();
    final home = Get.find<HomeController>();
    _pendingStageWorkers[clientId] = ever(home.clients, (_) {
      final synced = home.clients.firstWhereOrNull((c) => c.id == clientId);
      if (synced != null &&
          OsCrmStage.effective(synced.crmStage) == expectedStage) {
        _clearPendingStage(clientId);
      }
    });
  }

  void _clearPendingStage(String clientId) {
    _pendingStageByClientId.remove(clientId);
    _touchStageOverrides();
    _pendingStageWorkers.remove(clientId)?.dispose();
  }

  Future<bool> appendNote(String clientId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final client = clientById(clientId);
    if (client == null) return false;

    final timestamp = DateFormat.yMd().add_jm().format(DateTime.now());
    final entry = '$trimmed • ($timestamp)';
    final existing = (client.crmNotes ?? '').trim();
    final updatedNotes = existing.isEmpty ? entry : '$entry||$existing';

    final activities = List<OsCrmActivity>.from(client.crmActivities ?? []);
    activities.insert(
      0,
      OsCrmActivity(
        type: OsCrmActivityType.note,
        content: trimmed,
        at: DateTime.now(),
        performedBy: _currentEmployeeName(),
      ),
    );

    return updateCrmClient(
      client.copyWith(crmNotes: updatedNotes, crmActivities: activities),
    );
  }

  Future<bool> logActivity(String clientId, String type, String content) async {
    final client = clientById(clientId);
    if (client == null) return false;
    final activities = List<OsCrmActivity>.from(client.crmActivities ?? []);
    activities.insert(
      0,
      OsCrmActivity(
        type: type,
        content: content,
        at: DateTime.now(),
        performedBy: _currentEmployeeName(),
      ),
    );
    return updateCrmClient(client.copyWith(crmActivities: activities));
  }

  List<String> parseNotes(String? crmNotes) {
    if (crmNotes == null || crmNotes.trim().isEmpty) return const [];
    return crmNotes.split('||').where((n) => n.trim().isNotEmpty).toList();
  }
}
