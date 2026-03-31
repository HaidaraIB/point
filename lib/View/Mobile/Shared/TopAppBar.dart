import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';

Widget TopAppBar(BuildContext context, String title) {
  final backIcon =
      Directionality.of(context) == TextDirection.rtl
          ? Icons.arrow_forward
          : Icons.arrow_back;
  return Container(
    child: Row(
      // mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        SizedBox(width: 10),
        InkWell(
          onTap: () {
            Get.back();
          },
          child: Icon(backIcon),
        ),
        Spacer(),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.primary,
          ),
        ),
        Spacer(),

        SizedBox(width: 25),
      ],
    ),
  );
}
