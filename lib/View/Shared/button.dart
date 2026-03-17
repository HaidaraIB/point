import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';

Widget MainButton({
  double? width,
  double? height,
  Function()? onpress,
  Color? backgroundcolor,
  Color? borderColor,
  Color? fontcolor,
  double? fontsize,
  String? title,
  Widget? widget,
  bool? load,
  bool? enabled,
  LinearGradient? lineargrad,
  EdgeInsetsGeometry? margin,
  double? bordersize,
  bool icon = false,
  FontWeight? fontweight,
}) {
  return InkWell(
    onTap: (enabled == false || load == true) ? null : onpress,
    child: Opacity(
      opacity: (enabled == false || load == true) ? 0.4 : 1,
      child: Container(
        alignment: Alignment.center,
        margin: margin ?? EdgeInsets.symmetric(horizontal: 10),
        width: width ?? Get.width,
        height: height ?? 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(bordersize ?? 30),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          gradient:
              lineargrad ??
              LinearGradient(
                colors: [
                  backgroundcolor ?? AppColors.primary,
                  backgroundcolor ?? Color(0xff095D71),
                  backgroundcolor ?? Color(0xff095D71),
                  backgroundcolor ?? Color(0xff0B3954),

                  // backgroundcolor ?? AppColors.primary,
                ],
                end: Alignment.centerRight,
                begin: Alignment.centerLeft,
              ),
        ),
        child:
            load == true
                ? Center(child: CircularProgressIndicator())
                : widget != null
                ? widget
                : !icon
                ? Text(
                  title ?? '',
                  style: TextStyle(
                    color: fontcolor ?? Colors.white,
                    fontSize: fontsize ?? 15,
                    fontWeight: FontWeight.w500,
                    // fontFamily: Appfonts.basicFont,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    SizedBox(width: 20),
                    Text(
                      title ?? '',
                      style: TextStyle(
                        color: fontcolor ?? Colors.white,
                        fontSize: fontsize ?? 15,
                        fontWeight: fontweight ?? FontWeight.w500,
                        // fontFamily: Appfonts.basicFont,
                      ),
                    ),
                    Spacer(),
                    CircleAvatar(
                      radius: 20,
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.arrow_forward_ios_sharp,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 20),
                  ],
                ),
      ),
    ),
  );
}
