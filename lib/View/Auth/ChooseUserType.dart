import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/brand_logo.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Auth/Shared/Rights.dart';

/// شاشة اختيار نوع المستخدم (عميل / موظف) - بدون تسجيل حساب جديد
class ChooseUserType extends StatelessWidget {
  const ChooseUserType({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // الشعار
                BrandLogo(
                  width: Get.width * 0.6,
                  height: 80,
                ),
                SizedBox(height: 32),
                // عنوان اختيار نوع المستخدم
                Text(
                  'choose_user_type'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: appTheme.primaryText,
                  ),
                ),
                SizedBox(height: 28),
                // زر عميل
                _UserTypeButton(
                  label: 'user_type_client'.tr,
                  gradient: AppColors.authLoginButtonGradient,
                  onTap: () => Get.toNamed('/auth/LoginUserAccount'),
                ),
                SizedBox(height: 14),
                // زر موظف
                _UserTypeButton(
                  label: 'user_type_employee'.tr,
                  onTap: () => Get.toNamed('/auth/login'),
                ),
                SizedBox(height: 40),
                buildRightsSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTypeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final LinearGradient? gradient;

  const _UserTypeButton({
    Key? key,
    required this.label,
    required this.onTap,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final radius = BorderRadius.circular(12);
    final isPrimary = gradient != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            gradient: gradient,
            color: isPrimary ? null : appTheme.unselected,
            borderRadius: radius,
            border: isPrimary ? null : Border.all(color: appTheme.border, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : appTheme.primaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
