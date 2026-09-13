import 'package:get/instance_manager.dart';
import 'package:point/Controller/AuthController.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/InternetStatusController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Controller/OsPayrollController.dart';
import 'package:point/Controller/WebUpdateController.dart';
import 'package:point/Services/notification_navigation/notification_navigation_coordinator.dart';
import 'package:point/Services/os_quote_template_settings.dart';
import 'package:point/Services/os_stamp_settings.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController());
    Get.put(HomeController());
    Get.put(ClientController());
    Get.put(InternetStatusController(), permanent: true);
    Get.put(WebUpdateController(), permanent: true);
    Get.put(NotificationNavigationCoordinator(), permanent: true);
    Get.put(OsStampSettingsController(), permanent: true);
    Get.put(OsQuoteTemplateController(), permanent: true);
    Get.lazyPut(() => OsFinanceController(), fenix: true);
    Get.lazyPut(() => OsPayrollController(), fenix: true);
  }
}
