import 'dart:developer';
import 'dart:math' show min;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/instance_manager.dart';
import 'package:point/Controller/AuthController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/View/Auth/Shared/Rights.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

class LoginView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final showBackButton = !kIsWeb;
    return Responsive(
      mobile: Scaffold(
        appBar: showBackButton ? _buildEmployeeLoginAppBar() : null,
        body: _buildDesktopLayout(),
      ),
      tablet: Scaffold(
        appBar: showBackButton ? _buildEmployeeLoginAppBar() : null,
        body: _buildDesktopLayout(),
      ),
      desktop: Scaffold(body: _buildDesktopLayout()),
    );
  }

  static PreferredSizeWidget _buildEmployeeLoginAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
        onPressed: () => Get.back(),
      ),
      title: Text(
        'login_employee_title'.tr,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }
}

// --- IGNORE ---
Widget _buildDesktopLayout() {
  final _key = GlobalKey<FormState>();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  return GetBuilder<AuthController>(
    init: AuthController(),
    builder: (controller) {
      return Form(
        key: _key,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showAuthSplit =
                Responsive.showAuthSplitLayout(constraints.maxWidth);
            final viewportMinHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : 0.0;
            final formColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'login_employee_title'.tr,
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
                        hintText: 'email'.tr,
                        labelText: 'email'.tr,
                        textInputType: TextInputType.emailAddress,
                        controller: controller.email,
                        height: 42,
                        fillColor: Colors.white,

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
                        hintText: 'password'.tr,
                        labelText: 'password'.tr,
                        controller: controller.pass,
                        obscureText: controller.obSecure,
                        height: 42,
                        fillColor: Colors.white,
                        textInputType: TextInputType.visiblePassword,
                        suffixIcon: InkWell(
                          onTap: () {
                            controller.changeObsecure();
                          },
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
                          return null;
                        },
                        borderRadius: 5,
                        borderColor: Colors.grey.shade300,
                      ),
                      SizedBox(height: 10),
                      InkWell(
                        onTap: () {
                          Get.toNamed('/auth/forgetpassword');
                        },
                        child: Text(
                          'forgotpassword'.tr,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                      SizedBox(height: 25),
                      Obx(
                        () => MainButton(
                          icon: false,
                          height: 40,
                          bordersize: 10,
                          load: Get.find<HomeController>().isLoading.value,
                          margin: EdgeInsets.all(0),
                          onpress: () {
                            if (_key.currentState!.validate()) {
                              Get.find<HomeController>()
                                  .loginClient(
                                    controller.email.text.trim(),
                                    controller.pass.text.trim(),
                                  )
                                  .then((v) async {
                                    if (v != null) {
                                      log("✅ تم تسجيل دخول الموظف: ${v.email}");
                                      log(v.status.toString());
                                      if (v.status == 'active') {

                                        await FunHelper.savelogindata(
                                          controller.email.text.trim(),
                                        );
                                        if (!kIsWeb) {
                                          await _fcm.subscribeToTopic('all');
                                        }
                                        // fetchnotification + listenToClient تُستدعى داخل loginClient()
                                        // بعد نجاح Auth حتى يمرّ AuthMiddleware قبل Get.toNamed.
                                        if (v.role == 'supervisor') {
                                          if (!kIsWeb) {
                                            await _fcm.unsubscribeFromTopic(
                                              'clients',
                                            );
                                            await _fcm.subscribeToTopic(
                                              'employees',
                                            );
                                          }
                                          Get.toNamed('/');
                                        } else if (v.role == 'admin') {
                                          Get.toNamed('/');
                                        } else if (v.role == 'employee') {
                                          if (!kIsWeb) {
                                            await _fcm.unsubscribeFromTopic(
                                              'clients',
                                            );
                                            await _fcm.subscribeToTopic(
                                              'employees',
                                            );
                                          }

                                          Get.toNamed('/employeeDashboard');
                                        } else if (v.role == 'accountholder') {
                                          Get.toNamed('/');
                                        }
                                        await Get.find<HomeController>()
                                            .setupFCM(v.id);
                                      } else {
                                        FunHelper.showsnackbar(
                                          'error'.tr,
                                          'account_not_active_contact_support'
                                              .tr,
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
                        ),
                      ),
                      SizedBox(height: 10),
                      InkWell(
                        onTap: () => Get.toNamed('/auth/LoginUserAccount'),
                        child: Center(
                          child: Text(
                            'are_you_client'.tr,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ),

                      buildRightsSection(),
                    ],
            );

            if (!showAuthSplit) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewportMinHeight),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: min(480, constraints.maxWidth - 20),
                        ),
                        child: formColumn,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: Responsive.authSplitCoverFlex,
                  child: Image.asset(
                    AppImages.images.authcover,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(color: Colors.grey.shade200);
                    },
                  ),
                ),
                Expanded(
                  flex: Responsive.authSplitFormFlex,
                  child: LayoutBuilder(
                    builder: (context, colConstraints) {
                      const verticalPad = 50.0;
                      final minScrollChildHeight = colConstraints.maxHeight >
                              verticalPad * 2
                          ? colConstraints.maxHeight - verticalPad * 2
                          : colConstraints.maxHeight;
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          vertical: verticalPad,
                          horizontal: 40,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: minScrollChildHeight,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: min(
                                  480,
                                  colConstraints.maxWidth - 80,
                                ),
                              ),
                              child: formColumn,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
