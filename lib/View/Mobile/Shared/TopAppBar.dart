import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';

Widget TopAppBar(title) {
  return Container(
    child: Row(
      // mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        SizedBox(width: 10),
        InkWell(
          onTap: () {
            Get.back();
          },
          child: Icon(Icons.arrow_back),
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
