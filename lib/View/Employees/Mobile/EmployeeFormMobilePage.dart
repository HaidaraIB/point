import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ReadOnlyAccountEmailField.dart';
import 'package:point/Utils/PasswordValidator.dart';
import 'package:uuid/uuid.dart';

/// Mobile-only full-screen add/edit employee form.
/// Opened when showAddEmployeeDialog is called on mobile; desktop keeps the dialog.
class EmployeeFormMobilePage extends StatefulWidget {
  final EmployeeModel? model;

  const EmployeeFormMobilePage({super.key, this.model});

  @override
  State<EmployeeFormMobilePage> createState() => _EmployeeFormMobilePageState();
}

class _EmployeeFormMobilePageState extends State<EmployeeFormMobilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;

  bool obscurePassword = true;
  String selectedRole = "employee";
  String selectedDepartment = "cat1";
  static const List<String> _roles = ["supervisor", "admin", "employee"];

  bool get _canEditCredentials {
    final m = widget.model;
    if (m == null) return true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final au = m.authUid;
    return uid != null &&
        uid.isNotEmpty &&
        au != null &&
        au.isNotEmpty &&
        uid == au;
  }

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    nameController = TextEditingController(text: m?.name);
    emailController = TextEditingController(text: m?.email);
    passwordController = TextEditingController();
    selectedRole = m?.role ?? "employee";
    selectedDepartment = m?.department ?? "cat1";
    final controller = Get.find<HomeController>();
    controller.uploadedFilesPaths.assignAll(
      m != null && m.image != null ? [m.image!] : [],
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = Get.find<HomeController>();
    final model = widget.model;
    final departmentToSave = selectedRole == 'employee' ? selectedDepartment : null;

    if (model == null) {
      final success = await controller.addEmployee(
        password:
            passwordController.text.trim().isEmpty
                ? 'TempPass@123'
                : passwordController.text.trim(),
        EmployeeModel(
          id: const Uuid().v4(),
          name: nameController.text,
          email: emailController.text,
          role: selectedRole,
          department: departmentToSave,
          status: 'active',
          createdAt: DateTime.now(),
          image:
              controller.uploadedFilesPaths.isNotEmpty
                  ? controller.uploadedFilesPaths.last
                  : null,
        ),
      );
      if (!mounted) return;
      if (success) {
        controller.uploadedFilesPaths.clear();
        Get.back();
      }
    } else {
      final success = await controller.updateEmployee(
        model.copyWith(
          name: nameController.text,
          email:
              _canEditCredentials
                  ? emailController.text
                  : (model.email ?? ''),
          role: selectedRole,
          department: departmentToSave,
          image:
              controller.uploadedFilesPaths.isNotEmpty
                  ? controller.uploadedFilesPaths.last
                  : model.image,
        ),
        newPassword:
            !_canEditCredentials || passwordController.text.trim().isEmpty
                ? null
                : passwordController.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        controller.uploadedFilesPaths.clear();
        Get.back();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.model == null ? 'addemployee'.tr : 'editemployee'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: GetBuilder<HomeController>(
        builder: (controller) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: InkWell(
                      onTap: () async {
                        await controller.pickoneImage().then((v) {
                          if (v.isNotEmpty) {
                            controller.uploadFiles(
                              filePathOrBytes: v.first.bytes!,
                              fileName: v.first.name,
                            );
                          }
                        });
                      },
                      child: Obx(
                        () => CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          radius: 50,
                          child:
                              controller.uploadedFilesPaths.isNotEmpty
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Image.network(
                                      controller.uploadedFilesPaths.last,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                  : Icon(
                                    Icons.camera_alt,
                                    size: 50,
                                    color: AppColors.primary,
                                  ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: 'name'.tr,
                    hintText: 'entername'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: nameController,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  if (widget.model == null || _canEditCredentials) ...[
                    InputText(
                      labelText: 'email'.tr,
                      hintText: 'example@example.com'.tr,
                      height: 48,
                      fillColor: Colors.white,
                      textInputType: TextInputType.emailAddress,
                      controller: emailController,
                      validator: (v) {
                        if (v == null || v.isEmpty || !v.toString().isEmail) {
                          return ' ';
                        }
                        return null;
                      },
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    InputText(
                      hintText:
                          widget.model == null
                              ? '******'.tr
                              : 'leave_empty_unchanged'.tr,
                      labelText: 'password'.tr,
                      obscureText: obscurePassword,
                      controller: passwordController,
                      height: 48,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () {
                          setState(() => obscurePassword = !obscurePassword);
                        },
                      ),
                      validator: (v) {
                        if (v == null || v.toString().trim().isEmpty) {
                          return null;
                        }
                        return validatePasswordStrong(v);
                      },
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    ReadOnlyAccountEmailField(
                      email: widget.model?.email ?? '',
                      height: 48,
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                      fillColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                  ],
                  DynamicDropdown<String>(
                    items:
                        _roles
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              ),
                            )
                            .toList(),
                    value: selectedRole,
                    label: 'role'.tr,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                    height: 48,
                    fillColor: Colors.white,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedRole = value;
                          if (selectedRole != 'employee') {
                            selectedDepartment = "cat1";
                          }
                        });
                      }
                    },
                  ),
                  if (selectedRole == 'employee') ...[
                    const SizedBox(height: 16),
                    DynamicDropdown<String>(
                      items:
                          StorageKeys.departments
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d.tr),
                                ),
                              )
                              .toList(),
                      value: selectedDepartment,
                      label: 'employees.department'.tr,
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                      height: 48,
                      fillColor: Colors.white,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedDepartment = value);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 32),
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: controller.isLoading.value ? null : _submit,
                        child:
                            controller.isLoading.value
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  'common.confirm'.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      controller.uploadedFilesPaths.clear();
                      Get.back();
                    },
                    child: Text('common.cancel'.tr),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
