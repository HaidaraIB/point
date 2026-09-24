import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/EmployeeDashboard/employee_profile_form.dart';

/// شاشة تعديل الاسم والصورة للموظف الحالي (لوحة الموظف — موبايل).
class EmployeeProfileScreen extends StatelessWidget {
  const EmployeeProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    final theme = context.appTheme;

    return Scaffold(
      backgroundColor: theme.pageBackground,
      appBar: AppBar(
        backgroundColor: theme.navSurface,
        foregroundColor: theme.onNavSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'employee.profile.title'.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: theme.onNavSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: theme.onNavSurface,
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
