import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Statistics/StatistcsCard.dart';

class StatisticsMobileScreen extends StatelessWidget {
  const StatisticsMobileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(
          () => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Column(
              children: [
                _MobileStatCard(
                  value: '${controller.employees.length}',
                  title: 'employeecount'.tr,
                  color: Colors.blue,
                ),
                const SizedBox(height: 10),
                _MobileStatCard(
                  value: '${controller.clients.length}',
                  title: 'clientscount'.tr,
                  color: Colors.amber,
                ),
                const SizedBox(height: 10),
                _MobileStatCard(
                  value: '${controller.clients.length}',
                  title: 'taskscount'.tr,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                const StatisticsCard(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileStatCard extends StatelessWidget {
  final String value;
  final String title;
  final Color color;

  const _MobileStatCard({
    required this.value,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
