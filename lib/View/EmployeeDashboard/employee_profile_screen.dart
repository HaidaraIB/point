import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/EmployeeDashboard/employee_profile_form.dart';

/// شاشة تعديل الاسم والصورة للموظف الحالي (لوحة الموظف — موبايل).
class EmployeeProfileScreen extends StatelessWidget {
  const EmployeeProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 24;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'employee.profile.title'.tr,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: EmployeeProfileForm(
        closeOnSuccess: false,
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
      ),
    );
  }
}
