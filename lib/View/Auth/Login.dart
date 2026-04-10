import 'package:point/Utils/app_log.dart';
import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/instance_manager.dart';
import 'package:point/Controller/AuthController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/View/Auth/Shared/Rights.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/app_version_label.dart';
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

String _extractDiagnosticCode(Object error) {
  final raw = error.toString().toUpperCase();
  final match = RegExp(r'FIREBASE_AUTH_([A-Z0-9\-_]+)').firstMatch(raw);
  if (match != null && (match.group(1)?.isNotEmpty ?? false)) {
    return 'AUTH_${match.group(1)!}';
  }
  if (raw.contains('AUTH_UID_MISMATCH')) return 'AUTH_UID_MISMATCH';
  if (raw.contains('NETWORK')) return 'NETWORK_REQUEST_FAILED';
  return 'LOGIN_FAILED';
}

String _buildLoginErrorMessage(Object error) {
  final key = FunHelper.mapErrorToKey(error);
  final translated = key.tr;
  final fallback = 'حدث خطأ غير متوقع';
  final base = translated == key ? fallback : translated;
  return '$base (${_extractDiagnosticCode(error)})';
}

Widget _buildDesktopLayout() {
  return GetBuilder<AuthController>(
    init: AuthController(),
    builder:
        (controller) => _EmployeeLoginDesktopLayout(controller: controller),
  );
}

class _EmployeeLoginDesktopLayout extends StatefulWidget {
  final AuthController controller;

  const _EmployeeLoginDesktopLayout({required this.controller});

  @override
  State<_EmployeeLoginDesktopLayout> createState() =>
      _EmployeeLoginDesktopLayoutState();
}

class _EmployeeLoginDesktopLayoutState
    extends State<_EmployeeLoginDesktopLayout> {
  final _formKey = GlobalKey<FormState>();
  late final FocusNode _emailFocus;
  late final FocusNode _passwordFocus;

  @override
  void initState() {
    super.initState();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submitEmployeeLogin() async {
    if (_formKey.currentState?.validate() != true) return;
    final c = widget.controller;
    try {
      final v = await Get.find<HomeController>().loginClient(
        c.email.text.trim(),
        c.pass.text.trim(),
      );
      if (v != null) {
        appLog("✅ تم تسجيل دخول الموظف: ${v.email}");
        appLog(v.status.toString());
        if (v.status == 'active') {
          Get.offAllNamed('/sessionSetup');
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
    } catch (e, st) {
      final code = _extractDiagnosticCode(e);
      appLog(
        'Employee login failed: type=${e.runtimeType}, message=$e',
        stackTrace: st,
      );
      await FirestoreServices.logClientDiagnosticError(
        source: 'LoginView.employeeLogin',
        code: code,
        error: e,
        stackTrace: st,
        extra: {
          'platform': defaultTargetPlatform.name,
          'isWeb': kIsWeb,
          'email': c.email.text.trim(),
        },
      );
      FunHelper.showSnackbar(
        'error'.tr,
        _buildLoginErrorMessage(e),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showAuthSplit = Responsive.showAuthSplitLayout(
            constraints.maxWidth,
          );
          final viewportMinHeight =
              constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
          final authFormCore = AutofillGroup(
            child: Column(
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
                  focusNode: _emailFocus,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
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
                  focusNode: _passwordFocus,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.go,
                  onFieldSubmitted: (_) => _submitEmployeeLogin(),
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
                    Get.toNamed('/auth/forgetPassword');
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
                    borderSize: 10,
                    load: Get.find<HomeController>().isLoading.value,
                    margin: EdgeInsets.all(0),
                    onPressed: _submitEmployeeLogin,
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
            ),
          );

          final loginVersionCorner = Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: LoginScreenVersionCornerLabel(),
            ),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [authFormCore, loginVersionCorner],
                      ),
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
                    final minScrollChildHeight =
                        colConstraints.maxHeight > verticalPad * 2
                            ? colConstraints.maxHeight - verticalPad * 2
                            : colConstraints.maxHeight;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
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
                                  child: authFormCore,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            40,
                            0,
                            40,
                            16,
                          ),
                          child: SafeArea(
                            top: false,
                            minimum: EdgeInsets.zero,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: LoginScreenVersionCornerLabel(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
