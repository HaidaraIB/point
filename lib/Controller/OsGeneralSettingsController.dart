import 'package:get/get.dart';
import 'package:point/Models/Os/OsGeneralSettings.dart';
import 'package:point/Services/firestore/firestore_os_general_settings_api.dart';
import 'package:point/Utils/os_currency.dart';

class OsGeneralSettingsController extends GetxController {
  final settings = OsGeneralSettings.defaults().obs;
  final isLoading = false.obs;

  double get usdToIqdRate => settings.value.usdToIqdRate;

  @override
  void onInit() {
    super.onInit();
    settings.bindStream(FirestoreOsGeneralSettingsApi.streamSettings());
  }

  Future<bool> saveUsdToIqdRate(double rate) async {
    if (!isValidUsdToIqdRate(rate)) return false;
    isLoading.value = true;
    try {
      return await FirestoreOsGeneralSettingsApi.saveSettings(
        settings.value.copyWith(usdToIqdRate: rate),
      );
    } finally {
      isLoading.value = false;
    }
  }
}
