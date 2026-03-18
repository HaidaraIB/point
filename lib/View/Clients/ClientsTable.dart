import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Auth/CreateUserAccount.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Clients/ClientFormMobilePage.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/HorizantalScroll.dart';
import 'package:point/View/Shared/responsive.dart';

class ClientsTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      selectedTab: 2,

      body: GetBuilder<HomeController>(
        builder: (controller) {
          return Responsive(
            // mobile: Container(),
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
                              'clients'.tr,
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
                                    'addnewclient'.tr,
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
                                      "الوصف",
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
                                      "تاريخ البداية",
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
                                      "تاريخ التهاية",
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
                                    controller.clients.map((emp) {
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
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  maxWidth: 150,
                                                ),
                                                child: Text(
                                                  emp.description ?? '--',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.fontColorGrey,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: Text(
                                                FunHelper.formatdate(
                                                      emp.startAt!,
                                                    ) ??
                                                    '',
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
                                                FunHelper.formatdate(
                                                      emp.endAt!,
                                                    ) ??
                                                    '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppColors.fontColorGrey,
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
                                                    FunHelper.showConfirmDailog(
                                                      context,
                                                      onTap: () async {
                                                        await controller
                                                            .deleteClient(
                                                              emp.id!,
                                                            );
                                                      },
                                                    );
                                                  },
                                                ),
                                                SizedBox(width: 5),
                                                MainButton(
                                                  width: 78,
                                                  height: 36,
                                                  backgroundcolor:
                                                      emp.status == 'active'
                                                          ? Colors.red
                                                          : Colors.green,
                                                  bordersize: 8,
                                                  title:
                                                      emp.status == 'active'
                                                          ? 'تعطيل'
                                                          : "تفعيل",
                                                  onpress: () {
                                                    FunHelper.showConfirmDailog(
                                                      context,
                                                      onTap: () async {
                                                        await controller.updateClient(
                                                          emp.copyWith(
                                                            status:
                                                                emp.status ==
                                                                        'active'
                                                                    ? 'inactive'
                                                                    : 'active',
                                                          ),
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

void showAddEmployeeDialog(BuildContext context, {ClientModel? model}) {
  if (Responsive.isMobile(context)) {
    Get.to(() => ClientFormMobilePage(model: model));
    return;
  }
  final nameController = TextEditingController(text: model?.name);
  final emailController = TextEditingController(text: model?.email);
  final passwordController = TextEditingController(text: model?.password);
  final desccontroller = TextEditingController(text: model?.description);
  final startatcontroller = TextEditingController(
    text: FunHelper.formatdate(model?.startAt),
  );
  final endatcontroller = TextEditingController(
    text: FunHelper.formatdate(model?.endAt),
  );
  DateTime? startAt = model?.startAt;
  DateTime? endAt = model?.endAt;
  Get.find<HomeController>().uploadedFilesPaths.assignAll(
    model != null && model.image != null ? [model.image!] : [],
  );
  // String selectedRole = model?.role ?? "media_buyer";
  // List<String> roles = ["media_buyer", "designer", "developer", "manager"];
  var _key = GlobalKey<FormState>();
  bool obscurePassword = true;
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: GetBuilder<HomeController>(
              builder: (controller) {
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
                                  'assets/svgs/Check_circle.svg',
                                ),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'addclient'.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'addclienthint'.tr,
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
                                      setState(() {});
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
                                InputText(
                                  labelText: 'desc'.tr,
                                  hintText: ''.tr,
                                  expanded: true,
                                  height: 42,
                                  fillColor: Colors.white,
                                  textInputType: TextInputType.emailAddress,
                                  controller: desccontroller,

                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return ' ';
                                    }
                                    return null;
                                  },

                                  borderRadius: 5,
                                  borderColor: Colors.grey.shade300,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      width: Get.width / 4.3,
                                      child: InputText(
                                        onTap: () async {
                                          final picked = await customDatePicker(
                                            context,
                                          );
                                          if (picked != null) {
                                            startAt = picked;
                                            startatcontroller.text = DateFormat(
                                              'dd MM yyyy - hh:mm a',
                                            ).format(picked.toLocal());
                                          }
                                        },
                                        labelText: 'startat'.tr,
                                        hintText: '1/10/2025'.tr,
                                        height: 42,
                                        fillColor: Colors.white,
                                        textInputType: TextInputType.datetime,
                                        controller: startatcontroller,
                                        readOnly: true,
                                        // enable: false,
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return ' ';
                                          }
                                          return null;
                                        },
                                        suffixIcon: Icon(
                                          CupertinoIcons.calendar,
                                          color: Colors.grey,
                                        ),

                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                      ),
                                    ),
                                    SizedBox(
                                      width: Get.width / 4.3,

                                      child: InputText(
                                        labelText: 'endat'.tr,
                                        hintText: '1/10/2026'.tr,
                                        readOnly: true,

                                        onTap: () async {
                                          final picked = await customDatePicker(
                                            context,
                                          );
                                          if (picked != null) {
                                            endAt = picked;
                                            endatcontroller.text = DateFormat(
                                              'dd MM yyyy - hh:mm a',
                                            ).format(picked.toLocal());
                                          }
                                        },
                                        height: 42,

                                        fillColor: Colors.white,
                                        textInputType: TextInputType.datetime,
                                        controller: endatcontroller,
                                        // enable: false,
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return ' ';
                                          }
                                          return null;
                                        },
                                        suffixIcon: Icon(
                                          CupertinoIcons.calendar,
                                          color: Colors.grey,
                                        ),
                                        borderRadius: 5,
                                        borderColor: Colors.grey.shade300,
                                      ),
                                    ),
                                  ],
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
                                                .addClient(
                                                  password:
                                                      passwordController.text,
                                                  ClientModel(
                                                    id:
                                                        '${Random().nextInt(100000)}',
                                                    name: nameController.text,
                                                    email: emailController.text,
                                                    image:
                                                        controller
                                                            .uploadedFilesPaths
                                                            .lastOrNull,
                                                    description:
                                                        desccontroller.text,
                                                    status: 'active',
                                                    createdAt: DateTime.now(),

                                                    password:
                                                        passwordController.text,
                                                    startAt: startAt,
                                                    endAt: endAt,
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
                                            // log(
                                            //   controller
                                            //       .uploadedFilesPaths
                                            //       .lastOrNull
                                            //       .toString(),
                                            // );
                                            // return;
                                            controller
                                                .updateClient(
                                                  model.copyWith(
                                                    name: nameController.text,
                                                    email: emailController.text,
                                                    createdAt: DateTime.now(),
                                                    password:
                                                        passwordController.text,
                                                    image:
                                                        controller
                                                            .uploadedFilesPaths
                                                            .lastOrNull,

                                                    startAt: startAt,
                                                    endAt: endAt,
                                                    description:
                                                        desccontroller.text,
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
                                                    CircularProgressIndicator(),
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
            ),
          );
        },
      );
    },
  );
}

// Future<DateTime?> customDatePicker(BuildContext context) async {
//   DateTime selectedDate = DateTime.now();

//   final pickedDate = await showDialog<DateTime>(
//     context: context,
//     builder: (context) {
//       return AlertDialog(
//         backgroundColor: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         // title: const Text("اختر التاريخ"),
//         content: SizedBox(
//           height: 400,
//           width: 350,
//           child: CalendarDatePicker(

//             initialDate: DateTime.now(),
//             firstDate: DateTime(2000),
//             lastDate: DateTime(2100),
//             onDateChanged: (date) {
//               selectedDate = date;
//             },
//           ),
//         ),
//         actions: [
//           SizedBox(
//             width: 160,
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Color(0xFF5C5589),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(24),
//                 ),
//                 padding: EdgeInsets.symmetric(horizontal: 48, vertical: 20),
//               ),
//               onPressed: () {
//                 Navigator.pop(context, selectedDate);
//               },
//               child: Text("تأكيد", style: TextStyle(color: Colors.white)),
//             ),
//           ),
//           SizedBox(
//             width: 160,
//             child: OutlinedButton(
//               style: OutlinedButton.styleFrom(
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(24),
//                 ),
//                 padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
//               ),
//               onPressed: () => Navigator.pop(context),
//               child: Text("إلغاء"),
//             ),
//           ),
//         ],
//       );
//     },
//   );

//   if (pickedDate != null) {
//     log("✅ Selected: $pickedDate");
//     return pickedDate;
//   } else {
//     log("❌ Cancelled");
//     return null;
//   }
// }
Future<DateTime?> customDatePicker(BuildContext context) async {
  DateTime selectedDate = DateTime.now();

  // 🗓️ أول خطوة: اختيار التاريخ
  final pickedDate = await showDialog<DateTime>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          height: 400,
          width: 350,
          child: CalendarDatePicker(
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            onDateChanged: (date) {
              selectedDate = date;
            },
          ),
        ),
        actions: [
          SizedBox(
            width: 160,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5C5589),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              ),
              onPressed: () async {
                final pickedTime = await showDialog<TimeOfDay>(
                  context: context,
                  builder: (context) {
                    TimeOfDay selectedTime = TimeOfDay.now();

                    return AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      content: SizedBox(
                        height: 200,
                        width: 300,
                        child: Center(
                          child: TimePickerSpinnerWidget(
                            initialTime: selectedTime,
                            onTimeChanged: (time) {
                              selectedTime = time;
                            },
                          ),
                        ),
                      ),
                      actions: [
                        SizedBox(
                          width: 160,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF5C5589),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 20,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context, selectedTime);
                            },
                            child: Text(
                              "تأكيد",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 160,
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
                            onPressed: () => Navigator.pop(context),
                            child: Text("إلغاء"),
                          ),
                        ),
                      ],
                    );
                  },
                );

                if (pickedTime != null) {
                  selectedDate = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                }

                Navigator.pop(context, selectedDate);
              },
              child: Text("تأكيد", style: TextStyle(color: Colors.white)),
            ),
          ),
          SizedBox(
            width: 160,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text("إلغاء"),
            ),
          ),
        ],
      );
    },
  );

  if (pickedDate != null) {
    // log("✅ Selected: $pickedDate");
    return pickedDate;
  } else {
    // log("❌ Cancelled");
    return null;
  }
}

class TimePickerSpinnerWidget extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const TimePickerSpinnerWidget({
    Key? key,
    required this.initialTime,
    required this.onTimeChanged,
  }) : super(key: key);

  @override
  State<TimePickerSpinnerWidget> createState() =>
      _TimePickerSpinnerWidgetState();
}

class _TimePickerSpinnerWidgetState extends State<TimePickerSpinnerWidget> {
  late int hour;
  late int minute;

  @override
  void initState() {
    super.initState();
    hour = widget.initialTime.hour;
    minute = widget.initialTime.minute;
  }

  String get period => hour >= 12 ? 'م' : 'ص';

  int get displayHour {
    int h = hour % 12;
    return h == 0 ? 12 : h; // علشان الساعة 0 تبقى 12
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "${displayHour.toString().padLeft(2, '0')} : ${minute.toString().padLeft(2, '0')} $period",
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // ⏰ الساعة يمين - الدقايق شمال
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ⏰ الساعة
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_up, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      hour = (hour + 1) % 24;
                      widget.onTimeChanged(
                        TimeOfDay(hour: hour, minute: minute),
                      );
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      hour = (hour - 1) < 0 ? 23 : hour - 1;
                      widget.onTimeChanged(
                        TimeOfDay(hour: hour, minute: minute),
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(width: 40),
            // ⏱️ الدقايق
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_up, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      minute = (minute + 1) % 60;
                      widget.onTimeChanged(
                        TimeOfDay(hour: hour, minute: minute),
                      );
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      minute = (minute - 1) < 0 ? 59 : minute - 1;
                      widget.onTimeChanged(
                        TimeOfDay(hour: hour, minute: minute),
                      );
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
