import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Contents/ContentDialogDetails.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart';
import 'package:point/View/Shared/CustomDropDown.dart';

Widget buildMobileHistory(
  BuildContext context,
  HomeController controller,
  List<String> months,
) {
  return SingleChildScrollView(
    child: Container(
      padding: const EdgeInsets.all(10),
      width: Get.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'settings'.tr,
            style: TextStyle(
              color: AppColors.fontColorGrey,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => SizedBox(
              width: double.infinity,
              child: DynamicDropdown<dynamic>(
                items: controller.clients
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text('${v.name}'),
                      ),
                    )
                    .toList(),
                value: controller.clientController.text.isEmpty
                    ? null
                    : controller.clients.cast<dynamic>().firstWhereOrNull(
                          (a) => a.id == controller.clientController.text,
                        ),
                label: 'chooseclient'.tr,
                borderRadius: 5,
                borderColor: Colors.grey.shade300,
                height: 42,
                fillColor: Colors.white,
                onChanged: (value) {
                  if (value != null) {
                    controller.searchedcontents.assignAll(
                      List.from(
                        controller.contents.where(
                          (a) => a.clientId == (value as dynamic).id,
                        ),
                      ),
                    );
                    controller.selectedDate.value = '';
                    controller.clientController.text =
                        (value as dynamic).id ?? '';
                    controller.update();
                  }
                },
                validator: (v) => v == null ? ' ' : null,
              ),
            ),
          ),
          if (controller.clientController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Obx(
              () => SizedBox(
                width: double.infinity,
                child: DynamicDropdown<String>(
                  items: months
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v),
                        ),
                      )
                      .toList(),
                  value: controller.selectedDate.value.isEmpty
                      ? null
                      : controller.selectedDate.value,
                  label: 'اختر التاريخ'.tr,
                  borderRadius: 5,
                  borderColor: Colors.grey.shade300,
                  height: 42,
                  fillColor: Colors.white,
                  onChanged: (value) {
                    if (value != null) {
                      final parts = value.split('-');
                      final year = int.parse(parts[0]);
                      final month = int.parse(parts[1]);
                      controller.searchedcontents.assignAll(
                        List.from(
                          controller.contents.where(
                            (a) =>
                                a.clientId ==
                                    controller.clientController.text &&
                                a.publishDate != null &&
                                a.publishDate!.month == month &&
                                a.publishDate!.year == year,
                          ),
                        ),
                      );
                      controller.selectedDate.value = value;
                      controller.update();
                    }
                  },
                  validator: (v) => v == null ? ' ' : null,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          GetX<HomeController>(
            builder: (c) {
              final contents = c.searchedcontents.toList();
              if (c.clientController.text.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'اختر العميل لعرض المحتوى',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.fontColorGrey,
                      ),
                    ),
                  ),
                );
              }
              if (contents.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'لا توجد بيانات',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.fontColorGrey,
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: contents.length,
                itemBuilder: (_, i) {
                  return ContentStatusCard(
                    index: i,
                    model: contents[i],
                    onTap: () => showContentDialogDetails(
                      context,
                      task: contents[i],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
              );
            },
          ),
        ],
      ),
    ),
  );
}
