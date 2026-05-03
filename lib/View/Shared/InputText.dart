import 'package:flutter/foundation.dart' show kIsWeb;
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
  final Widget? prefixIcon;
  final TextEditingController? controller;
  final String? Function(String? val)? validator;
  final String? Function(String? val)? onchange;
  final Color? fillColor;
  final Color? borderColor;
  final double? borderRadius;
  final bool? expanded;
  final bool? readOnly;
  final Widget? body;
  final int? maxLength;
  final TextInputType? textInputType;
  final TextStyle? hintStyle;
  final TextStyle? textStyle;
  final List<TextInputFormatter>? inputFormatters;
  final bool? require;
  final VoidCallback? onTap;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  /// When set with a multiline field ([expanded] true, [maxLines] null), reserves
  /// this many lines of height while empty (textarea-style).
  final int? minLines;

  InputText({
    super.key,
    this.validator,
    required this.hintText,
    this.prefixIcon,
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
    this.hintStyle,
    this.borderRadius,
    this.expanded,
    this.fillColor,
    this.textStyle,
    this.inputFormatters,
    this.require,
    this.onTap,
    this.readOnly,
    this.onFieldSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.focusNode,
    this.minLines,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompactHeight = (height ?? 0) > 0 && (height ?? 0) <= 44;
    final double fieldVerticalPadding =
        isCompactHeight ? (kIsWeb ? 8.0 : 5.0) : 12.0;

    // Always bound [height] with maxHeight so the text field's hit-test region matches
    // the outline (web multiline used min-only before, which left a tall I-beam zone
    // below the visible border).
    final BoxConstraints boxConstraints =
        height != null
            ? BoxConstraints(minHeight: height!, maxHeight: height!)
            : const BoxConstraints();

    /// [TextFormField] path keeps the original web min-only behavior; custom
    /// [body] needs bounded height so inner [ScrollView]s get a finite viewport.
    final BoxConstraints bodyBoxConstraints =
        height != null
            ? BoxConstraints(minHeight: height!, maxHeight: height!)
            : const BoxConstraints();

    final borderRadiusValue = borderRadius ?? 15.0;
    final outlineColor = borderColor ?? fillColor ?? const Color(0xffF1F5F9);

    /// Custom content (e.g. notes log, drag-drop zone). Must not use
    /// [InputDecoration.label], which would stack all children as one floating label.
    if (body != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (labelText != null) const SizedBox(height: 8),
          if (labelText != null)
            Row(
              children: [
                Flexible(
                  child: Text(
                    labelText ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (require == true)
                  const Text(' * ', style: TextStyle(color: Colors.red)),
              ],
            ),
          if (labelText != null) const SizedBox(height: 8),
          Container(
            constraints: bodyBoxConstraints,
            width: double.infinity,
            decoration: BoxDecoration(
              color: fillColor ?? const Color(0xffF1F5F9),
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: Border.all(color: outlineColor, width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: fieldVerticalPadding,
              ),
              child: body,
            ),
          ),
        ],
      );
    }

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
          constraints: boxConstraints,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            autofillHints: autofillHints,
            validator: validator,
            onChanged: onchange,
            onFieldSubmitted: onFieldSubmitted,
            textInputAction: textInputAction,
            obscureText: obscureText,
            enabled: enable,
            readOnly: readOnly ?? false,
            onTap: onTap,
            keyboardType: textInputType,
            maxLength: maxLength,
            maxLines: expanded == true ? null : 1,
            minLines: expanded == true && minLines != null ? minLines : null,
            textAlignVertical:
                expanded == true ? TextAlignVertical.top : TextAlignVertical.center,
            style:
                textStyle ??
                TextStyle(fontSize: 13, color: AppColors.primaryfontColor),
            inputFormatters: inputFormatters,

            decoration: InputDecoration(
              filled: true,
              fillColor: fillColor ?? const Color(0xffF1F5F9),
              isDense: isCompactHeight,
              hintText: hintText,
              hintStyle:
                  hintStyle ??
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryfontColor,
                  ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: fieldVerticalPadding,
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
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius ?? 15),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),

              suffixIcon: suffixIcon,
              prefixIcon: prefixIcon,
              // Keep border style on validation failure without shrinking field height.
              errorStyle: const TextStyle(fontSize: 0, height: 0),
            ),
          ),
        ),
      ],
    );
  }
}
