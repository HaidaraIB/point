import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/AuthController.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/View/Auth/CreateUserAccount.dart';
import 'package:point/View/Auth/Shared/Rights.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

class ResetPassword extends StatelessWidget {
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
  return GetBuilder<AuthController>(
    builder: (controller) {
      return Form(
        key: _key,
        child: Row(
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
                      'resetpassword'.tr,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        wordSpacing: 1.2,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 10),

                    Text(
                      'enternewpassword'.tr,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    InputText(
                      hintText: '********'.tr,
                      labelText: 'newpass'.tr,
                      height: 42,
                      fillColor: Colors.white,
                      obscureText: controller.obSecure,
                      suffixIcon: InkWell(
                        onTap: () {
                          controller.changeObsecure();
                        },
                        child: Icon(
                          controller.obSecure
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                          size: 12,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return ' ';
                        }

                        return validatePasswordStrong(v);
                      },

                      borderRadius: 5,
                      borderColor: Colors.grey.shade300,
                    ),
                    InputText(
                      hintText: '******'.tr,
                      labelText: 'renewpass'.tr,
                      obscureText: controller.obSecure,
                      height: 42,
                      fillColor: Colors.white,
                      suffixIcon: InkWell(
                        onTap: () {
                          controller.changeObsecure();
                        },
                        child: Icon(
                          controller.obSecure
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                          size: 12,
                        ),
                      ),
                      // require: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return ' ';
                        }
                        return null;
                      },
                      borderRadius: 5,
                      borderColor: Colors.grey.shade300,
                    ),

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
                      title: 'login'.tr,
                      onpress: () {
                        if (_key.currentState!.validate()) {
                          //perform reset password action
                        }
                      },
                    ),
                    buildRightsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
