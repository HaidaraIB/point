import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
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

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Get.back();
      return;
    }
    final isClientFlow = Get.isRegistered<ClientController>() &&
        Get.find<ClientController>().currentClient.value != null;
    Get.offAllNamed(isClientFlow ? '/auth/LoginUserAccount' : '/auth/login');
  }

  PreferredSizeWidget _buildForgetPasswordAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
        onPressed: _goBack,
      ),
      title: Text(
        'forgotpassword'.tr,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirestoreServices().sendPasswordResetEmail(_emailController.text);
      FunHelper.showSnackbar(
        'success'.tr,
        'auth.forget_password_sent'.tr,
        backgroundColor: Colors.green,
      );
    } on FirebaseAuthException catch (e) {
      FunHelper.showSnackbar(
        'error'.tr,
        e.message ?? 'auth.recovery_send_failed'.tr,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBody() {
    return Form(
      key: _formKey,
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
                controller: _emailController,
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
                title: 'confirm'.tr,
                load: _isLoading,
                onPressed: _submit,
              ),
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
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: _buildForgetPasswordAppBar(),
      body: _buildBody(),
    );
    return Responsive(
      mobile: scaffold,
      tablet: scaffold,
      desktop: scaffold,
    );
  }
}
