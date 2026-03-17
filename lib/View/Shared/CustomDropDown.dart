import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';

class DynamicDropdown<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final void Function(T?)? onChanged;
  final double radius;
  final bool isExpanded;
  final bool? require;
  final Color? borderColor;
  final Color? fillColor;
  final double? borderRadius;
  final double? height;
  final String? Function(T?)? validator;

  DynamicDropdown({
    super.key,
    required this.items,
    required this.value,
    this.label,
    this.hint,
    this.borderColor,
    this.borderRadius,
    this.onChanged,
    this.height,
    this.radius = 12,
    this.isExpanded = true,
    this.fillColor,
    this.require,
    this.validator, // ✅ هنا
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constrains) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              SizedBox(height: 15),
              Row(
                children: [
                  Text(
                    label!,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  if (require == true)
                    Text(' * ', style: TextStyle(color: Colors.red)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Container(
              color: fillColor ?? Colors.transparent,

              height: height,
              child: DropdownButtonFormField<T>(
                initialValue: value,
                items: items,

                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey,
                ),
                padding: EdgeInsets.zero,
                dropdownColor: Colors.white,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryfontColor,
                ),
                onChanged: onChanged,
                isExpanded: isExpanded,

                validator: validator,
                decoration: InputDecoration(
                  hintText: hint,
                  fillColor: Colors.white,
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: borderColor ?? fillColor ?? Color(0xffF1F5F9),
                    ),
                    borderRadius: BorderRadius.circular(borderRadius ?? 15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: borderColor ?? fillColor ?? Color(0xffF1F5F9),
                    ),
                    borderRadius: BorderRadius.circular(borderRadius ?? 15),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: borderColor ?? fillColor ?? Color(0xffF1F5F9),
                    ),
                    borderRadius: BorderRadius.circular(borderRadius ?? 15),
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: borderColor ?? fillColor ?? Color(0xffF1F5F9),
                    ),
                    borderRadius: BorderRadius.circular(borderRadius ?? 15),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(borderRadius ?? 15),
                    borderSide: BorderSide(color: Colors.red),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
