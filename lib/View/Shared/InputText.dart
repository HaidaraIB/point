import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/text_input_bidi.dart';

class InputText extends StatefulWidget {
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

  /// Picks readable text color when [fill] differs from the page theme (e.g. white
  /// inputs on a dark scaffold).
  static Color textOnFill(Color fill, AppThemeExtension appTheme) {
    return fill.computeLuminance() > 0.55
        ? AppThemeExtension.light.primaryText
        : appTheme.primaryText;
  }

  static Color hintOnFill(Color fill, AppThemeExtension appTheme) {
    return fill.computeLuminance() > 0.55
        ? AppThemeExtension.light.mutedText
        : appTheme.mutedText;
  }

  @override
  State<InputText> createState() => _InputTextState();
}

class _InputTextState extends State<InputText> {
  TextEditingController? _internalController;
  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _effectiveController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant InputText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController)?.removeListener(
        _onTextChanged,
      );
      if (widget.controller == null && _internalController == null) {
        _internalController = TextEditingController();
      }
      _effectiveController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onTextChanged);
    _internalController?.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final bool isCompactHeight = (widget.height ?? 0) > 0 && (widget.height ?? 0) <= 44;
    final double fieldVerticalPadding =
        isCompactHeight ? (kIsWeb ? 8.0 : 5.0) : 12.0;

    // Always bound [height] with maxHeight so the text field's hit-test region matches
    // the outline (web multiline used min-only before, which left a tall I-beam zone
    // below the visible border).
    final BoxConstraints boxConstraints =
        widget.height != null
            ? BoxConstraints(minHeight: widget.height!, maxHeight: widget.height!)
            : const BoxConstraints();

    /// [TextFormField] path keeps the original web min-only behavior; custom
    /// [body] needs bounded height so inner [ScrollView]s get a finite viewport.
    final BoxConstraints bodyBoxConstraints =
        widget.height != null
            ? BoxConstraints(minHeight: widget.height!, maxHeight: widget.height!)
            : const BoxConstraints();

    final borderRadiusValue = widget.borderRadius ?? 15.0;
    final resolvedFill = widget.fillColor ?? appTheme.inputFill;
    final outlineColor = widget.borderColor ?? appTheme.border;
    final fieldTextColor = InputText.textOnFill(resolvedFill, appTheme);
    final fieldHintColor = InputText.hintOnFill(resolvedFill, appTheme);
    final textDirection = typedInputTextDirection(_effectiveController.text);
    final hintTextDirection = typedInputHintTextDirection(widget.hintText);

    /// Custom content (e.g. notes log, drag-drop zone). Must not use
    /// [InputDecoration.label], which would stack all children as one floating label.
    if (widget.body != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.labelText != null) const SizedBox(height: 8),
          if (widget.labelText != null)
            Row(
              children: [
                Flexible(
                  child: Text(
                    widget.labelText ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: appTheme.primaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.require == true)
                  const Text(' * ', style: TextStyle(color: Colors.red)),
              ],
            ),
          if (widget.labelText != null) const SizedBox(height: 8),
          Container(
            constraints: bodyBoxConstraints,
            width: double.infinity,
            decoration: BoxDecoration(
              color: resolvedFill,
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: Border.all(color: outlineColor, width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.body,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) SizedBox(height: 8),
        if (widget.labelText != null)
          Row(
            children: [
              Flexible(
                child: Text(
                  widget.labelText ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: appTheme.primaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.require == true)
                Text(' * ', style: TextStyle(color: Colors.red)),
            ],
          ),
        if (widget.labelText != null) SizedBox(height: 8),
        if (widget.height != null && widget.expanded != true)
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: _buildTextField(
              appTheme: appTheme,
              isCompactHeight: isCompactHeight,
              fieldVerticalPadding: fieldVerticalPadding,
              resolvedFill: resolvedFill,
              outlineColor: outlineColor,
              fieldTextColor: fieldTextColor,
              fieldHintColor: fieldHintColor,
              borderRadiusValue: borderRadiusValue,
              textDirection: textDirection,
              hintTextDirection: hintTextDirection,
            ),
          )
        else
          Container(
            constraints: boxConstraints,
            width: double.infinity,
            child: _buildTextField(
              appTheme: appTheme,
              isCompactHeight: isCompactHeight,
              fieldVerticalPadding: fieldVerticalPadding,
              resolvedFill: resolvedFill,
              outlineColor: outlineColor,
              fieldTextColor: fieldTextColor,
              fieldHintColor: fieldHintColor,
              borderRadiusValue: borderRadiusValue,
              textDirection: textDirection,
              hintTextDirection: hintTextDirection,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required AppThemeExtension appTheme,
    required bool isCompactHeight,
    required double fieldVerticalPadding,
    required Color resolvedFill,
    required Color outlineColor,
    required Color fieldTextColor,
    required Color fieldHintColor,
    required double borderRadiusValue,
    required TextDirection? textDirection,
    required TextDirection? hintTextDirection,
  }) {
    return TextFormField(
            controller: _effectiveController,
            focusNode: widget.focusNode,
            autofillHints: widget.autofillHints,
            validator: widget.validator,
            onChanged: widget.onchange,
            onFieldSubmitted: widget.onFieldSubmitted,
            textInputAction: widget.textInputAction,
            obscureText: widget.obscureText,
            enabled: widget.enable,
            readOnly: widget.readOnly ?? false,
            onTap: widget.onTap,
            keyboardType: widget.textInputType,
            maxLength: widget.maxLength,
            maxLines: widget.expanded == true ? null : 1,
            minLines: widget.expanded == true && widget.minLines != null ? widget.minLines : null,
            textAlignVertical:
                widget.expanded == true ? TextAlignVertical.top : TextAlignVertical.center,
            textDirection: textDirection,
            style:
                widget.textStyle ??
                TextStyle(fontSize: 13, color: fieldTextColor),
            inputFormatters: widget.inputFormatters,

            decoration: InputDecoration(
              filled: true,
              fillColor: resolvedFill,
              isDense: isCompactHeight,
              hintText: widget.hintText,
              hintTextDirection: hintTextDirection,
              hintStyle:
                  widget.hintStyle ??
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: fieldHintColor,
                  ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: fieldVerticalPadding,
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? 15),
                borderSide: BorderSide(
                  color: outlineColor,
                  width: 1.2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? 15),
                borderSide: BorderSide(
                  color: outlineColor,
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? 15),
                borderSide: BorderSide(
                  color: widget.borderColor ?? AppColors.primary,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? 15),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? 15),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),

              suffixIcon: widget.suffixIcon,
              prefixIcon: widget.prefixIcon,
              // Keep border style on validation failure without shrinking field height.
              errorStyle: TextStyle(fontSize: 0, height: 0),
            ),
    );
  }
}
