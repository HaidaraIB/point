import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:point/Utils/AppColors.dart';

class InputText extends StatelessWidget {
  final String hintText;
  final String? labelText;
  final double? height;
  final bool obscureText;
  final bool? enable;
  final Widget? suffixIcon;
  final Widget? prefixicon;
  final TextEditingController? controller;
  final String? Function(String? val)? validator;
  final String? Function(String? val)? onchange;
  final Color? fillColor;
  final Color? borderColor;
  final double? borderRadius;
  final bool? expanded;
  final bool? readonly;
  final Widget? body;
  final int? maxLength;
  final TextInputType? textInputType;
  final TextStyle? hintstyle;
  final TextStyle? texttstyle;
  final List<TextInputFormatter>? inputFormatters;
  final bool? require;
  final VoidCallback? ontap;

  InputText({
    Key? key,
    this.validator,
    required this.hintText,
    this.prefixicon,
    this.labelText,
    this.onchange,
    this.height,
    this.obscureText = false,
    this.suffixIcon,
    this.enable,
    this.maxLength,
    this.controller,
    this.borderColor,
    this.body,
    this.textInputType,
    this.hintstyle,
    this.borderRadius,
    this.expanded,
    this.fillColor,
    this.texttstyle,
    this.inputFormatters,
    this.require,
    this.ontap,
    this.readonly,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) SizedBox(height: 8),
        if (labelText != null)
          Row(
            children: [
              Flexible(
                child: Text(
                  labelText ?? '',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (require == true)
                Text(' * ', style: TextStyle(color: Colors.red)),
            ],
          ),
        if (labelText != null) SizedBox(height: 8),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: fillColor ?? Color(0xffF1F5F9),
            borderRadius: BorderRadius.circular(borderRadius ?? 15.0),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            onChanged: onchange,
            obscureText: obscureText,
            enabled: enable,
            readOnly: readonly ?? false,
            onTap: ontap,
            keyboardType: textInputType,
            maxLength: maxLength,
            maxLines: expanded == true ? null : 1,
            style:
                texttstyle ??
                TextStyle(fontSize: 13, color: AppColors.primaryfontColor),
            inputFormatters: inputFormatters,

            // ✅ contentPadding ديناميكي حسب height أو default
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle:
                  hintstyle ??
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryfontColor,
                  ),
              label: body,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: height != null ? (height! / 2 - 10) : 14,
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius ?? 15),
                borderSide: BorderSide(
                  color: borderColor ?? fillColor ?? Color(0xffF1F5F9),
                  width: 1.2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius ?? 15),
                borderSide: BorderSide(
                  color: borderColor ?? fillColor ?? Color(0xffF1F5F9),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius ?? 15),
                borderSide: BorderSide(
                  color: borderColor ?? AppColors.primaryfontColor,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius ?? 15),
                borderSide: BorderSide(color: Colors.red, width: 1.8),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius ?? 15),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),

              suffixIcon: suffixIcon,
              prefixIcon: prefixicon,
              errorStyle: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
