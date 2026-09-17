import 'package:get/get.dart';
import 'package:point/Controller/OsGeneralSettingsController.dart';
import 'package:point/Models/Os/OsGeneralSettings.dart';

/// Returns the configured USD→IQD rate, or the point_os default when unavailable.
double osCurrentUsdToIqdRate() {
  if (Get.isRegistered<OsGeneralSettingsController>()) {
    return Get.find<OsGeneralSettingsController>().usdToIqdRate;
  }
  return OsGeneralSettings.defaultUsdToIqdRate;
}

double convertUsdToIqd(double usd, {double? rate}) {
  final resolved = rate ?? osCurrentUsdToIqdRate();
  return usd * resolved;
}

bool isValidUsdToIqdRate(double rate) => rate > 0;
