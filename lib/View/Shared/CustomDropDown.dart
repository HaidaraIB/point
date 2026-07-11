import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';

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
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final resolvedFill = fillColor ?? appTheme.inputFill;
    final resolvedBorder = borderColor ?? appTheme.border;
    final fieldTextColor = context.textOnFill(resolvedFill);
    final fieldHintColor = context.hintOnFill(resolvedFill);
    final borderRadiusValue = borderRadius ?? 15.0;

    OutlineInputBorder outlineBorder(Color color) => OutlineInputBorder(
          borderSide: BorderSide(color: color),
          borderRadius: BorderRadius.circular(borderRadiusValue),
        );

    return LayoutBuilder(
      builder: (context, constrains) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  Text(
                    label!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: appTheme.primaryText,
                    ),
                  ),
                  if (require == true)
                    const Text(' * ', style: TextStyle(color: Colors.red)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Container(
              decoration: BoxDecoration(
                color: resolvedFill,
                borderRadius: BorderRadius.circular(borderRadiusValue),
              ),
              clipBehavior: Clip.antiAlias,
              constraints:
                  height != null
                      ? BoxConstraints(minHeight: height!, maxHeight: height!)
                      : const BoxConstraints(),
              child: DropdownButtonFormField<T>(
                initialValue: value,
                items: items
                    .map(
                      (item) => DropdownMenuItem<T>(
                        value: item.value,
                        enabled: item.enabled,
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: appTheme.primaryText,
                          ),
                          child: item.child,
                        ),
                      ),
                    )
                    .toList(),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: appTheme.mutedText,
                ),
                padding: EdgeInsets.zero,
                dropdownColor: appTheme.cardSurface,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: fieldTextColor,
                ),
                onChanged: onChanged,
                isExpanded: isExpanded,
                validator: validator,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: resolvedFill,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: fieldHintColor,
                  ),
                  disabledBorder: outlineBorder(resolvedBorder),
                  focusedBorder: outlineBorder(appTheme.border),
                  enabledBorder: outlineBorder(resolvedBorder),
                  border: outlineBorder(resolvedBorder),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(borderRadiusValue),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(borderRadiusValue),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  errorStyle: const TextStyle(fontSize: 0, height: 0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
