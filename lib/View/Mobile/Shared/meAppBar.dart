import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppImages.dart';

PreferredSize meAppBar(BuildContext context) {
  return PreferredSize(
    preferredSize: Size(Get.width, 50),
    child: Container(
      decoration: BoxDecoration(color: Colors.white),
      margin: EdgeInsets.only(top: 25),
      child: Row(children: [Image.asset(AppImages.images.logocolored)]),
    ),
  );
}
