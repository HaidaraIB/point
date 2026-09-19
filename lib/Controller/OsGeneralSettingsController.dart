import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/Os/OsGeneralSettings.dart';
import 'package:point/Services/firestore/firestore_os_general_settings_api.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_currency.dart';
import 'package:point/Utils/os_stream_binding.dart';

class OsGeneralSettingsController extends GetxController {
  final settings = OsGeneralSettings.defaults().obs;
  final isLoading = false.obs;

  double get usdToIqdRate => settings.value.usdToIqdRate;

  @override
  void onInit() {
    super.onInit();
    rebindStreamsForPermissions();
  }

  void rebindStreamsForPermissions() {
    final emp = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>().effectiveEmployee
        : null;
    bindOsValueStream(
      settings,
      OsPermissions.canAccessOsSection(emp),
      FirestoreOsGeneralSettingsApi.streamSettings(),
      OsGeneralSettings.defaults(),
    );
  }

  Future<bool> saveUsdToIqdRate(double rate) async {
    if (!isValidUsdToIqdRate(rate)) return false;
    isLoading.value = true;
    try {
      final ok = await FirestoreOsGeneralSettingsApi.patchSettings({
        'usdToIqdRate': rate,
      });
      if (ok) {
        settings.value = settings.value.copyWith(usdToIqdRate: rate);
      }
      return ok;
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
      final ok = await FirestoreOsGeneralSettingsApi.patchSettings(
        next.printContactToJson(),
      );
      if (ok) {
        settings.value = next;
      }
      return ok;
    } finally {
      isLoading.value = false;
    }
  }
}
