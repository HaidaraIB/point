import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:point/Controller/AuthController.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/Utils/PasswordValidator.dart';
import 'package:point/View/Auth/Shared/Rights.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

class ResetPassword extends StatefulWidget {
  const ResetPassword({super.key});

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _key = GlobalKey<FormState>();
  bool _isLoading = false;

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Get.back();
      return;
    }
    final isClientFlow = Get.isRegistered<ClientController>() &&
        Get.find<ClientController>().currentClient.value != null;
    Get.offAllNamed(isClientFlow ? '/auth/LoginUserAccount' : '/auth/login');
  }

  PreferredSizeWidget _buildResetPasswordAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
        onPressed: _goBack,
      ),
      title: Text(
        'resetpassword'.tr,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_key.currentState!.validate()) return;
    if (_newPassController.text.trim() != _confirmPassController.text.trim()) {
      FunHelper.showsnackbar('error'.tr, 'passwordmustmatch'.tr);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirestoreServices().changeCurrentUserPassword(
        currentPassword: _currentPassController.text.trim(),
        newPassword: _newPassController.text.trim(),
      );
      final isClientFlow = Get.isRegistered<ClientController>() &&
          Get.find<ClientController>().currentClient.value != null;
      FunHelper.showsnackbar(
        'success'.tr,
        'auth.password_changed_success'.tr,
        backgroundColor: Colors.green,
      );
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().clearEmployeeSession();
      }
      if (Get.isRegistered<ClientController>()) {
        Get.find<ClientController>().currentClient.value = null;
      }
      await FirestoreServices().signOut();
      await FunHelper.removelogindata();
      Get.offAllNamed(
        isClientFlow ? '/auth/LoginUserAccount' : '/auth/login',
      );
    } on FirebaseAuthException catch (e) {
      FunHelper.showsnackbar(
        'error'.tr,
        e.message ?? 'auth.reset_password_failed'.tr,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: Scaffold(
        appBar: _buildResetPasswordAppBar(),
        body: _buildDesktopLayout(
          _key,
          _currentPassController,
          _newPassController,
          _confirmPassController,
          _isLoading,
          _resetPassword,
        ),
      ),
      tablet: Scaffold(
        appBar: _buildResetPasswordAppBar(),
        body: _buildDesktopLayout(
          _key,
          _currentPassController,
          _newPassController,
          _confirmPassController,
          _isLoading,
          _resetPassword,
        ),
      ),
      desktop: Scaffold(
        appBar: _buildResetPasswordAppBar(),
        body: _buildDesktopLayout(
          _key,
          _currentPassController,
          _newPassController,
          _confirmPassController,
          _isLoading,
          _resetPassword,
        ),
      ),
    );
  }
}

// --- IGNORE ---
Widget _buildDesktopLayout(
  GlobalKey<FormState> formKey,
  TextEditingController currentPassController,
  TextEditingController newPassController,
  TextEditingController confirmPassController,
  bool isLoading,
  VoidCallback onSubmit,
) {
  return GetBuilder<AuthController>(
    builder: (controller) {
      return Form(
        key: formKey,
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
                  labelText: 'password'.tr,
                  height: 42,
                  fillColor: Colors.white,
                  controller: currentPassController,
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
                    return null;
                  },
                  borderRadius: 5,
                  borderColor: Colors.grey.shade300,
                ),
                InputText(
                  hintText: '********'.tr,
                  labelText: 'newpass'.tr,
                  height: 42,
                  fillColor: Colors.white,
                  controller: newPassController,
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
                  controller: confirmPassController,
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
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomRight,
                  ),
                  title: 'login'.tr,
                  load: isLoading,
                  onpress: onSubmit,
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
