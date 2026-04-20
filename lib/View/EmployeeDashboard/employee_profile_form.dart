import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/app_version_label.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ReadOnlyAccountEmailField.dart';

/// نموذج الملف الشخصي (اسم + صورة + حقوق قراءة فقط) — يُستخدم في شاشة الموبايل وفي حوار الويب.
class EmployeeProfileForm extends StatefulWidget {
  const EmployeeProfileForm({
    super.key,
    this.closeOnSuccess = false,
    this.padding = EdgeInsets.zero,
  });

  /// عند الحفظ الناجح يُغلق الحوار (يُستخدم مع [showEmployeeProfileDialog]).
  final bool closeOnSuccess;

  final EdgeInsetsGeometry padding;

  @override
  State<EmployeeProfileForm> createState() => _EmployeeProfileFormState();
}

class _EmployeeProfileFormState extends State<EmployeeProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String _lastHydratedEmployeeId = '';

  @override
  void initState() {
    super.initState();
    final c = Get.find<HomeController>();
    final emp = c.currentEmployee.value;
    _nameController = TextEditingController(text: emp?.name ?? '');
    c.uploadedFilesPaths.assignAll(
      emp != null && (emp.image ?? '').trim().isNotEmpty ? [emp.image!.trim()] : [],
    );
  }

  void _hydrateFromEmployee(HomeController controller) {
    final emp = controller.currentEmployee.value;
    if (emp == null) return;

    final employeeId = (emp.id ?? '').trim();
    final shouldHydrateName =
        _lastHydratedEmployeeId != employeeId ||
        _nameController.text.trim().isEmpty;
    if (shouldHydrateName) {
      final name = (emp.name ?? '').trim();
      _nameController.value = TextEditingValue(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
      );
      _lastHydratedEmployeeId = employeeId;
    }

    final image = (emp.image ?? '').trim();
    if (controller.uploadedFilesPaths.isEmpty && image.isNotEmpty) {
      controller.uploadedFilesPaths.assignAll([image]);
    }
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
    final emp = c.currentEmployee.value;
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
      if (widget.closeOnSuccess) {
        Navigator.of(context).pop();
      }
    }
  }

  static String departmentsLabel(EmployeeModel? emp) {
    final list = emp?.departments ?? const <String>[];
    if (list.isEmpty) return '—';
    return list
        .map((d) => StorageKeys.semanticDepartmentLabelKey(d).tr)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: widget.padding,
            child: Obx(() {
              final emp = controller.currentEmployee.value;
              _hydrateFromEmployee(controller);
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
                    value:
                        (emp?.role ?? '').trim().isEmpty
                            ? '—'
                            : emp!.role.tr,
                  ),
                  const SizedBox(height: 12),
                  _readOnlyLine(
                    label: 'employee.profile.department'.tr,
                    value: departmentsLabel(emp),
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
                  AppVersionLabel(
                    padding: const EdgeInsets.only(top: 24),
                    textStyle: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
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

/// حوار ملف الموظف على الويب (نفس محتوى شاشة الموبايل).
void showEmployeeProfileDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      final dialogH = h < 600 ? h * 0.92 : (h * 0.9).clamp(400.0, 640.0);
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 440,
          height: dialogH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'employee.profile.title'.tr,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: EmployeeProfileForm(
                  closeOnSuccess: true,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
