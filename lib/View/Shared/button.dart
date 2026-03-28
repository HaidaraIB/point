import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';

Widget MainButton({
  double? width,
  double? height,
  Function()? onPressed,
  Color? backgroundColor,
  Color? borderColor,
  Color? fontColor,
  double? fontSize,
  String? title,
  Widget? widget,
  bool? load,
  bool? enabled,
  LinearGradient? linearGradient,
  EdgeInsetsGeometry? margin,
  double? borderSize,
  bool icon = false,
  FontWeight? fontWeight,
}) {
  return InkWell(
    onTap: (enabled == false || load == true) ? null : onPressed,
    child: Opacity(
      opacity: (enabled == false || load == true) ? 0.4 : 1,
      child: Container(
        alignment: Alignment.center,
        margin: margin ?? EdgeInsets.symmetric(horizontal: 10),
        width: width ?? Get.width,
        height: height ?? 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderSize ?? 30),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          gradient:
              linearGradient ??
              LinearGradient(
                colors: [
                  backgroundColor ?? AppColors.primary,
                  backgroundColor ?? Color(0xff095D71),
                  backgroundColor ?? Color(0xff095D71),
                  backgroundColor ?? Color(0xff0B3954),

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
                ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    title ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    softWrap: true,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: fontColor ?? Colors.white,
                      fontSize: fontSize ?? 15,
                      fontWeight: FontWeight.w500,
                      // fontFamily: Appfonts.basicFont,
                    ),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    SizedBox(width: 20),
                    Text(
                      title ?? '',
                      style: TextStyle(
                        color: fontColor ?? Colors.white,
                        fontSize: fontSize ?? 15,
                        fontWeight: fontWeight ?? FontWeight.w500,
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
