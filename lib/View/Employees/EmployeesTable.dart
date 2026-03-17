import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Auth/CreateUserAccount.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/HorizantalScroll.dart';
import 'package:point/View/Employees/Mobile/EmployeeFormMobilePage.dart';
import 'package:point/View/Shared/responsive.dart';

class EmployeeTable extends StatefulWidget {
  @override
  State<EmployeeTable> createState() => _EmployeeTableState();
}

class _EmployeeTableState extends State<EmployeeTable> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      selectedtab: 1,

      body: GetBuilder<HomeController>(
        builder: (controller) {
          return Responsive(
            desktop: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width:
                        Responsive.isDesktop(context)
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
                              bordersize: 35,
                              fontcolor: Colors.white,
                              backgroundcolor: AppColors.primary,
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
                              onpress: () {
                                showAddEmployeeDialog(context);
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        HorizontalScrollbarTable(
                          child: SizedBox(
                            width: (Get.width - 270).clamp(1100.0, double.infinity),
                            child: Obx(
                              () => DataTable(
                                dataRowMinHeight: 60,
                                dataRowMaxHeight: 60,
                                // headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                                dataRowColor: WidgetStateProperty.all(
                                  Colors.white,
                                ),
                                dividerThickness: 0.5,
                                columns: const [
                                  DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,

                                    label: Text(
                                      "ID",
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
                                      "الاسم",
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
                                      "البريد",
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
                                      "الدور",
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
                                      "الاجراءات",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fontColorGrey,
                                      ),
                                    ),
                                  ),
                                ],
                                rows:
                                    controller.employees.map((emp) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Center(
                                              child: Text(
                                                emp.id.toString(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppColors.fontColorGrey,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: Text(
                                                emp.name ?? '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppColors.fontColorGrey,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: Text(
                                                emp.email ?? '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppColors.fontColorGrey,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              alignment: Alignment.center,
                                              width: 110,
                                              height: 40,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    // vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                emp.role != 'supervisor'
                                                    ? '${emp.role}\n(${emp.department?.tr})'
                                                    : '${emp.role}',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.purple,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),

                                          DataCell(
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                MainButton(
                                                  width: 78,
                                                  height: 36,
                                                  backgroundcolor: Color(
                                                    0xff84D62C,
                                                  ),
                                                  bordersize: 8,
                                                  title: 'edit'.tr,
                                                  onpress: () {
                                                    if (emp.role ==
                                                            'accountholder' &&
                                                        controller
                                                                .currentemployee
                                                                .value
                                                                ?.role !=
                                                            'accountholder') {
                                                      FunHelper.showsnackbar(
                                                        'error'.tr,
                                                        'ليس لديك الصلاحيه'.tr,
                                                        snackPosition:
                                                            SnackPosition.TOP,
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                      );

                                                      return;
                                                    }
                                                    showAddEmployeeDialog(
                                                      context,
                                                      model: emp,
                                                    );
                                                  },
                                                ),
                                                SizedBox(width: 5),
                                                MainButton(
                                                  width: 78,
                                                  height: 36,
                                                  backgroundcolor: Colors.red,
                                                  bordersize: 8,
                                                  title: 'delete'.tr,
                                                  onpress: () {
                                                    if (emp.role ==
                                                            'accountholder' &&
                                                        controller
                                                                .currentemployee
                                                                .value
                                                                ?.role !=
                                                            'accountholder') {
                                                      FunHelper.showsnackbar(
                                                        'error'.tr,
                                                        'ليس لديك الصلاحيه'.tr,
                                                        snackPosition:
                                                            SnackPosition.TOP,
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                      );

                                                      return;
                                                    }
                                                    FunHelper.showConfirmDailog(
                                                      context,
                                                      ontap: () {
                                                        controller
                                                            .deleteEmployee(
                                                              emp.id ?? '',
                                                            );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ],
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
  final passwordController = TextEditingController(text: model?.password);

  bool obscurePassword = true;

  String selectedRole = model?.role ?? "employee";
  String selectedDepartment = model?.department ?? "cat1";
  List<String> roles = ["supervisor", "admin", "employee"];
  Get.find<HomeController>().uploadedFilesPaths.assignAll(
      model != null && model.image != null ? [model.image!] : []);
  var _key = GlobalKey<FormState>();
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
                                SvgPicture.asset('assets/svgs/Check_circle.svg'),
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
                                  builder:
                                      (c) => InkWell(
                                        onTap: () async {
                                          await controller.pickoneImage().then((
                                            v,
                                          ) {
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
                                                          BorderRadius.circular(
                                                            50,
                                                          ),
                                                      child: Image.network(
                                                        controller
                                                            .uploadedFilesPaths
                                                            .last,
                                                        width: 100,
                                                        height: 100,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                    : Icon(
                                                      Icons.camera_alt,
                                                      size: 50,
                                                    ),
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
                                ),
                                InputText(
                                  hintText: '******'.tr,
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
                                    if (v == null || v.isEmpty) {
                                      return ' ';
                                    }
                                    return validatePasswordStrong(v);
                                  },
                                  borderRadius: 5,
                                  borderColor: Colors.grey.shade300,
                                ),
                                DynamicDropdown(
                                  items:
                                      roles
                                          .map(
                                            (role) => DropdownMenuItem(
                                              value: role,
                                              child: Text(role),
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
                                      newstate(() {});
                                    }
                                  },
                                ),
                                if (selectedRole == 'employee')
                                  DynamicDropdown(
                                    items:
                                        StorageKeys.departments
                                            .map(
                                              (role) => DropdownMenuItem(
                                                value: role,
                                                child: Text(role.tr),
                                              ),
                                            )
                                            .toList(),
                                    value: selectedDepartment,
                                    label: 'القسم'.tr,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
                                    onChanged: (value) {
                                      if (value != null) {
                                        selectedDepartment = value;
                                      }
                                    },
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
                                          if (model == null) {
                                            controller
                                                .addEmployee(
                                                  EmployeeModel(
                                                    id:
                                                        '${Random().nextInt(100000)}',
                                                    name: nameController.text,
                                                    email: emailController.text,
                                                    role: selectedRole,
                                                    department:
                                                        selectedDepartment,
                                                    status: 'active',
                                                    createdAt: DateTime.now(),
                                                    password:
                                                        passwordController.text,
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
                                                    email: emailController.text,
                                                    role: selectedRole,
                                                    department:
                                                        selectedDepartment,
                                                    password:
                                                        passwordController.text,
                                                    image:
                                                        controller
                                                                .uploadedFilesPaths
                                                                .isNotEmpty
                                                            ? controller
                                                                .uploadedFilesPaths
                                                                .last
                                                            : model.image,
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
                                          }
                                        }
                                      },
                                      child:
                                          controller.isLoading.value
                                              ? Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                    ),
                                              )
                                              : Text(
                                                "تأكيد",
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
                                    child: Text("إلغاء"),
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
