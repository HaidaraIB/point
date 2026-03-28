import 'dart:developer';
import 'dart:math' show min;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/Utils/PasswordValidator.dart';
import 'package:point/View/Auth/Shared/Rights.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

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
    if (kIsWeb) {
      return Scaffold(
        body: GetBuilder<ClientController>(
          builder: (controller) => Form(
            key: _key,
            child: _buildWebAuthLayout(controller),
          ),
        ),
      );
    }
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
      body: GetBuilder<ClientController>(
        builder: (controller) => Form(
          key: _key,
          child: _buildNativeMobileLayout(controller),
        ),
      ),
    );
  }

  Future<void> _submitClientLogin(ClientController controller) async {
    final FirebaseMessaging fcm = FirebaseMessaging.instance;
    if (_key.currentState?.validate() != true) return;
    await controller
        .loginclient(
          emailController.text.trim().toLowerCase(),
          passwordController.text.trim(),
        )
        .then((v) async {
      if (v != null) {
        log("✅ تم تسجيل دخول العميل: ${v.email}");
        if (v.status == 'active') {
          await FunHelper.saveLoginData(
            emailController.text.trim(),
          );
          controller.listenToClient(v.id!);
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Get.offAllNamed('/ClientHome'));
          if (!kIsWeb) {
            try {
              final settings = await fcm.requestPermission(
                alert: true,
                badge: true,
                sound: true,
              );
              final allowed =
                  settings.authorizationStatus == AuthorizationStatus.authorized ||
                  settings.authorizationStatus ==
                      AuthorizationStatus.provisional;
              if (allowed) {
                await fcm.unsubscribeFromTopic(
                  'employees',
                );
                await fcm.subscribeToTopic('clients');
                await fcm.subscribeToTopic('all');
              } else {
                log(
                  'Client login notification permission denied: ${settings.authorizationStatus}',
                );
              }
            } catch (e) {
              log('Client FCM setup failed: $e');
            }
          }
        } else {
          FunHelper.showSnackbar(
            'error'.tr,
            'account_not_active_contact_support'.tr,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        FunHelper.showSnackbar(
          'error'.tr,
          'invalid_email_or_password'.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    });
  }

  /// نفس تخطيط شاشة الموظف على الويب: صورة جانبية + نموذج (عرض ≥ [Responsive.authSplitMinWidth]).
  Widget _buildWebAuthLayout(ClientController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showAuthSplit =
            Responsive.showAuthSplitLayout(constraints.maxWidth);
        final viewportMinHeight =
            constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
        final formColumn = _buildFormColumn(
          controller,
          useWebEmployeeChrome: true,
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
    );
  }

  Widget _buildNativeMobileLayout(ClientController controller) {
    return Center(
      child: Container(
        alignment: Alignment.center,
        margin: EdgeInsets.symmetric(vertical: 50, horizontal: 10),
        width: Get.width - 50,
        child: SingleChildScrollView(
          child: _buildFormColumn(
            controller,
            useWebEmployeeChrome: false,
          ),
        ),
      ),
    );
  }

  Widget _buildFormColumn(
    ClientController controller, {
    required bool useWebEmployeeChrome,
  }) {
    final inputHeight = useWebEmployeeChrome ? 42.0 : 50.0;
    final subtitleSize = useWebEmployeeChrome ? 13.0 : 12.0;
    final linkSize = useWebEmployeeChrome ? 13.0 : 12.0;
    final afterPasswordGap = useWebEmployeeChrome ? 10.0 : 25.0;
    final beforeButtonGap = useWebEmployeeChrome ? 25.0 : 8.0;

    return Column(
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
          style: TextStyle(color: Colors.grey, fontSize: subtitleSize),
        ),
        InputText(
          labelText: 'email'.tr,
          hintText: useWebEmployeeChrome ? 'email'.tr : 'example@example.com'.tr,
          height: inputHeight,
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
          hintText: useWebEmployeeChrome ? 'password'.tr : ''.tr,
          labelText: 'password'.tr,
          obscureText: _obscurePassword,
          height: inputHeight,
          controller: passwordController,
          fillColor: Colors.white,
          textInputType: TextInputType.visiblePassword,
          suffixIcon: useWebEmployeeChrome
              ? InkWell(
                  onTap: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
                    size: 12,
                  ),
                )
              : IconButton(
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
        SizedBox(height: afterPasswordGap),
        InkWell(
          onTap: () => Get.toNamed('/auth/forgetPassword'),
          child: Text(
            'forgotpassword'.tr,
            style: TextStyle(color: Colors.grey, fontSize: linkSize),
          ),
        ),
        SizedBox(height: beforeButtonGap),
        Obx(
          () => MainButton(
            load: controller.isLoading.value,
            icon: false,
            height: 40,
            borderSize: 10,
            margin: EdgeInsets.all(0),
            linearGradient: LinearGradient(
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
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomRight,
            ),
            title: 'login'.tr,
            onPressed: () => _submitClientLogin(controller),
          ),
        ),
        SizedBox(height: 10),
        InkWell(
          onTap: () {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => Get.toNamed('/auth/login'));
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
    );
  }
}
