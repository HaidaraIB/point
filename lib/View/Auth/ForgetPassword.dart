import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/instance_manager.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

class ForgetPassword extends StatefulWidget {
  const ForgetPassword({super.key});

  @override
  State<ForgetPassword> createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends State<ForgetPassword> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirestoreServices().sendPasswordResetEmail(_emailController.text);
      FunHelper.showsnackbar(
        'success'.tr,
        'auth.forget_password_sent'.tr,
        backgroundColor: Colors.green,
      );
    } on FirebaseAuthException catch (e) {
      FunHelper.showsnackbar(
        'error'.tr,
        e.message ?? 'auth.recovery_send_failed'.tr,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: Scaffold(
        body: _buildDesktopLayout(
          _formKey,
          _emailController,
          _isLoading,
          _submit,
        ),
      ),
      tablet: Scaffold(
        body: _buildDesktopLayout(
          _formKey,
          _emailController,
          _isLoading,
          _submit,
        ),
      ),
      desktop: Scaffold(body: _buildDesktopLayout(_formKey, _emailController, _isLoading, _submit)),
    );
  }
}

// --- IGNORE ---
Widget _buildDesktopLayout(
  GlobalKey<FormState> formKey,
  TextEditingController emailController,
  bool isLoading,
  VoidCallback onSubmit,
) {
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
          child: Form(
            key: formKey,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'forgotpassword'.tr,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  wordSpacing: 1.2,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 10),

              Text(
                'enteremailandwaitcode'.tr,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              InputText(
                hintText: 'example@gmail.com'.tr,
                labelText: 'email'.tr,
                controller: emailController,
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
                title: 'confirm'.tr,
                load: isLoading,
                onpress: onSubmit,
              ),
            ],
            ),
          ),
        ),
      ),
    ],
  );
}
