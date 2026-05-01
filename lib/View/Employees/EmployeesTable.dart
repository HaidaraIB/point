import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/PasswordValidator.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/MultiSelectDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ReadOnlyAccountEmailField.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/HorizontalScroll.dart';
import 'package:point/View/Shared/TableCellCenter.dart';
import 'package:point/View/Employees/Mobile/EmployeeFormMobilePage.dart';
import 'package:point/View/Employees/Mobile/EmployeesMobileScreen.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/table_actions_menu_row.dart';
import 'package:uuid/uuid.dart';

bool _canEditEmployeeCredentials(EmployeeModel? model) {
  if (model == null) return true;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final au = model.authUid;
  return uid != null &&
      uid.isNotEmpty &&
      au != null &&
      au.isNotEmpty &&
      uid == au;
}

bool _isEmployeeRecentlyOnline(DateTime? at) {
  if (at == null) return false;
  return DateTime.now().difference(at.toLocal()) <= const Duration(minutes: 2);
}

String _employeePresenceLabel(DateTime? at) {
  if (_isEmployeeRecentlyOnline(at)) return 'employees.online_now'.tr;
  if (at == null) return 'employees.last_seen_unknown'.tr;
  final when = FunHelper.formatTimeAgo(at.toLocal());
  return 'employees.last_seen_at'.trParams({'time': when});
}

Widget _employeePresenceChip(DateTime? at) {
  final online = _isEmployeeRecentlyOnline(at);
  final fg = online ? const Color(0xFF0F9D58) : AppColors.fontColorGrey;
  final bg = online ? const Color(0xFFEAF8F1) : const Color(0xFFF3F4F6);
  return Container(
    alignment: Alignment.center,
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Text(
      _employeePresenceLabel(at),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: fg,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );
}

class EmployeeTable extends StatefulWidget {
  @override
  State<EmployeeTable> createState() => _EmployeeTableState();
}

class _EmployeeTableState extends State<EmployeeTable> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      selectedTab: 1,

      body: GetBuilder<HomeController>(
        builder: (controller) {
          final canDeleteEmployees =
              controller.effectiveEmployee?.role == 'admin';
          return Responsive(
            mobile: Obx(
              () => EmployeesMobileScreen(
                employees: controller.employees.toList(),
                canDelete: canDeleteEmployees,
                selfEmployeeId: controller.effectiveEmployee?.id,
                onAdd: () => showAddEmployeeDialog(context),
                onEdit: (emp) {
                  if (emp.role == 'admin' &&
                      controller.effectiveEmployee?.role != 'admin') {
                    FunHelper.showSnackbar(
                      'error'.tr,
                      'errors.no_permission'.tr,
                      snackPosition: SnackPosition.TOP,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  showAddEmployeeDialog(context, model: emp);
                },
                onDelete: (emp) {
                  if (emp.role == 'admin' &&
                      controller.effectiveEmployee?.role != 'admin') {
                    FunHelper.showSnackbar(
                      'error'.tr,
                      'errors.no_permission'.tr,
                      snackPosition: SnackPosition.TOP,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  FunHelper.showConfirmDailog(
                    context,
                    onTap: () => controller.deleteEmployee(emp.id ?? ''),
                  );
                },
              ),
            ),
            desktop: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: Responsive.isDesktop(context)
                        ? Get.width - 270
                        : Get.width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 50),

                        Row(
                          children: [
                            Text(
                              'employees'.tr,
                              style: TextStyle(
                                color: AppColors.fontColorGrey,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            MainButton(
                              width: 180,
                              height: 45,
                              borderSize: 35,
                              fontColor: Colors.white,
                              backgroundColor: AppColors.primary,
                              widget: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'addnewwmployee'.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                              onPressed: () {
                                showAddEmployeeDialog(context);
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        HorizontalScrollbarTable(
                          child: SizedBox(
                            width: (Get.width - 270).clamp(
                              1100.0,
                              double.infinity,
                            ),
                            child: Obx(
                              () => DataTable(
                                dataRowMinHeight: 60,
                                dataRowMaxHeight: 60,
                                // headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                                dataRowColor: WidgetStateProperty.all(
                                  Colors.white,
                                ),
                                dividerThickness: 0.5,
                                columns: [
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,

                                    label: Text(
                                      'name'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fontColorGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,

                                    label: Text(
                                      'email'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fontColorGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,

                                    label: Text(
                                      'role'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fontColorGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,
                                    label: Text(
                                      'employees.presence'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fontColorGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,
                                    label: Text(
                                      'actions'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fontColorGrey,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: controller.employees.map((emp) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        TableCellCenter(
                                          child: Text(
                                            emp.name ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.fontColorGrey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        TableCellCenter(
                                          child: Text(
                                            emp.email ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.fontColorGrey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        TableCellCenter(
                                          child: Container(
                                            alignment: Alignment.center,
                                            height: 40,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              emp.role == 'employee'
                                                  ? '${emp.role.tr}\n(${emp.departments.map((d) => StorageKeys.semanticDepartmentLabelKey(d).tr).join(', ')})'
                                                  : emp.role.tr,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.purple,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      DataCell(
                                        TableCellCenter(
                                          child: _employeePresenceChip(
                                            controller.employeeLastSeenAt(emp.id),
                                          ),
                                        ),
                                      ),

                                      DataCell(
                                        TableCellCenter(
                                          child: PopupMenuButton<int>(
                                            tooltip: 'tasks.options_tooltip'.tr,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            color: Colors.white,
                                            elevation: 4,
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                value: 0,
                                                child: tableActionsMenuRow(
                                                  label: 'edit'.tr,
                                                  icon: Icons.edit_outlined,
                                                  iconColor: AppColors.success,
                                                ),
                                              ),
                                              if (canDeleteEmployees &&
                                                  emp.id !=
                                                      controller
                                                          .effectiveEmployee
                                                          ?.id)
                                                PopupMenuItem(
                                                  value: 1,
                                                  child: tableActionsMenuRow(
                                                    label: 'delete'.tr,
                                                    icon: Icons.delete_outline,
                                                    iconColor:
                                                        AppColors.destructive,
                                                  ),
                                                ),
                                            ],
                                            onSelected: (value) {
                                              if (value == 0) {
                                                if (emp.role == 'admin' &&
                                                    controller
                                                            .effectiveEmployee
                                                            ?.role !=
                                                        'admin') {
                                                  FunHelper.showSnackbar(
                                                    'error'.tr,
                                                    'errors.no_permission'.tr,
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                  );
                                                  return;
                                                }
                                                showAddEmployeeDialog(
                                                  context,
                                                  model: emp,
                                                );
                                              } else if (canDeleteEmployees &&
                                                  value == 1) {
                                                if (emp.role == 'admin' &&
                                                    controller
                                                            .effectiveEmployee
                                                            ?.role !=
                                                        'admin') {
                                                  FunHelper.showSnackbar(
                                                    'error'.tr,
                                                    'errors.no_permission'.tr,
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                  );
                                                  return;
                                                }
                                                FunHelper.showConfirmDailog(
                                                  context,
                                                  onTap: () {
                                                    controller.deleteEmployee(
                                                      emp.id ?? '',
                                                    );
                                                  },
                                                );
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.more_vert,
                                                color:
                                                    AppColors.primaryfontColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void showAddEmployeeDialog(BuildContext context, {EmployeeModel? model}) {
  if (Responsive.isMobile(context)) {
    Get.to(() => EmployeeFormMobilePage(model: model));
    return;
  }

  final nameController = TextEditingController(text: model?.name);
  final emailController = TextEditingController(text: model?.email);
  final passwordController = TextEditingController();

  bool obscurePassword = true;

  String selectedRole = model?.role ?? "employee";
  if (selectedRole == 'accountholder') selectedRole = 'admin';
  List<String> selectedDepartments = model == null
      ? <String>[StorageKeys.departmentPromotion]
      : (model.departments.isNotEmpty
            ? List<String>.from(model.departments)
            : <String>[StorageKeys.departmentPromotion]);
  List<String> roles = ["supervisor", "admin", "employee"];
  Get.find<HomeController>().uploadedFilesPaths.assignAll(
    model != null && model.image != null ? [model.image!] : [],
  );
  var _key = GlobalKey<FormState>();
  final canEditCredentials = _canEditEmployeeCredentials(model);
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GetBuilder<HomeController>(
          builder: (controller) {
            return StatefulBuilder(
              builder: (context, newstate) {
                return Form(
                  key: _key,
                  child: SizedBox(
                    width: Get.width * 0.5,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            margin: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Color(0xFF5C5589),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/svgs/icon_check_circle.svg',
                                ),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'addemployee'.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'addemployeehint'.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Builder(
                                  builder: (c) => InkWell(
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
                                    child: CircleAvatar(
                                      backgroundColor: Colors.grey.shade200,
                                      radius: 50,
                                      child: Obx(
                                        () =>
                                            controller
                                                .uploadedFilesPaths
                                                .isNotEmpty
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                                child: Image.network(
                                                  controller
                                                      .uploadedFilesPaths
                                                      .last,
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Icon(Icons.camera_alt, size: 50),
                                      ),
                                    ),
                                  ),
                                ),

                                InputText(
                                  labelText: 'name'.tr,
                                  hintText: 'entername'.tr,
                                  height: 42,
                                  fillColor: Colors.white,
                                  controller: nameController,

                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return ' ';
                                    }
                                    return null;
                                  },

                                  borderRadius: 5,
                                  borderColor: Colors.grey.shade300,
                                ),
                                if (model == null || canEditCredentials)
                                  InputText(
                                    labelText: 'email'.tr,
                                    hintText: 'example@example.com'.tr,
                                    height: 42,
                                    fillColor: Colors.white,
                                    textInputType: TextInputType.emailAddress,
                                    controller: emailController,
                                    validator: (v) {
                                      if (v == null ||
                                          v.isEmpty ||
                                          !v.toString().isEmail) {
                                        return ' ';
                                      }
                                      return null;
                                    },
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                  )
                                else
                                  ReadOnlyAccountEmailField(
                                    email: model.email ?? '',
                                    height: 42,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    fillColor: Colors.white,
                                  ),
                                if (model == null || canEditCredentials)
                                  InputText(
                                    hintText: model == null
                                        ? '******'.tr
                                        : 'leave_empty_unchanged'.tr,
                                    labelText: 'password'.tr,
                                    obscureText: obscurePassword,
                                    controller: passwordController,
                                    height: 42,
                                    fillColor: Colors.white,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey.shade600,
                                      ),
                                      onPressed: () {
                                        obscurePassword = !obscurePassword;
                                        newstate(() {});
                                      },
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return null;
                                      }
                                      return validatePasswordStrong(v.trim());
                                    },
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                  ),
                                DynamicDropdown(
                                  items: roles
                                      .map(
                                        (role) => DropdownMenuItem(
                                          value: role,
                                          child: Text(role.tr),
                                        ),
                                      )
                                      .toList(),
                                  value: selectedRole,
                                  label: 'role'.tr,
                                  borderRadius: 5,
                                  borderColor: Colors.grey.shade300,
                                  height: 42,
                                  fillColor: Colors.white,
                                  onChanged: (value) {
                                    if (value != null) {
                                      selectedRole = value;
                                      if (selectedRole != 'employee') {
                                        selectedDepartments = [];
                                      } else if (selectedDepartments.isEmpty) {
                                        selectedDepartments = [
                                          StorageKeys.departmentPromotion,
                                        ];
                                      }
                                      newstate(() {});
                                    }
                                  },
                                ),
                                if (selectedRole == 'employee')
                                  DynamicMultiSelect<String>(
                                    items: StorageKeys.departments,
                                    selectedValues: selectedDepartments,
                                    itemLabel: (d) =>
                                        StorageKeys.semanticDepartmentLabelKey(
                                          d,
                                        ).tr,
                                    label: 'employees.departments'.tr,
                                    hint: 'employees.departments'.tr,
                                    require: true,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
                                    onChanged: (list) {
                                      selectedDepartments = List<String>.from(
                                        list,
                                      );
                                      newstate(() {});
                                    },
                                    validator: (list) =>
                                        (list == null || list.isEmpty)
                                        ? ' '
                                        : null,
                                  ),
                              ],
                            ),
                          ),

                          // Actions
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Obx(
                                  () => SizedBox(
                                    width: Get.width * 0.5 - 260,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF5C5589),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 48,
                                          vertical: 20,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (_key.currentState!.validate()) {
                                          if (selectedRole == 'employee' &&
                                              selectedDepartments.isEmpty) {
                                            FunHelper.showSnackbarDeduped(
                                              'error'.tr,
                                              'employees.departments_required'
                                                  .tr,
                                              dedupeKey:
                                                  'employee_departments_required',
                                              snackPosition: SnackPosition.TOP,
                                              backgroundColor: Colors.red,
                                              colorText: Colors.white,
                                            );
                                            return;
                                          }
                                          final departmentsToSave =
                                              selectedRole == 'employee'
                                              ? StorageKeys.normalizeDepartments(
                                                  selectedDepartments,
                                                )
                                              : <String>[];
                                          if (model == null) {
                                            controller
                                                .addEmployee(
                                                  password:
                                                      passwordController.text
                                                          .trim()
                                                          .isEmpty
                                                      ? 'TempPass@123'
                                                      : passwordController.text
                                                            .trim(),
                                                  EmployeeModel(
                                                    id: const Uuid().v4(),
                                                    name: nameController.text,
                                                    email: emailController.text,
                                                    role: selectedRole,
                                                    departments:
                                                        departmentsToSave,
                                                    status: 'active',
                                                    createdAt: DateTime.now(),
                                                    image:
                                                        controller
                                                            .uploadedFilesPaths
                                                            .isNotEmpty
                                                        ? controller
                                                              .uploadedFilesPaths
                                                              .last
                                                        : null,
                                                  ),
                                                )
                                                .then((v) {
                                                  if (v) {
                                                    controller
                                                        .uploadedFilesPaths
                                                        .clear();
                                                    Get.back();
                                                  }
                                                });
                                          } else {
                                            controller
                                                .updateEmployee(
                                                  model.copyWith(
                                                    name: nameController.text,
                                                    email: canEditCredentials
                                                        ? emailController.text
                                                        : (model.email ?? ''),
                                                    role: selectedRole,
                                                    departments:
                                                        departmentsToSave,
                                                    image:
                                                        controller
                                                            .uploadedFilesPaths
                                                            .isNotEmpty
                                                        ? controller
                                                              .uploadedFilesPaths
                                                              .last
                                                        : model.image,
                                                  ),
                                                  newPassword:
                                                      !canEditCredentials ||
                                                          passwordController
                                                              .text
                                                              .trim()
                                                              .isEmpty
                                                      ? null
                                                      : passwordController.text
                                                            .trim(),
                                                )
                                                .then((v) {
                                                  if (v) {
                                                    controller
                                                        .uploadedFilesPaths
                                                        .clear();

                                                    Get.back();
                                                  }
                                                });
                                          }
                                        }
                                      },
                                      child: controller.isLoading.value
                                          ? Center(
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              'common.confirm'.tr,
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 190,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 20,
                                      ),
                                    ),
                                    onPressed: () {
                                      controller.uploadedFilesPaths.clear();
                                      Get.back();
                                    },
                                    child: Text('common.cancel'.tr),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    },
  );
}
