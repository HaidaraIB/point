import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Shared/InputText.dart';

/// Compact filter dropdown with dark-mode-safe fill, border, and menu colors.
class AppFilterDropdown<T> extends StatelessWidget {  const AppFilterDropdown({
    super.key,
    required this.hint,
    required this.items,
    this.value,
    this.onChanged,
    this.width = 150,
    this.height = 40,
    this.fontSize = 13,
    this.expandWidth = false,
  });

  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final double width;
  final double height;
  final double fontSize;
  final bool expandWidth;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final textStyle = TextStyle(
      fontSize: fontSize,
      color: theme.primaryText,
      fontWeight: FontWeight.bold,
    );

    final dropdown = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.inputFill,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          style: TextStyle(
            fontSize: fontSize,
            color: theme.primaryText,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: theme.cardSurface,
          iconEnabledColor: theme.mutedText,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );

    if (expandWidth) {
      return SizedBox(height: height, child: dropdown);
    }
    return SizedBox(width: width, height: height, child: dropdown);
  }
}

/// Full-width mobile search field used above filter rows (tasks, contents, history).
class MobileFilterSearchBar extends StatelessWidget {
  const MobileFilterSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
    this.height = 42,
    this.borderRadius = 8,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onChanged;
  final ValueChanged<String>? onSubmitted;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return InputText(
      prefixIcon: Icon(
        CupertinoIcons.search,
        color: context.appTheme.mutedText,
      ),
      hintText: hintText,
      height: height,
      controller: controller,
      textInputAction: TextInputAction.search,
      onchange: (_) {
        onChanged();
        return null;
      },
      onFieldSubmitted: onSubmitted == null
          ? null
          : (value) {
              onSubmitted!(value);
              FocusManager.instance.primaryFocus?.unfocus();
            },
      borderRadius: borderRadius,
    );
  }
}

/// Search row + optional clear button, stacked above filter dropdowns.
class MobileFilterSearchRow extends StatelessWidget {
  const MobileFilterSearchRow({
    super.key,
    required this.searchBar,
    this.onClearFilters,
    this.clearButtonSize = 42,
  });

  final Widget searchBar;
  final VoidCallback? onClearFilters;
  final double clearButtonSize;

  @override
  Widget build(BuildContext context) {
    if (onClearFilters == null) {
      return searchBar;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: searchBar),
        const SizedBox(width: 10),
        FilterResetButton(onPressed: onClearFilters!, size: clearButtonSize),
      ],
    );
  }
}

/// Themed filter/clear button (replaces the legacy white SVG filter icon).
class FilterResetButton extends StatelessWidget {
  const FilterResetButton({
    super.key,
    required this.onPressed,
    this.size = 42,
  });

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Material(
      color: theme.inputFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.filter_alt_outlined,
            color: context.appTheme.accentText,
            size: size * 0.48,
          ),
        ),
      ),
    );
  }
}