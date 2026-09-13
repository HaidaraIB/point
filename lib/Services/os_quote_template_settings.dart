import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quotation digital template header/footer (mirrors point_os Quotations.tsx).
class OsQuoteTemplateController extends GetxController {
  final headerText = ''.obs;
  final footerText = ''.obs;

  @override
  void onInit() {
    super.onInit();
    headerText.value = AppLocaleKeys.osQuotationsTemplateHeaderDefault.tr;
    footerText.value = AppLocaleKeys.osQuotationsTemplateFooterDefault.tr;
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final header = prefs.getString(StorageKeys.prefsOsQuoteHeader);
    final footer = prefs.getString(StorageKeys.prefsOsQuoteFooter);
    if (header != null && header.trim().isNotEmpty) {
      headerText.value = header;
    }
    if (footer != null && footer.trim().isNotEmpty) {
      footerText.value = footer;
    }
  }

  Future<void> setHeaderText(String value) async {
    headerText.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.prefsOsQuoteHeader, value);
  }

  Future<void> setFooterText(String value) async {
    footerText.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.prefsOsQuoteFooter, value);
  }
}
