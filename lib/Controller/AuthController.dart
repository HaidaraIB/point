import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/config/app_config.dart';

class AuthController extends GetxController {
  var name = TextEditingController();
  var email = TextEditingController(text: kDebugMode ? 'point@admin.app' : "");
  bool obSecure = true;

  var mobile = TextEditingController();
  var pass = TextEditingController(
    text: kDebugMode ? AppConfig.testAdminPassword : '',
  );
  var repass = TextEditingController(
    text: kDebugMode ? AppConfig.testAdminPassword : '',
  );
  List<TextEditingController> controllersForOtp = List.generate(
    6,
    (index) => TextEditingController(),
  );
  changeObsecure() {
    obSecure = !obSecure;
    update();
  }
}
