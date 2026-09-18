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
      return await FirestoreOsGeneralSettingsApi.patchSettings({
        'usdToIqdRate': rate,
      });
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> savePrintContact({
    required String addressAr,
    required String addressEn,
    required String phone,
    required String email,
    required String website,
  }) async {
    isLoading.value = true;
    try {
      final next = settings.value.copyWith(
        printAddressAr: addressAr.trim(),
        printAddressEn: addressEn.trim(),
        printPhone: phone.trim(),
        printEmail: email.trim(),
        printWebsite: website.trim(),
      );
      return await FirestoreOsGeneralSettingsApi.patchSettings(
        next.printContactToJson(),
      );
    } finally {
      isLoading.value = false;
    }
  }
}
