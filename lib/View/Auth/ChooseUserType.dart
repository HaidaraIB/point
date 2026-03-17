import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/View/Auth/Shared/Rights.dart';

/// شاشة اختيار نوع المستخدم (عميل / موظف) - بدون تسجيل حساب جديد
class ChooseUserType extends StatelessWidget {
  const ChooseUserType({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // الشعار
                Image.asset(
                  AppImages.images.logocolored,
                  width: Get.width * 0.6,
                  height: 80,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 32),
                // عنوان اختيار نوع المستخدم
                Text(
                  'choose_user_type'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 28),
                // زر عميل
                _UserTypeButton(
                  label: 'user_type_client'.tr,
                  onTap: () => Get.toNamed('/auth/LoginUserAccount'),
                ),
                SizedBox(height: 14),
                // زر موظف
                _UserTypeButton(
                  label: 'user_type_employee'.tr,
                  onTap: () => Get.toNamed('/auth/login'),
                ),
                SizedBox(height: 40),
                buildRightsSection(),
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

  const _UserTypeButton({
    Key? key,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
