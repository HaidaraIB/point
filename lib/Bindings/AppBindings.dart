import 'package:get/instance_manager.dart';
import 'package:point/Controller/AuthController.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/MeHomeController.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController());
    Get.put(HomeController());
    Get.put(ClientController());
    Get.lazyPut(() => MeHomeController());
  }
}
