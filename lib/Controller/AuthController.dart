import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthController extends GetxController {
  var name = TextEditingController();
  var email = TextEditingController(
    text: kDebugMode ? 'point@accountholder.app' : "",
  );
  bool obSecure = true;

  var mobile = TextEditingController();
  var pass = TextEditingController(text: kDebugMode ? 'Pp@12acc' : '');
  var repass = TextEditingController();
  List<TextEditingController> controllersForOtp = List.generate(
    6,
    (index) => TextEditingController(),
  );
  changeObsecure() {
    obSecure = !obSecure;
    update();
  }
}
