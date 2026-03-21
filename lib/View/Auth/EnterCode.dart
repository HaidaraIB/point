import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import 'package:point/Controller/AuthController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/View/Auth/Shared/Rights.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

class EnterCode extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: Scaffold(
        appBar: AppBar(title: Text('auth.debug.login_mobile_title'.tr)),
        body: Center(child: Text('auth.debug.login_mobile_body'.tr)),
      ),
      tablet: Scaffold(
        appBar: AppBar(title: Text('auth.debug.login_tablet_title'.tr)),
        body: Center(child: Text('auth.debug.login_tablet_body'.tr)),
      ),
      desktop: Scaffold(body: _buildDesktopLayout()),
    );
  }
}

// --- IGNORE ---
Widget _buildDesktopLayout() {
  return GetBuilder<AuthController>(
    builder: (controller) {
      return Row(
        children: [
          Image.asset(
            AppImages.images.authcover,
            // width: Get.width / 2 - 50,
            // height: Get.height,
            // fit: BoxFit.fitWidth,
          ),

          Center(
            child: Container(
              alignment: Alignment.center,
              // color: Colors.yellow,
              margin: EdgeInsets.symmetric(vertical: 50, horizontal: 100),
              width: Get.width / 2 - 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'entercode'.tr,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      wordSpacing: 1.2,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 10),

                  Text(
                    'entercodefore'.trParams({'email': controller.email.text}),
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  SizedBox(height: 25),

                  Container(
                    height: 330,
                    decoration: BoxDecoration(
                      // color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/svgs/Featured icon.svg',
                          height: 80,
                        ),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color:
                                      controller
                                              .controllersForOtp[index]
                                              .text
                                              .isEmpty
                                          ? Colors.white
                                          : Color(0xffF1F5F9),
                                ),
                                margin: EdgeInsets.symmetric(horizontal: 5),
                                width: 60,
                                height: 60,
                                child: TextField(
                                  controller:
                                      controller.controllersForOtp[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: "",
                                    disabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xffF1F5F9),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xffF1F5F9),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xffF1F5F9),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xffF1F5F9),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.red),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (value.isNotEmpty && index < 5) {
                                      controller.update();
                                      FocusScope.of(Get.context!).nextFocus();
                                    }
                                  },
                                ),
                              );
                            }),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'resendcode'.tr,
                              style: TextStyle(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 2),
                            Text(
                              'aftermin'.trParams({'min': '30'}),
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 25),
                  MainButton(
                    icon: false,
                    height: 40,
                    bordersize: 10,
                    margin: EdgeInsets.all(0),
                    // lineargrad: ,
                    lineargrad: LinearGradient(
                      colors: [
                        Color(0xff19133F),
                        Color(0xff19133F),
                        Color(0xff19133F),
                        Color(0xff19133F),
                        Color(0xff19133F),
                        Color.fromARGB(255, 47, 19, 63),
                        Color.fromARGB(255, 47, 19, 63),
                        Color.fromARGB(255, 47, 19, 63),
                        Color.fromARGB(255, 47, 19, 63),

                        // Color(0xff5B0E4E),
                      ],

                      begin: Alignment.topCenter,
                      end: Alignment.bottomRight,
                    ),
                    title: 'confirm'.tr,
                  ),
                  buildRightsSection(),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
