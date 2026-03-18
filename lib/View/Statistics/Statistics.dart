import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';

import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Statistics/StatistcsCard.dart';

class Statistics extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      selectedTab: 6,

      body: GetBuilder<HomeController>(
        builder: (controller) {
          return Obx(
            () => Responsive(
              mobile: Container(),
              desktop: Row(
                children: [
                  SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.all(10),
                      width: Get.width - 270,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 50),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                width: Get.width / 3 - 120,
                                height: 150,
                                margin: EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,

                                  children: [
                                    Text(
                                      '${controller.employees.length}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 25),

                                    Text(
                                      'employeecount'.tr,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                width: Get.width / 3 - 120,
                                height: 150,
                                margin: EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${controller.clients.length}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 25),

                                    Text(
                                      'clientscount'.tr,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                width: Get.width / 3 - 120,
                                height: 150,
                                margin: EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,

                                  children: [
                                    Text(
                                      '${controller.clients.length}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 25),
                                    Text(
                                      'taskscount'.tr,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          StatisticsCard(),
                        ],
                      ),
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
