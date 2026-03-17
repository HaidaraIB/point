import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Auth/CreateUserAccount.dart' show validatePasswordStrong;
import 'package:point/View/Shared/InputText.dart';

/// Mobile-only full-screen add/edit client form.
/// Opened when showAddEmployeeDialog is called on mobile; desktop keeps the dialog.
class ClientFormMobilePage extends StatefulWidget {
  final ClientModel? model;

  const ClientFormMobilePage({super.key, this.model});

  @override
  State<ClientFormMobilePage> createState() => _ClientFormMobilePageState();
}

class _ClientFormMobilePageState extends State<ClientFormMobilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController descController;
  late final TextEditingController startDateController;
  late final TextEditingController endDateController;

  DateTime? startAt;
  DateTime? endAt;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    nameController = TextEditingController(text: m?.name);
    emailController = TextEditingController(text: m?.email);
    passwordController = TextEditingController(text: m?.password);
    descController = TextEditingController(text: m?.description);
    startDateController = TextEditingController(text: FunHelper.formatdate(m?.startAt));
    endDateController = TextEditingController(text: FunHelper.formatdate(m?.endAt));
    startAt = m?.startAt;
    endAt = m?.endAt;
    Get.find<HomeController>().uploadedFilesPaths.assignAll(
      m != null && m.image != null ? [m.image!] : [],
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    descController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: startAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: startAt != null
          ? TimeOfDay.fromDateTime(startAt!)
          : TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() {
      startAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      startDateController.text = FunHelper.formatdate(startAt) ?? '';
    });
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: endAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: endAt != null
          ? TimeOfDay.fromDateTime(endAt!)
          : TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() {
      endAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      endDateController.text = FunHelper.formatdate(endAt) ?? '';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (startAt == null || endAt == null) {
      Get.snackbar('تنبيه', 'يرجى اختيار تاريخ البداية والنهاية');
      return;
    }
    final controller = Get.find<HomeController>();
    final model = widget.model;

    if (model == null) {
      final success = await controller.addClient(
        ClientModel(
          id: '${Random().nextInt(100000)}',
          name: nameController.text,
          email: emailController.text,
          image: controller.uploadedFilesPaths.lastOrNull,
          description: descController.text,
          status: 'active',
          createdAt: DateTime.now(),
          password: passwordController.text,
          startAt: startAt,
          endAt: endAt,
        ),
      );
      if (!mounted) return;
      if (success) {
        controller.uploadedFilesPaths.clear();
        Get.back();
      }
    } else {
      final newPassword = passwordController.text.trim();
      final success = await controller.updateClient(
        model.copyWith(
          name: nameController.text,
          email: emailController.text,
          createdAt: DateTime.now(),
          password: newPassword.isEmpty ? model.password : newPassword,
          image: controller.uploadedFilesPaths.lastOrNull,
          startAt: startAt,
          endAt: endAt,
          description: descController.text,
        ),
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
          widget.model == null ? 'addclient'.tr : '${'edit'.tr} العميل',
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
                  Center(
                    child: InkWell(
                      onTap: () async {
                        final v = await controller.pickoneImage();
                        if (v.isNotEmpty) {
                          controller.uploadFiles(
                            filePathOrBytes: v.first.bytes!,
                            fileName: v.first.name,
                          );
                        }
                      },
                      child: Obx(
                        () => CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          radius: 50,
                          child: controller.uploadedFilesPaths.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: Image.network(
                                    controller.uploadedFilesPaths.last,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(Icons.camera_alt, size: 50, color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                  InputText(
                    labelText: 'email'.tr,
                    hintText: 'example@example.com'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    textInputType: TextInputType.emailAddress,
                    controller: emailController,
                    validator: (v) {
                      if (v == null || v.isEmpty || !v.toString().isEmail) return ' ';
                      return null;
                    },
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    hintText: widget.model != null ? 'leave_empty_unchanged'.tr : '******'.tr,
                    labelText: 'password'.tr,
                    obscureText: obscurePassword,
                    controller: passwordController,
                    height: 48,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                    validator: (v) {
                      if (widget.model != null && (v == null || v.isEmpty)) return null;
                      return validatePasswordStrong(v);
                    },
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: 'desc'.tr,
                    hintText: '',
                    expanded: true,
                    height: 80,
                    fillColor: Colors.white,
                    textInputType: TextInputType.multiline,
                    controller: descController,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    ontap: _pickStartDate,
                    labelText: 'startat'.tr,
                    hintText: '1/10/2025'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: startDateController,
                    readonly: true,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    suffixIcon: Icon(CupertinoIcons.calendar, color: Colors.grey.shade600),
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    ontap: _pickEndDate,
                    labelText: 'endat'.tr,
                    hintText: '1/10/2026'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: endDateController,
                    readonly: true,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    suffixIcon: Icon(CupertinoIcons.calendar, color: Colors.grey.shade600),
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
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
                        onPressed: controller.isLoading.value ? null : _submit,
                        child: controller.isLoading.value
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'تأكيد',
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
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        controller.uploadedFilesPaths.clear();
                        Get.back();
                      },
                      child: Text('إلغاء'.tr),
                    ),
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
