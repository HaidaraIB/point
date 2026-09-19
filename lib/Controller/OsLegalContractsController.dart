import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Data/os_contract_templates_seed.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/Utils/os_stream_binding.dart';
import 'package:point/Models/Os/OsContractSettings.dart';
import 'package:point/Models/Os/OsContractTemplate.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Services/firestore/firestore_os_legal_contracts_api.dart';
import 'package:point/Utils/os_currency.dart';

class OsLegalContractsController extends GetxController {
  final contracts = <OsLegalContractModel>[].obs;
  final settings = OsContractSettings.defaults().obs;
  final isLoading = false.obs;

  List<OsContractTemplate> get templates => OsContractTemplatesSeed.presets();

  @override
  void onInit() {
    super.onInit();
    _bindStreams();
  }

  void rebindStreamsForPermissions() => _bindStreams();

  void _bindStreams() {
    final emp = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>().effectiveEmployee
        : null;
    final allowed = OsPermissions.canAccessModule(emp, OsModuleIds.contracts);

    bindOsListStream(
      contracts,
      allowed,
      FirestoreOsLegalContractsApi.streamContracts(),
    );
    bindOsValueStream(
      settings,
      allowed,
      FirestoreOsLegalContractsApi.streamSettings(),
      OsContractSettings.defaults(),
    );
  }

  List<OsLegalContractModel> filtered({
    required String query,
    required String statusFilter,
    required String targetFilter,
  }) {
    final q = query.trim().toLowerCase();
    return contracts.where((c) {
      if (statusFilter != 'ALL' && c.status != statusFilter) return false;
      if (targetFilter != 'ALL' && c.targetType != targetFilter) return false;
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.contractNumber.toLowerCase().contains(q) ||
          c.targetName.toLowerCase().contains(q) ||
          c.partyTwoCompany.toLowerCase().contains(q);
    }).toList();
  }

  int countByStatus(String status) =>
      contracts.where((c) => c.status == status).length;

  double activeValueIqd() {
    final usdRate = osCurrentUsdToIqdRate();
    return contracts
        .where((c) => c.status == OsLegalContractStatus.active)
        .fold<double>(0, (sum, c) {
      final v = c.totalValue;
      if (c.currency == OsLegalContractCurrency.usd) {
        return sum + convertUsdToIqd(v, rate: usdRate);
      }
      return sum + v;
    });
  }

  Future<String> generateContractNumber() {
    final prefix = settings.value.contractNumberPrefix.trim().isEmpty
        ? 'NOG-CON'
        : settings.value.contractNumberPrefix.trim();
    return FirestoreOsLegalContractsApi.nextContractNumber(prefix);
  }

  Future<bool> saveContract(OsLegalContractModel contract) async {
    isLoading.value = true;
    try {
      return await FirestoreOsLegalContractsApi.saveContract(contract);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteContract(String id) async {
    isLoading.value = true;
    try {
      return await FirestoreOsLegalContractsApi.deleteContract(id);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateStatus(String id, String status) async {
    final idx = contracts.indexWhere((c) => c.id == id);
    if (idx < 0) return false;
    final current = contracts[idx];
    final signedAt = status == OsLegalContractStatus.active &&
            current.signedAt == null
        ? DateTime.now()
        : current.signedAt;
    return saveContract(
      current.copyWith(status: status, signedAt: signedAt),
    );
  }

  Future<bool> saveSettings(OsContractSettings value) async {
    isLoading.value = true;
    try {
      return await FirestoreOsLegalContractsApi.saveSettings(value);
    } finally {
      isLoading.value = false;
    }
  }
}
