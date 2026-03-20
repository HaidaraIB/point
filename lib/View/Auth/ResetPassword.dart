import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:point/Controller/AuthController.dart';
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
      FunHelper.showsnackbar('error'.tr, 'كلمتا المرور غير متطابقتين');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirestoreServices().changeCurrentUserPassword(
        currentPassword: _currentPassController.text.trim(),
        newPassword: _newPassController.text.trim(),
      );
      FunHelper.showsnackbar(
        'success'.tr,
        'تم تغيير كلمة المرور بنجاح',
        backgroundColor: Colors.green,
      );
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
    } on FirebaseAuthException catch (e) {
      FunHelper.showsnackbar('error'.tr, e.message ?? 'فشل تغيير كلمة المرور');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: Scaffold(
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
                      load: isLoading,
                      onpress: onSubmit,
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
