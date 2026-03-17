import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:get/get_state_manager/src/simple/get_state.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/instance_manager.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/View/Auth/Shared/Rights.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

class CreateUserAccount extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: Scaffold(body: _buildDesktopLayout()),
      tablet: Scaffold(body: _buildDesktopLayout()),
      desktop: Scaffold(body: _buildDesktopLayout()),
    );
  }
}

// --- IGNORE ---
Widget _buildDesktopLayout() {
  var _key = GlobalKey<FormState>();
  var nameController = TextEditingController();
  var emailController = TextEditingController();
  var passwordController = TextEditingController();
  return GetBuilder<ClientController>(
    builder: (controller) {
      return Row(
        children: [
          Image.asset(
            AppImages.images.authcover,
            // width: Get.width / 2 - 50,
            // height: Get.height,
            // fit: BoxFit.fitWidth,
          ),

          Center(
            child: Container(
              alignment: Alignment.center,
              // color: Colors.yellow,
              margin: EdgeInsets.symmetric(vertical: 50, horizontal: 100),
              width: Get.width / 2 - 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'createuseraccount'.tr,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      wordSpacing: 1.2,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 10),

                  Text(
                    'enteremailandpassword'.tr,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  InputText(
                    labelText: 'companyname'.tr,
                    hintText: 'entername'.tr,
                    height: 42,
                    fillColor: Colors.white,
                    controller: nameController,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return ' ';
                      }
                      return null;
                    },

                    borderRadius: 5,
                    borderColor: Colors.grey.shade300,
                  ),
                  InputText(
                    labelText: 'email'.tr,
                    hintText: 'example@example.com'.tr,
                    height: 42,
                    fillColor: Colors.white,
                    controller: emailController,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return ' ';
                      }
                      return null;
                    },

                    borderRadius: 5,
                    borderColor: Colors.grey.shade300,
                  ),
                  InputText(
                    hintText: ''.tr,
                    labelText: 'password'.tr,
                    obscureText: controller.obSecure,
                    height: 42,
                    fillColor: Colors.white,
                    controller: passwordController,
                    suffixIcon: InkWell(
                      onTap: () => controller.changeObsecure(),
                      child: Icon(
                        controller.obSecure
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                        size: 12,
                      ),
                    ),
                    // require: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return ' ';
                      }
                      return validatePasswordStrong(v);
                    },
                    borderRadius: 5,
                    borderColor: Colors.grey.shade300,
                  ),
                  // SizedBox(height: 10),
                  // Text(
                  //   'forgotpassword'.tr,
                  //   style: TextStyle(color: Colors.grey, fontSize: 13),
                  // ),
                  SizedBox(height: 25),
                  MainButton(
                    icon: false,
                    height: 40,
                    bordersize: 10,
                    margin: EdgeInsets.all(0),
                    // lineargrad: ,
                    lineargrad: LinearGradient(
                      colors: [
                        Color(0xff19133F),
                        Color(0xff19133F),
                        Color(0xff19133F),
                        Color(0xff19133F),
                        Color(0xff19133F),
                        Color.fromARGB(255, 47, 19, 63),
                        Color.fromARGB(255, 47, 19, 63),
                        Color.fromARGB(255, 47, 19, 63),
                        Color.fromARGB(255, 47, 19, 63),

                        // Color(0xff5B0E4E),
                      ],

                      begin: Alignment.topCenter,
                      end: Alignment.bottomRight,
                    ),
                    title: 'createaccount'.tr,
                    onpress: () async {
                      if (_key.currentState!.validate()) {
                        await controller
                            .addClient(
                              ClientModel(
                                name: nameController.text,
                                email:
                                    emailController.text.trim().toLowerCase(),
                                password: passwordController.text,
                                status: StorageKeys.status_user_pending,
                                createdAt: DateTime.now(),
                                startAt: DateTime.now(),
                                endAt: DateTime.now(),
                                id: '${Random().nextInt(100000)}',
                              ),
                            )
                            .then((v) {
                              if (v == true) {
                                // Get.back();
                                FunHelper.showsnackbar(
                                  'success'.tr,
                                  'accountcreatedsuccessfully'.tr,
                                  snackPosition: SnackPosition.TOP,
                                  backgroundColor: Colors.green,
                                  colorText: Colors.white,
                                );
                              }
                            });
                      }
                    },
                  ),
                  buildRightsSection(),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

String? validatePasswordStrong(String? value) {
  if (value == null || value.isEmpty) return 'password_required'.tr;
  if (value.length < 8) return 'password_min_8'.tr;

  final pattern =
      r"""^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~%^()_\-+=\[\]{}|:;"'<>,.?/]).{8,}$""";
  final regExp = RegExp(pattern);

  if (!regExp.hasMatch(value)) return 'password_requirements'.tr;
  return null;
}
