import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Models/EmployeeAttendanceLocation.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/MultiSelectDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ReadOnlyAccountEmailField.dart';
import 'package:point/View/Employees/employee_identity_residence_fields.dart';
import 'package:point/View/Shared/employee_attendance_config_fields.dart';
import 'package:point/Utils/PasswordValidator.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Shared/safe_network_image.dart';
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
  late final TextEditingController jobTitleController;
  late final TextEditingController salaryController;
  late final TextEditingController bankNameController;
  late final TextEditingController bankAccountController;
  late final TextEditingController hireDateController;
  late final TextEditingController birthDateController;
  late final TextEditingController addressController;
  late final TextEditingController nationalIdNumberController;
  late final TextEditingController residenceCardNumberController;
  late final TextEditingController branchLabelController;
  late final TextEditingController branchLatController;
  late final TextEditingController branchLngController;
  late final TextEditingController branchRadiusController;

  bool obscurePassword = true;
  String selectedRole = "employee";
  List<String> selectedDepartments = [StorageKeys.departmentPromotion];
  String? selectedBranchId;
  DateTime? hireDate;
  DateTime? birthDate;
  String? nationalIdCardUrl;
  String? residenceCardUrl;
  TimeOfDay? workFrom;
  TimeOfDay? workTo;
  bool attendanceRemote = false;
  bool attendanceFlexibleHours = false;
  static const List<String> _roles = ["supervisor", "admin", "employee"];

  List<DropdownMenuItem<String>> _branchMenuItems() {
    final branches = Get.isRegistered<OsFinanceController>()
        ? Get.find<OsFinanceController>().branches.toList()
        : const [];
    final items = <DropdownMenuItem<String>>[
      for (final b in branches)
        if (b.id != null && b.id!.isNotEmpty)
          DropdownMenuItem(value: b.id, child: Text(b.name)),
    ];
    if (selectedBranchId != null &&
        selectedBranchId!.isNotEmpty &&
        !branches.any((b) => b.id == selectedBranchId)) {
      items.add(
        DropdownMenuItem(
          value: selectedBranchId!,
          child: Text(selectedBranchId!),
        ),
      );
    }
    return items;
  }

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
    jobTitleController = TextEditingController(text: m?.jobTitle);
    salaryController = TextEditingController(
      text: m?.salary != null ? m!.salary!.toStringAsFixed(0) : '',
    );
    bankNameController = TextEditingController(text: m?.bankName);
    bankAccountController = TextEditingController(text: m?.bankAccountNumber);
    hireDateController = TextEditingController(
      text: m?.hireDate == null
          ? ''
          : '${m!.hireDate!.year.toString().padLeft(4, '0')}-'
              '${m.hireDate!.month.toString().padLeft(2, '0')}-'
              '${m.hireDate!.day.toString().padLeft(2, '0')}',
    );
    birthDateController = TextEditingController(
      text: m?.birthDate == null
          ? ''
          : '${m!.birthDate!.year.toString().padLeft(4, '0')}-'
              '${m.birthDate!.month.toString().padLeft(2, '0')}-'
              '${m.birthDate!.day.toString().padLeft(2, '0')}',
    );
    addressController = TextEditingController(text: m?.address);
    nationalIdNumberController =
        TextEditingController(text: m?.nationalIdNumber);
    residenceCardNumberController =
        TextEditingController(text: m?.residenceCardNumber);
    birthDate = m?.birthDate;
    nationalIdCardUrl = m?.nationalIdCardUrl;
    residenceCardUrl = m?.residenceCardUrl;
    branchLabelController = TextEditingController();
    branchLatController = TextEditingController();
    branchLngController = TextEditingController();
    branchRadiusController = TextEditingController(
      text: EmployeeAttendanceLocation.defaultRadiusMeters.toString(),
    );
    EmployeeAttendanceFormData.populateFromEmployee(
      employee: m,
      labelController: branchLabelController,
      latController: branchLatController,
      lngController: branchLngController,
      radiusController: branchRadiusController,
    );
    workFrom = EmployeeAttendanceFormData.parseTime(m?.workHoursFrom);
    workTo = EmployeeAttendanceFormData.parseTime(m?.workHoursTo);
    attendanceRemote = m?.attendanceRemote ?? false;
    attendanceFlexibleHours = m?.attendanceFlexibleHours ?? false;
    selectedRole = m?.role ?? "employee";
    selectedBranchId = m?.branchId;
    hireDate = m?.hireDate;
    selectedDepartments = m == null
        ? <String>[StorageKeys.departmentPromotion]
        : (m.departments.isNotEmpty
              ? List<String>.from(m.departments)
              : <String>[StorageKeys.departmentPromotion]);
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
    jobTitleController.dispose();
    salaryController.dispose();
    bankNameController.dispose();
    bankAccountController.dispose();
    hireDateController.dispose();
    birthDateController.dispose();
    addressController.dispose();
    nationalIdNumberController.dispose();
    residenceCardNumberController.dispose();
    branchLabelController.dispose();
    branchLatController.dispose();
    branchLngController.dispose();
    branchRadiusController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = Get.find<HomeController>();
    final model = widget.model;
    if (selectedRole == 'employee' && selectedDepartments.isEmpty) {
      FunHelper.showSnackbarDeduped(
        'error'.tr,
        'employees.departments_required'.tr,
        dedupeKey: 'employee_departments_required',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    final departmentsToSave = selectedRole == 'employee'
        ? StorageKeys.normalizeDepartments(selectedDepartments)
        : <String>[];
    final workHoursOptional = selectedRole == 'employee' &&
        attendanceRemote &&
        attendanceFlexibleHours;
    final workHoursError = selectedRole == 'employee'
        ? EmployeeAttendanceFormData.validateWorkHours(
            workFrom,
            workTo,
            optional: workHoursOptional,
          )
        : null;
    if (workHoursError != null) {
      FunHelper.showSnackbarDeduped(
        'error'.tr,
        workHoursError,
        dedupeKey: 'employee_work_hours_invalid',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    final branchLocation = selectedRole == 'employee' && !attendanceRemote
        ? EmployeeAttendanceFormData.locationFromControllers(
            labelController: branchLabelController,
            latController: branchLatController,
            lngController: branchLngController,
            radiusController: branchRadiusController,
          )
        : null;
    final workHoursFrom = selectedRole == 'employee' && workFrom != null
        ? EmployeeAttendanceFormData.formatTimeOfDay(workFrom!)
        : null;
    final workHoursTo = selectedRole == 'employee' && workTo != null
        ? EmployeeAttendanceFormData.formatTimeOfDay(workTo!)
        : null;
    final clearWorkHoursOnSave = selectedRole != 'employee' ||
        (workHoursOptional && workFrom == null && workTo == null);
    final parsedSalary = double.tryParse(
      salaryController.text.trim().replaceAll(',', ''),
    );
    final jobTitle = jobTitleController.text.trim();
    final bankName = bankNameController.text.trim();
    final bankAccount = bankAccountController.text.trim();
    final address = addressController.text.trim();
    final nationalIdNumber = nationalIdNumberController.text.trim();
    final residenceCardNumber = residenceCardNumberController.text.trim();

    if (model == null) {
      final success = await controller.addEmployee(
        password: passwordController.text.trim().isEmpty
            ? 'TempPass@123'
            : passwordController.text.trim(),
        EmployeeModel(
          id: const Uuid().v4(),
          name: nameController.text,
          email: emailController.text,
          role: selectedRole,
          departments: departmentsToSave,
          status: 'active',
          createdAt: DateTime.now(),
          hireDate: hireDate,
          image: controller.uploadedFilesPaths.isNotEmpty
              ? controller.uploadedFilesPaths.last
              : null,
          attendanceLocation: branchLocation,
          workHoursFrom: workHoursFrom,
          workHoursTo: workHoursTo,
          attendanceRemote:
              selectedRole == 'employee' && attendanceRemote,
          attendanceFlexibleHours: selectedRole == 'employee' &&
              attendanceRemote &&
              attendanceFlexibleHours,
          salary: parsedSalary,
          jobTitle: jobTitle.isEmpty ? null : jobTitle,
          branchId: selectedBranchId,
          bankName: bankName.isEmpty ? null : bankName,
          bankAccountNumber: bankAccount.isEmpty ? null : bankAccount,
          birthDate: birthDate,
          address: address.isEmpty ? null : address,
          nationalIdNumber:
              nationalIdNumber.isEmpty ? null : nationalIdNumber,
          nationalIdCardUrl: nationalIdCardUrl,
          residenceCardNumber:
              residenceCardNumber.isEmpty ? null : residenceCardNumber,
          residenceCardUrl: residenceCardUrl,
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
          email: _canEditCredentials
              ? emailController.text
              : (model.email ?? ''),
          role: selectedRole,
          departments: departmentsToSave,
          hireDate: hireDate,
          clearHireDate: hireDate == null,
          image: controller.uploadedFilesPaths.isNotEmpty
              ? controller.uploadedFilesPaths.last
              : model.image,
          attendanceLocation: branchLocation,
          workHoursFrom: workHoursFrom,
          workHoursTo: workHoursTo,
          attendanceRemote:
              selectedRole == 'employee' && attendanceRemote,
          attendanceFlexibleHours: selectedRole == 'employee' &&
              attendanceRemote &&
              attendanceFlexibleHours,
          clearAttendanceLocation:
              selectedRole != 'employee' || attendanceRemote,
          clearWorkHours: clearWorkHoursOnSave,
          salary: parsedSalary,
          clearSalary: parsedSalary == null,
          jobTitle: jobTitle.isEmpty ? null : jobTitle,
          clearJobTitle: jobTitle.isEmpty,
          branchId: selectedBranchId,
          clearBranchId:
              selectedBranchId == null || selectedBranchId!.isEmpty,
          bankName: bankName.isEmpty ? null : bankName,
          clearBankName: bankName.isEmpty,
          bankAccountNumber: bankAccount.isEmpty ? null : bankAccount,
          clearBankAccountNumber: bankAccount.isEmpty,
          birthDate: birthDate,
          clearBirthDate: birthDate == null,
          address: address.isEmpty ? null : address,
          clearAddress: address.isEmpty,
          nationalIdNumber:
              nationalIdNumber.isEmpty ? null : nationalIdNumber,
          clearNationalIdNumber: nationalIdNumber.isEmpty,
          nationalIdCardUrl: nationalIdCardUrl,
          clearNationalIdCardUrl: nationalIdCardUrl == null ||
              nationalIdCardUrl!.trim().isEmpty,
          residenceCardNumber:
              residenceCardNumber.isEmpty ? null : residenceCardNumber,
          clearResidenceCardNumber: residenceCardNumber.isEmpty,
          residenceCardUrl: residenceCardUrl,
          clearResidenceCardUrl: residenceCardUrl == null ||
              residenceCardUrl!.trim().isEmpty,
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
    final appTheme = context.appTheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: appTheme.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.model == null ? 'addemployee'.tr : 'editemployee'.tr,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                              filePathOrBytes: v.first.bytes,
                              fileName: v.first.name,
                            );
                          }
                        });
                      },
                      child: Obx(
                        () => CircleAvatar(
                          backgroundColor: appTheme.unselected,
                          radius: 50,
                          child: controller.uploadedFilesPaths.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: SafeNetworkImage(
                                    controller.uploadedFilesPaths.last,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt,
                                  size: 50,
                                  color: appTheme.mutedText,
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
                    controller: nameController,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  if (widget.model == null || _canEditCredentials) ...[
                    InputText(
                      labelText: 'email'.tr,
                      hintText: 'example@example.com'.tr,
                      height: 48,
                      textInputType: TextInputType.emailAddress,
                      controller: emailController,
                      validator: (v) {
                        if (v == null || v.isEmpty || !v.toString().isEmail) {
                          return ' ';
                        }
                        return null;
                      },
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 16),
                    InputText(
                      hintText: widget.model == null
                          ? '******'.tr
                          : 'leave_empty_unchanged'.tr,
                      labelText: 'password'.tr,
                      obscureText: obscurePassword,
                      controller: passwordController,
                      height: 48,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: appTheme.mutedText,
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
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    ReadOnlyAccountEmailField(
                      email: widget.model?.email ?? '',
                      height: 48,
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 16),
                  ],
                  DynamicDropdown<String>(
                    items: _roles
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.tr),
                          ),
                        )
                        .toList(),
                    value: selectedRole,
                    label: 'role'.tr,
                    borderRadius: 8,
                    height: 48,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedRole = value;
                          if (selectedRole != 'employee') {
                            selectedDepartments = [];
                          } else if (selectedDepartments.isEmpty) {
                            selectedDepartments = [
                              StorageKeys.departmentPromotion,
                            ];
                          }
                        });
                      }
                    },
                  ),
                  if (selectedRole == 'employee') ...[
                    const SizedBox(height: 16),
                    DynamicMultiSelect<String>(
                      items: StorageKeys.departments,
                      selectedValues: selectedDepartments,
                      itemLabel: (d) =>
                          StorageKeys.semanticDepartmentLabelKey(d).tr,
                      label: 'employees.departments'.tr,
                      hint: 'employees.departments'.tr,
                      require: true,
                      borderRadius: 8,
                      height: 48,
                      onChanged: (list) {
                        setState(
                          () => selectedDepartments = List<String>.from(list),
                        );
                      },
                      validator: (list) =>
                          (list == null || list.isEmpty) ? ' ' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  InputText(
                    labelText: AppLocaleKeys.employeesJobTitle.tr,
                    hintText: AppLocaleKeys.employeesJobTitleHint.tr,
                    height: 48,
                    controller: jobTitleController,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: AppLocaleKeys.employeesSalary.tr,
                    hintText: AppLocaleKeys.employeesSalaryHint.tr,
                    height: 48,
                    controller: salaryController,
                    textInputType: TextInputType.number,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  DynamicDropdown<String>(
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(AppLocaleKeys.employeesBranchUnset.tr),
                      ),
                      ..._branchMenuItems(),
                    ],
                    value: selectedBranchId ?? '',
                    label: AppLocaleKeys.employeesBranch.tr,
                    borderRadius: 8,
                    height: 48,
                    onChanged: (value) {
                      setState(() {
                        selectedBranchId =
                            (value == null || value.isEmpty) ? null : value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  InputText(
                    labelText: AppLocaleKeys.employeesHireDate.tr,
                    hintText: AppLocaleKeys.employeesHireDateHint.tr,
                    height: 48,
                    controller: hireDateController,
                    readOnly: true,
                    borderRadius: 8,
                    suffixIcon: Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: appTheme.mutedText,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: hireDate ?? DateTime.now(),
                        firstDate: DateTime(1990),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          hireDate = picked;
                          hireDateController.text =
                              '${picked.year.toString().padLeft(4, '0')}-'
                              '${picked.month.toString().padLeft(2, '0')}-'
                              '${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  InputText(
                    labelText: AppLocaleKeys.employeesBankName.tr,
                    hintText: AppLocaleKeys.employeesBankNameHint.tr,
                    height: 48,
                    controller: bankNameController,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: AppLocaleKeys.employeesBankAccount.tr,
                    hintText: AppLocaleKeys.employeesBankAccountHint.tr,
                    height: 48,
                    controller: bankAccountController,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  EmployeeIdentityResidenceFields(
                    birthDateController: birthDateController,
                    addressController: addressController,
                    nationalIdNumberController: nationalIdNumberController,
                    residenceCardNumberController:
                        residenceCardNumberController,
                    nationalIdCardUrl: nationalIdCardUrl,
                    residenceCardUrl: residenceCardUrl,
                    birthDate: birthDate,
                    employeeId: widget.model?.id,
                    onBirthDateChanged: (d) => setState(() => birthDate = d),
                    onNationalIdCardUrlChanged: (u) =>
                        setState(() => nationalIdCardUrl = u),
                    onResidenceCardUrlChanged: (u) =>
                        setState(() => residenceCardUrl = u),
                  ),
                  if (selectedRole == 'employee') ...[
                    const SizedBox(height: 16),
                    EmployeeAttendanceConfigFields(
                      labelController: branchLabelController,
                      latController: branchLatController,
                      lngController: branchLngController,
                      radiusController: branchRadiusController,
                      workFrom: workFrom,
                      workTo: workTo,
                      attendanceRemote: attendanceRemote,
                      onAttendanceRemoteChanged: (v) => setState(() {
                        attendanceRemote = v;
                        if (!v) attendanceFlexibleHours = false;
                      }),
                      attendanceFlexibleHours: attendanceFlexibleHours,
                      onAttendanceFlexibleHoursChanged: (v) =>
                          setState(() => attendanceFlexibleHours = v),
                      onWorkFromChanged: (v) => setState(() => workFrom = v),
                      onWorkToChanged: (v) => setState(() => workTo = v),
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
                                'common.confirm'.tr,
                                style: TextStyle(
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
