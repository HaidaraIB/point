import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ReadOnlyAccountEmailField.dart';

/// شاشة تعديل الاسم والصورة للموظف الحالي (لوحة الموظف).
class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final c = Get.find<HomeController>();
    final emp = c.currentemployee.value;
    _nameController = TextEditingController(text: emp?.name ?? '');
    c.uploadedFilesPaths.assignAll(
      emp != null && (emp.image ?? '').trim().isNotEmpty ? [emp.image!.trim()] : [],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    Get.find<HomeController>().uploadedFilesPaths.clear();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final c = Get.find<HomeController>();
    final emp = c.currentemployee.value;
    final imageUrl =
        c.uploadedFilesPaths.isNotEmpty
            ? c.uploadedFilesPaths.last
            : emp?.image;
    final ok = await c.updateMyProfile(
      name: _nameController.text,
      imageUrl: imageUrl,
    );
    if (!mounted) return;
    if (ok) {
      c.uploadedFilesPaths.clear();
    }
  }

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
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
              child: Obx(() {
                final emp = controller.currentemployee.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: InkWell(
                        onTap: () async {
                          await controller.pickoneImage().then((v) async {
                            if (v.isNotEmpty) {
                              await controller.uploadFiles(
                                filePathOrBytes: v.first.bytes!,
                                fileName: v.first.name,
                              );
                              if (mounted) setState(() {});
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
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.person,
                                          size: 50,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                    : (emp?.image != null &&
                                            emp!.image!.trim().isNotEmpty)
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(50),
                                      child: Image.network(
                                        emp.image!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.camera_alt,
                                          size: 50,
                                          color: AppColors.primary,
                                        ),
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
                    const SizedBox(height: 20),
                    InputText(
                      labelText: 'employee.profile.name'.tr,
                      hintText: 'entername'.tr,
                      height: 48,
                      fillColor: Colors.white,
                      controller: _nameController,
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty) ? ' ' : null,
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    ReadOnlyAccountEmailField(
                      email: emp?.email ?? '',
                      height: 48,
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                      fillColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    _readOnlyLine(
                      label: 'employee.profile.role'.tr,
                      value: (emp?.role ?? '').trim().isEmpty
                          ? '—'
                          : emp!.role.tr,
                    ),
                    const SizedBox(height: 12),
                    _readOnlyLine(
                      label: 'employee.profile.department'.tr,
                      value: _departmentLabel(emp?.department),
                    ),
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
                          onPressed:
                              controller.isLoading.value ? null : _save,
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
                                    'employee.profile.save'.tr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          );
        },
      ),
    );
  }

  static String _departmentLabel(String? department) {
    final d = (department ?? '').trim();
    if (d.isEmpty) return '—';
    return StorageKeys.semanticDepartmentLabelKey(d).tr;
  }

  Widget _readOnlyLine({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
          ),
        ),
      ],
    );
  }
}
