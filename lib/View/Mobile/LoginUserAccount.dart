import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/PasswordValidator.dart';
import 'package:point/View/Auth/Shared/Rights.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
// import 'package:point/Utils/AppColors.dart';

class LoginUserAccount extends StatefulWidget {
  @override
  State<LoginUserAccount> createState() => _LoginUserAccountState();
}

class _LoginUserAccountState extends State<LoginUserAccount> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(
      text: kDebugMode ? 'osamasafty22@gmail.com' : '',
    );
    passwordController = TextEditingController(
      text: kDebugMode ? 'Ooaaoo@12' : '',
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'login_client_title'.tr,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    final FirebaseMessaging _fcm = FirebaseMessaging.instance;

    return GetBuilder<ClientController>(
    builder: (controller) {
      return Form(
        key: _key,
        child: Center(
          child: Container(
            alignment: Alignment.center,
            // color: Colors.yellow,
            margin: EdgeInsets.symmetric(vertical: 50, horizontal: 10),
            width: Get.width - 50,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'login_client_title'.tr,
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
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),

                  InputText(
                    labelText: 'email'.tr,
                    hintText: 'example@example.com'.tr,
                    height: 50,
                    fillColor: Colors.white,
                    controller: emailController,

                    validator: (v) {
                      if (v == null || v.isEmpty || !v.isEmail) {
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
                    obscureText: _obscurePassword,
                    height: 50,
                    controller: passwordController,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 40, minHeight: 40),
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

                  SizedBox(height: 25),
                  InkWell(
                    onTap: () => Get.toNamed('/auth/resetPassword'),
                    child: Text(
                      'resetpassword'.tr,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  SizedBox(height: 8),
                  Obx(
                    () => MainButton(
                      load: controller.isLoading.value,
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
                      onpress: () async {
                        if (_key.currentState!.validate()) {
                          await controller
                              .loginclient(
                                emailController.text.trim().toLowerCase(),
                                passwordController.text.trim(),
                              )
                              .then((v) async {
                                if (v != null) {
                                  log("✅ تم تسجيل دخول العميل: ${v.email}");
                                  // await onUserLogin(v.id.toString());

                                  // log("Subscribed: ${sub.optedIn}");
                                  // log("Token: ${sub.token}");

                                  if (v.status == 'active') {
                                    await FunHelper.savelogindata(
                                      emailController.text.trim(),
                                    );
                                    controller.listenToClient(v.id!);
                                    WidgetsBinding.instance.addPostFrameCallback((_) => Get.offAllNamed('/ClientHome'));
                                    await _fcm.unsubscribeFromTopic(
                                      'employees',
                                    );
                                    await _fcm.subscribeToTopic('clients');
                                    await _fcm.subscribeToTopic('all');
                                  } else {
                                    FunHelper.showsnackbar(
                                      'error'.tr,
                                      'account_not_active_contact_support'.tr,
                                      snackPosition: SnackPosition.TOP,
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                    );
                                  }
                                } else {
                                  FunHelper.showsnackbar(
                                    'error'.tr,
                                    'invalid_email_or_password'.tr,
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                }
                              });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) => Get.toNamed('/auth/login'));
                    },
                    child: Center(
                      child: Text(
                        'are_you_employee'.tr,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ),
                  buildRightsSection(),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  }
}
